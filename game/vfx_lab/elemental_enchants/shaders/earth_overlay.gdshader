shader_type spatial;
// 刀身岩壳：作为刀身材质的 next_pass。从刀背（UV.x 小）一侧往刃口长出一层粗糙岩壳，
// 岩壳里的裂缝透出金色光（地脉）；heat（这里当作“土的强度”）越高岩壳越厚、裂缝越亮。
// 岩壳是不透明的实体（普通混合 + 简单的朝光明暗），不是发光层。
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;

uniform float heat = 0.0;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D cells_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 rock_dark : source_color = vec3(0.16, 0.13, 0.1);
uniform vec3 rock_light : source_color = vec3(0.42, 0.36, 0.28);
uniform vec3 crack_color : source_color = vec3(1.0, 0.72, 0.28);
uniform float crack_emission = 2.2;
uniform float push = 0.0018;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float n = texture(noise_tex, UV * vec2(1.2, 4.0)).r;
	float p = clamp(heat, 0.0, 1.5);
	// 刀背一侧先长：spine = 1 在刀背，0 在刃口
	float spine = 1.0 - UV.x;
	float thr = mix(1.1, 0.35, clamp(p, 0.0, 1.0));
	float cover = smoothstep(thr, thr + 0.12, spine * 0.75 + n * 0.45) * smoothstep(0.0, 0.05, UV.y);
	if (cover < 0.02) discard;
	float cells = texture(cells_tex, UV * vec2(1.6, 6.0)).r;          // 细胞边缘亮 → 裂缝
	float crack = smoothstep(0.82, 0.95, cells) * smoothstep(0.3, 0.7, cover);
	// 用视线做一点明暗，岩面不会是一块平色
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 rock = mix(rock_dark, rock_light, n * 0.7 + facing * 0.3);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + UV.y * 9.0);
	ALBEDO = mix(rock, crack_color * crack_emission * pulse * (0.4 + 0.6 * min(p, 1.0)), crack);
	ALPHA = clamp(cover, 0.0, 1.0);
}
