// 地面 / 广场：Blender 俯视烘焙的颜色图 + 世界坐标细节噪声，避免近看糊
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 rect = vec4(-58.0, -72.0, 116.0, 116.0);   // x0, z0, 宽, 深（世界 xz）
uniform float detail_scale = 1.6;
uniform float detail_strength = 0.22;
uniform float roughness_base = 0.9;
uniform float wet_level = -0.05;                         // 低于此高度的地面变湿变亮

varying vec3 world_pos;
varying vec3 world_n;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = (world_pos.xz - rect.xy) / rect.zw;
	vec3 c = texture(albedo_tex, uv).rgb;
	float d = vnoise(world_pos.xz * detail_scale) * 0.6 + vnoise(world_pos.xz * detail_scale * 4.3) * 0.4;
	c *= 1.0 - detail_strength * 0.5 + detail_strength * d;
	float wet = smoothstep(wet_level + 0.15, wet_level - 0.1, world_pos.y);
	ALBEDO = c * mix(1.0, 0.75, wet);
	ROUGHNESS = mix(roughness_base, 0.25, wet);
	// 细节法线：用噪声梯度轻微扰动
	float e = 0.05;
	float h0 = vnoise(world_pos.xz * detail_scale * 4.3);
	vec3 bn = normalize(vec3(h0 - vnoise((world_pos.xz + vec2(e, 0.0)) * detail_scale * 4.3), 4.0 * e * detail_scale, h0 - vnoise((world_pos.xz + vec2(0.0, e)) * detail_scale * 4.3)));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(world_n + vec3(bn.x, 0.0, bn.z) * 0.6), 0.0)).xyz);
}
