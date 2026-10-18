shader_type spatial;
render_mode cull_disabled, world_vertex_coords, alpha_to_coverage;
// 植被（草、花、叶片、蕨）：镂空、双面、随风摆动。光照模型照着 Blender 里这些素材的材质做：
//   - 正面：朗伯漫反射（和 Cycles 的 Principled 一样）
//   - 背面：透射。阳光从叶片背后照来时，叶片透出自身颜色的光；草的透射色更亮更饱和，
//     这就是逆光下草地发亮的原因（对应 Blender 材质里的 Translucent BSDF）
//   - 一点 GGX 近似的高光
// 每种材质的参数（饱和度、亮度、透射比例等）由 forest_room.gd 按 Blender 材质填入，
// 见 room.tscn 的 foliage_grades；共用参数在 foliage_material.tres。

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_tex = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform float roughness = 0.65;
uniform float specular = 0.5;              // 0.5 = 4% 正面反射率，与 Blender 的 Specular IOR Level 0.5 相同
uniform float alpha_cut = 0.4;
uniform float mip_alpha_scale = 0.25;      // 每降一级贴图，不透明度补多少（远处镂空不至于越来越稀）
// 贴图取样提前降级几级：细草叶在屏幕上比像素还细时会闪烁成“花屏”，提前取模糊一点的贴图，
// 草丛读成柔和的一簇而不是一堆跳动的细线。0 为不处理
uniform float texture_lod_bias = 0.0;
// 镂空取样最多降到第几级贴图。细草叶的贴图降级后会糊成一片，再补不透明度就成了一块块“叶片”；
// 限制级数让草叶保持细长（远处的闪烁由 TAA 抹平）。99 = 不限制
uniform float alpha_lod_max = 99.0;
uniform float up_normal = 0.2;             // 着色法线向正上方靠拢多少：薄片法线杂乱，稍微收拢更柔和

// —— 按材质设置（对应 Blender 材质节点）——
uniform float saturation = 1.0;            // 底色饱和度（Hue/Saturation 节点）
uniform float value = 1.0;                 // 底色亮度倍数
uniform float diffuse_weight = 1.0;        // 漫反射占比（Mix Shader 里 Principled 的份额）
uniform float transmission = 0.0;          // 透射占比（Translucent BSDF 的份额；Add Shader 时为 1）
uniform float transmission_saturation = 1.0;
uniform float transmission_value = 1.0;
// 草叶的偏黄：Blender 草材质把叶片中段的色相往黄偏（Hue 0.375 = -45°），越靠 UV.x 大的一端越弱
uniform float hue_shift = 0.0;             // 色相偏移（圈数，-0.125 = -45°）
uniform vec2 hue_shift_uv = vec2(0.42, 0.6);
uniform float hue_jitter = 0.0;            // 每株随机的色相偏移幅度（圈数）

// 草丛内部的遮挡：根部压暗
uniform float root_shade = 0.55;
// 草丛内部互相挡阳光：直射光（含透射）在根部只剩这么多，往上逐渐恢复。
// 阴影贴图分辨率不够画出草叶之间的影子，用它代替。1 为不处理。
uniform float direct_root = 1.0;
// 树冠内部的遮挡：越靠树冠中心、越靠下，天光越少（只影响环境光）。crown_size 为 0 时不用。
// crown_centre / crown_size 由房间脚本按网格包围盒填入（网格自身坐标）。
uniform vec3 crown_centre = vec3(0.0);
uniform vec3 crown_size = vec3(0.0);
uniform float crown_occlusion = 0.0;       // 树冠最深处剩下的环境光比例 = 1 - crown_occlusion
// 投影：叶片在阳光阴影图里按不透明度随机透光（Cycles 的叶影会漏光），0 为硬镂空
uniform float shadow_dither = 0.0;
// 每株之间的明暗与偏黄差异
uniform float variation = 0.12;
uniform float yellowing = 0.2;

// 风。以下三项由房间脚本按模型尺寸填入：植株顶端高度、网格原点离地高度、网格自带的缩放。
uniform float plant_height = 1.0;
uniform float origin_height = 0.0;
uniform float local_scale = 1.0;
uniform float sway = 0.05;                 // 顶端摆幅，占植株高度的比例
uniform float flutter = 0.01;              // 叶片抖动幅度（米）
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float wind_speed = 1.0;

varying float height01;
varying float plant_seed;
varying vec3 facing_normal;
varying vec3 transmit_colour;
varying float crown_ao;
varying float direct_shade;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 hue_rotate(vec3 colour, float turns) {
	// 绕灰轴旋转：正方向 红→绿→蓝，与 Blender 色相增大的方向一致
	const vec3 k = vec3(0.57735);
	float angle = turns * TAU;
	return colour * cos(angle) + cross(k, colour) * sin(angle) + k * dot(k, colour) * (1.0 - cos(angle));
}

