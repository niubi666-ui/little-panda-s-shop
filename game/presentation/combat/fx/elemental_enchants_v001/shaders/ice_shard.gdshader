shader_type spatial;
// 冰晶（甩出的冰碴、受击冰刺）：受场景光照的半透明玻璃感——高光强、边缘（菲涅尔）发冷光、中间透。
// 粒子用时 COLOR.a 来自 Color Ramp（落地后淡出）。
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.72, 0.88, 1.0);
uniform vec3 rim_color : source_color = vec3(0.6, 0.85, 1.0);
uniform float rim_power = 2.2;
uniform float rim_emission = 1.2;
uniform float body_alpha = 0.35;
uniform float edge_alpha = 0.95;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = tint * 0.55;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = rim_color * fres * rim_emission + tint * 0.12;
	ALPHA = clamp(mix(body_alpha, edge_alpha, fres) * COLOR.a, 0.0, 1.0);
}
