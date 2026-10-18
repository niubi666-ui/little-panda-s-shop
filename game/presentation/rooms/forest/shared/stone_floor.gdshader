shader_type spatial;
// 石砌地面（森林系列共用，神木圣坛的圆形石台、石桥、台阶用）。
// 石材贴图按世界坐标平铺；石缝、浮雕、缝里的苔藓、落花由一张图案图（pattern）决定，图案图由
// Blender 布景脚本生成，覆盖 pattern_rect 这块范围：
//   R = 石缝（1 = 缝）  G = 缝里/边上长的苔藓  B = 浮雕的高度（凸起的藤叶纹样）  A = 落花
// 浮雕和石缝的凹凸由图案图的梯度算出，叠在石材法线上。网格不需要 UV。

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float stone_scale = 2.5;
uniform vec3 stone_tint = vec3(1.0);
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float moss_scale = 2.0;
uniform vec3 moss_tint = vec3(1.0);
uniform sampler2D bloom_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float bloom_scale = 1.8;
uniform float bloom_strength = 1.0;

uniform sampler2D pattern : filter_linear_mipmap, repeat_disable;
uniform vec4 pattern_rect = vec4(-15.0, -15.0, 30.0, 30.0);   // 图案覆盖的世界范围：x、z 起点和宽、深（米）
uniform float groove_dark = 0.45;        // 石缝压暗
uniform float carve_dark = 0.12;         // 浮雕的边上略暗（积灰）
uniform float relief_strength = 3.0;     // 浮雕凹凸的强度
uniform float groove_strength = 2.0;     // 石缝凹凸的强度
uniform float macro_contrast = 0.25;     // 大尺度明暗起伏，打破平铺感
uniform float normal_strength = 0.7;
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, -1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 puv = (p - pattern_rect.xy) / pattern_rect.zw;
	vec4 pat = texture(pattern, puv);
	// 图案的梯度 → 凹凸（浮雕凸起、石缝凹下）
	vec2 texel = 1.0 / vec2(textureSize(pattern, 0));
	float h0 = pat.b * relief_strength - pat.r * groove_strength;
	vec4 px = texture(pattern, puv + vec2(texel.x, 0.0));
	vec4 pz = texture(pattern, puv + vec2(0.0, texel.y));
	float hx = px.b * relief_strength - px.r * groove_strength;
	float hz = pz.b * relief_strength - pz.r * groove_strength;
	vec2 slope = vec2(hx - h0, hz - h0) / (texel * pattern_rect.zw * 40.0);

	vec3 albedo = texture(stone_albedo, p / stone_scale, texture_lod_bias).rgb * stone_tint;
	albedo *= 1.0 - macro_contrast * 0.5 + macro_contrast * vnoise(p * 0.12 + 7.0);
	albedo *= 1.0 - groove_dark * pat.r;
	albedo *= 1.0 - carve_dark * smoothstep(0.05, 0.5, length(slope));
	float rough = texture(stone_roughness, p / stone_scale, texture_lod_bias).r;
	vec3 normal = texture(stone_normal, p / stone_scale, texture_lod_bias).rgb;

	vec3 moss = texture(moss_albedo, p / moss_scale, texture_lod_bias).rgb * moss_tint;
	float moss_amount = clamp(pat.g * (0.6 + 0.8 * vnoise(p * 1.7)), 0.0, 1.0);
	albedo = mix(albedo, moss, moss_amount);
	rough = mix(rough, 0.9, moss_amount);

	vec4 b1 = texture(bloom_albedo, p / bloom_scale, texture_lod_bias);
	vec4 b2 = texture(bloom_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (bloom_scale * 1.37) + 0.5, texture_lod_bias);
	float cover = clamp(pat.a * bloom_strength, 0.0, 1.0);
	albedo = mix(albedo, b1.rgb, b1.a * cover);
	albedo = mix(albedo, b2.rgb, b2.a * cover * smoothstep(0.4, 1.0, pat.a));

	// 石材法线（切线空间）上叠加图案的凹凸：x 沿世界 +X，y 沿世界 -Z
	vec3 n = normal * 2.0 - 1.0;
	n.xy += vec2(-slope.x, slope.y);
	ALBEDO = albedo;
	NORMAL_MAP = normalize(n) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