vec3 grade(vec3 colour, float sat, float val) {
	float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(grey), colour, sat), vec3(0.0)) * val;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	plant_seed = hash21(floor(origin.xz * 7.0));
	float instance_scale = length(MODEL_MATRIX[1].xyz) / local_scale;
	float top = max(plant_height * instance_scale, 0.05);
	float ground = origin.y - origin_height * instance_scale;
	height01 = clamp((VERTEX.y - ground) / top, 0.0, 1.0);
	float phase = origin.x * 0.31 + origin.z * 0.23;
	float time = TIME * wind_speed;
	float gust = sin(time * 1.1 + phase) * 0.5 + sin(time * 2.3 + phase * 1.9) * 0.28 + sin(time * 0.37 + phase * 0.2) * 0.4;
	vec2 push = normalize(wind_direction) * (gust * sway * top * height01 * height01);
	float shiver = sin(time * 5.3 + VERTEX.x * 3.1 + VERTEX.z * 2.7 + VERTEX.y * 1.3) * flutter * height01;
	crown_ao = 1.0;
	if (crown_size.x > 0.0) {
		mat3 basis = mat3(MODEL_MATRIX);
		vec3 local = inverse(basis) * (VERTEX - origin);
		vec3 offset = (local - crown_centre) / (crown_size * 0.5);
		float depth_inside = clamp(1.0 - length(offset), 0.0, 1.0);
		float below = clamp(-offset.y * 0.5 + 0.5, 0.0, 1.0);
		crown_ao = 1.0 - crown_occlusion * clamp(smoothstep(0.0, 0.7, depth_inside) * 0.7 + below * 0.3, 0.0, 1.0);
	}
	VERTEX.xz += push + vec2(shiver, shiver * 0.6);
	VERTEX.y -= length(push) * 0.25 * height01;
}

void fragment() {
	vec4 texel = texture(albedo_tex, UV, texture_lod_bias);
	vec3 base = texel.rgb * tint;
	base *= 1.0 + (plant_seed - 0.5) * 2.0 * variation;
	base = mix(base, base * vec3(1.1, 1.03, 0.75), plant_seed * yellowing);
	float shift = hue_shift * (1.0 - smoothstep(hue_shift_uv.x, hue_shift_uv.y, UV.x)) - hue_jitter * plant_seed;
	base = max(hue_rotate(base, shift), vec3(0.0));
	float occlusion = mix(root_shade, 1.0, smoothstep(0.0, 0.5, height01));
	direct_shade = mix(direct_root, 1.0, smoothstep(0.0, 0.9, height01));
	vec3 coloured = grade(base, saturation, value) * occlusion;
	ALBEDO = coloured * diffuse_weight;
	transmit_colour = grade(coloured, transmission_saturation, transmission_value) * transmission;

	vec2 texel_uv = UV * vec2(textureSize(albedo_tex, 0));
	float lod = 0.5 * log2(max(max(dot(dFdx(texel_uv), dFdx(texel_uv)), dot(dFdy(texel_uv), dFdy(texel_uv))), 1e-6));
	lod += texture_lod_bias;
	float coverage = lod > alpha_lod_max ? textureLod(albedo_tex, UV, alpha_lod_max).a : texel.a;
	ALPHA = coverage * (1.0 + clamp(lod, 0.0, alpha_lod_max) * mip_alpha_scale);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// 平行光阴影图是正交投影：那时按不透明度随机镂空，阴影经过柔化后就是半透的叶影
	if (PROJECTION_MATRIX[3][3] > 0.5 && shadow_dither > 0.0) {
		float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		ALPHA = texel.a;
		ALPHA_SCISSOR_THRESHOLD = mix(alpha_cut, clamp(noise, 0.02, 0.98), shadow_dither);
	}
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = texel_uv;

	facing_normal = NORMAL;            // 已经翻到朝向镜头的一面
	if (use_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, up, up_normal));
	ROUGHNESS = roughness;
	SPECULAR = specular;
	AO = crown_ao;
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0);
	vec3 arriving = ATTENUATION * LIGHT_COLOR * direct_shade;
	DIFFUSE_LIGHT += lit * arriving / PI;
	// 透射：光从叶片背面照来（相对镜头这一面）。不乘 ALBEDO，所以记在 SPECULAR_LIGHT 上。
	float behind = max(-dot(facing_normal, LIGHT), 0.0);
	SPECULAR_LIGHT += transmit_colour * behind * arriving / PI;
	// 高光：GGX 分布 + Schlick 菲涅耳的简化版
	vec3 half_vector = normalize(LIGHT + VIEW);
	float alpha = max(roughness * roughness, 0.02);
	float n_dot_h = max(dot(NORMAL, half_vector), 0.0);
	float d = alpha * alpha / (PI * pow(n_dot_h * n_dot_h * (alpha * alpha - 1.0) + 1.0, 2.0));
	float f0 = 0.08 * specular;
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - max(dot(LIGHT, half_vector), 0.0), 5.0);
	float visibility = 0.25 / max(max(dot(NORMAL, VIEW), 0.05) * max(lit, 0.05), 0.05);
	SPECULAR_LIGHT += d * fresnel * min(visibility, 4.0) * lit * arriving;
}
