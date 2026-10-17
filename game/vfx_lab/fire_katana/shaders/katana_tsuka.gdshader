shader_type spatial;
// 太刀柄：黑色柄卷（菱形交叉编织）+ 菱形窗里露出白色鲛皮颗粒。
// UV.x：绕柄一圈；UV.y：沿柄长度

uniform vec3 ito_color : source_color = vec3(0.035, 0.032, 0.04);
uniform vec3 same_color : source_color = vec3(0.8, 0.78, 0.72);
uniform float wraps = 9.0;
uniform float band_half_width = 0.36;
uniform float normal_strength = 1.4;

float wrap_height(vec2 uv, out float coverage) {
	float s = uv.y * wraps;
	float c = uv.x * 2.0;
	float b1 = fract(s + c);
	float b2 = fract(s - c);
	float d1 = abs(b1 - 0.5);
	float d2 = abs(b2 - 0.5);
	float band1 = smoothstep(band_half_width, band_half_width - 0.05, d1);
	float band2 = smoothstep(band_half_width, band_half_width - 0.05, d2);
	float cell = mod(floor(s + c) + floor(s - c), 2.0);
	float fiber1 = 0.85 + 0.15 * sin((b2) * 70.0);
	float fiber2 = 0.85 + 0.15 * sin((b1) * 70.0);
	float h1 = band1 * cos(d1 / band_half_width * 1.4) * fiber1 * (cell > 0.5 ? 1.0 : 0.75);
	float h2 = band2 * cos(d2 / band_half_width * 1.4) * fiber2 * (cell > 0.5 ? 0.75 : 1.0);
	coverage = max(band1, band2);
	float dots = 0.5 + 0.5 * sin(uv.x * 420.0) * sin(uv.y * 300.0);
	return max(max(h1, h2), 0.15 * dots * (1.0 - coverage));
}

void fragment() {
	float cov;
	float h = wrap_height(UV, cov);
	float c2;
	float hx = wrap_height(UV + vec2(0.002, 0.0), c2);
	float hy = wrap_height(UV + vec2(0.0, 0.002), c2);
	vec3 n = normalize(vec3((h - hx) * normal_strength, (h - hy) * normal_strength, 0.05));
	NORMAL_MAP = n * 0.5 + 0.5;
	float dots = 0.5 + 0.5 * sin(UV.x * 420.0) * sin(UV.y * 300.0);
	vec3 same = same_color * (0.8 + 0.2 * dots);
	ALBEDO = mix(same, ito_color * (0.7 + 0.5 * h), cov);
	ROUGHNESS = mix(0.55, 0.62, cov);
	SPECULAR = mix(0.4, 0.55, cov);
}
