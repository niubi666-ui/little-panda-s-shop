shader_type spatial;
// 太刀刀身：钢面 + 波浪刃文；heat 0..1.5 时刃口先烧红，火纹沿刀身往上爬。
// UV.x：栋(0) → 刃(1)；UV.y：刀根(0) → 刀尖(1)

uniform vec3 steel_color : source_color = vec3(0.6, 0.61, 0.64);
uniform vec3 hamon_color : source_color = vec3(0.85, 0.86, 0.87);
uniform float steel_roughness = 0.14;
uniform float hamon_roughness = 0.32;
uniform float hamon_base = 0.64;
uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float heat = 0.0;
uniform vec3 heat_dark : source_color = vec3(0.45, 0.03, 0.0);
uniform vec3 heat_mid : source_color = vec3(1.0, 0.32, 0.02);
uniform vec3 heat_hot : source_color = vec3(1.0, 0.82, 0.45);
uniform float heat_emission = 5.0;
uniform float crawl_speed = 1.4;

void fragment() {
	float u = UV.x;
	float t = UV.y;
	float n = texture(detail_noise, vec2(u * 0.6, t * 4.0)).r;
	float hamon = hamon_base + 0.045 * sin(t * 55.0) + 0.022 * sin(t * 131.0 + 1.7) + 0.06 * (n - 0.5);
	float in_hamon = smoothstep(hamon - 0.02, hamon + 0.02, u);
	float polish = texture(detail_noise, vec2(u * 3.0, t * 0.35)).r;
	vec3 base = mix(steel_color, hamon_color, in_hamon);
	float h = clamp(heat, 0.0, 2.0);
	ALBEDO = base * mix(1.0, 0.45, clamp(h, 0.0, 1.0));
	METALLIC = mix(0.95, 0.7, in_hamon);
	ROUGHNESS = clamp(mix(steel_roughness, hamon_roughness, in_hamon) + (polish - 0.5) * 0.08 + h * 0.15, 0.04, 1.0);

	float crawl = texture(detail_noise, vec2(u * 1.3 + TIME * 0.05, t * 5.0 - TIME * crawl_speed)).r;
	float edge = smoothstep(0.3, 1.0, u);
	float glow = h * mix(0.3, 1.0, edge) * (0.55 + 0.9 * crawl);
	glow *= smoothstep(0.0, 0.06, t);
	vec3 hc = mix(heat_dark, heat_mid, clamp(glow * 2.0, 0.0, 1.0));
	hc = mix(hc, heat_hot, clamp(glow - 0.6, 0.0, 1.0));
	EMISSION = hc * glow * heat_emission;
}
