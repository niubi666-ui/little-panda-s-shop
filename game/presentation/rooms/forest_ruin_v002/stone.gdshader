// 石头 / 树皮 / 木头：世界坐标三向投影噪声 + 顶面苔藓 + 缝隙暗化
shader_type spatial;

uniform vec3 color_a : source_color = vec3(0.43, 0.41, 0.37);
uniform vec3 color_b : source_color = vec3(0.61, 0.58, 0.51);
uniform vec3 moss_a : source_color = vec3(0.24, 0.35, 0.13);
uniform vec3 moss_b : source_color = vec3(0.46, 0.57, 0.23);
uniform float scale = 1.2;
uniform vec3 stretch = vec3(1.0);              // 树皮：竖向拉伸纹理
uniform float moss_amount = 1.0;
uniform float moss_min_up = 0.45;
uniform float roughness = 0.85;
uniform float bump = 0.5;

varying vec3 wp;
varying vec3 wn;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; } return v; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = wp * stretch;
	float n1 = fbm(p * scale);
	float nf = fbm(p * scale * 7.0);
	vec3 c = mix(color_a, color_b, smoothstep(0.35, 0.65, n1));
	c = mix(c, c * 0.45, smoothstep(0.3, 0.7, nf) * 0.3);
	float up = smoothstep(moss_min_up, 0.95, wn.y);
	float patch = smoothstep(0.42, 0.58, fbm(wp * 0.9));
	float m = clamp(up * patch * moss_amount + smoothstep(0.6, 0.0, wp.y) * 0.25 * moss_amount * patch, 0.0, 1.0);
	c = mix(c, mix(moss_a, moss_b, nf), m);
	ALBEDO = c;
	ROUGHNESS = mix(roughness, 0.95, m);
	float e = 0.03;
	vec3 g = vec3(fbm((p + vec3(e, 0, 0)) * scale * 7.0) - nf, fbm((p + vec3(0, e, 0)) * scale * 7.0) - nf, fbm((p + vec3(0, 0, e)) * scale * 7.0) - nf) / e;
	vec3 bn = normalize(wn - (g - wn * dot(g, wn)) * bump * 0.02);
	NORMAL = normalize((VIEW_MATRIX * vec4(bn, 0.0)).xyz);
}
