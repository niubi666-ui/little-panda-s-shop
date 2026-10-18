shader_type spatial;
// 童话森林地面：苔藓为底，落叶小径和溪床用解析遮罩混入（公式与 Blender 布景脚本
// build_game_arena.py 中的 path_x / stream_y 一致，改了一边要同步另一边）。
// 贴图按世界坐标平铺，网格不需要 UV。参数在 ground_material.tres 里调。

uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D litter_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D pebbles_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebbles_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D caustic_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

// 由房间脚本从 layout.json 填入
uniform float stream_half = 1.7;
uniform float bridge_x = 0.6;
uniform float water_level = -0.4;

uniform float moss_scale = 3.0;
uniform float litter_scale = 2.5;
uniform float pebbles_scale = 1.8;
// 三个染色是线性倍数（不按 sRGB 换算），与 Blender 对照材质里的乘法节点一致
uniform vec3 moss_tint = vec3(1.0);
uniform vec3 litter_tint = vec3(1.0);
uniform vec3 wet_tint = vec3(0.34, 0.4, 0.38);
uniform float saturation = 1.0;
uniform float litter_patches = 0.4;       // 小径之外零星泥土落叶的多少
uniform float macro_contrast = 0.36;      // 大尺度明暗变化的幅度，打破贴图平铺的重复感
uniform float wet_band = 0.18;            // 水面以上多高的岸边是湿的（米）
uniform float caustics = 0.9;             // 水下焦散亮纹的强度
uniform float caustic_scale = 0.35;
uniform float normal_strength = 1.0;      // 法线贴图强度：细碎的凹凸在远处会闪，调低更“安静”
// 贴图取样提前降级几级：地面细碎的颗粒在运动中会闪，取模糊一点的贴图更稳
uniform float texture_lod_bias = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
// Blender 坐标：bx = 世界 x，by = -世界 z
float stream_y(float bx) { return -12.4 + 1.2 * sin(bx * 0.2 + 0.4) + 0.4 * sin(bx * 0.53); }
float path_x(float by) { return bridge_x + 0.9 * sin((by + 12.0) * 0.22); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 世界坐标平铺：切线沿 +X，副切线沿 -Z（贴图 V 轴向下）
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, -1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float bx = p.x;
	float by = -p.y;
	float wobble = (vnoise(p * 0.7) - 0.5) * 0.9;

	float bed = 1.0 - smoothstep(stream_half * 0.95, stream_half * 1.75, abs(by - stream_y(bx)) + wobble * 0.5);

	float width = 1.5 * (1.0 + 0.25 * sin(by * 0.5)) * (1.0 - smoothstep(0.0, 3.5, by)) * step(-28.0, by);
	float path = (1.0 - smoothstep(width * 0.5, width, abs(bx - path_x(by)) + wobble * 0.6)) * step(0.05, width);
	float patches = smoothstep(0.62, 0.8, vnoise(p * 0.16 + 9.0) * 0.6 + vnoise(p * 0.55 + 3.0) * 0.4) * litter_patches;
	float litter = clamp(max(path, patches) * (1.0 - bed), 0.0, 1.0);

	vec3 albedo = texture(moss_albedo, p / moss_scale, texture_lod_bias).rgb * moss_tint;
	albedo *= 1.0 - macro_contrast * 0.5 + macro_contrast * vnoise(p * 0.09 + 20.0);
	vec3 normal = texture(moss_normal, p / moss_scale, texture_lod_bias).rgb;
	float rough = texture(moss_roughness, p / moss_scale, texture_lod_bias).r;

	albedo = mix(albedo, texture(litter_albedo, p / litter_scale, texture_lod_bias).rgb * litter_tint, litter);
	normal = mix(normal, texture(litter_normal, p / litter_scale, texture_lod_bias).rgb, litter);
	rough = mix(rough, texture(litter_roughness, p / litter_scale, texture_lod_bias).r, litter);

	albedo = mix(albedo, texture(pebbles_albedo, p / pebbles_scale, texture_lod_bias).rgb * wet_tint, bed);
	normal = mix(normal, texture(pebbles_normal, p / pebbles_scale, texture_lod_bias).rgb, bed);
	rough = mix(rough, 0.25, bed);

	// 水线附近的岸是湿的：更暗、更亮滑
	float wet = 1.0 - smoothstep(water_level, water_level + wet_band, world_pos.y);
	albedo *= mix(1.0, 0.6, wet);
	rough = mix(rough, 0.22, wet);

	// 水下焦散：两层流动噪声相交处出亮纹。乘在底色上，所以只有被太阳照到的水底才看得见。
	float submerged = smoothstep(0.0, 0.08, water_level - world_pos.y);
	vec2 cp = p * caustic_scale;
	float c1 = texture(caustic_noise, cp + TIME * vec2(0.03, 0.02)).r;
	float c2 = texture(caustic_noise, cp * 1.3 - TIME * vec2(0.025, 0.035) + 0.37).r;
	albedo *= 1.0 + pow(1.0 - abs(c1 - c2), 14.0) * caustics * submerged;

	float grey = dot(albedo, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(grey), albedo, saturation);
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
