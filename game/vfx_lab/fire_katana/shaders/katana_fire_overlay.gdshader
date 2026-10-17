shader_type spatial;
// 刀身附魔火层：作为刀身材质的 next_pass 叠在钢面上（相当于课程里的 Material Overlay），不改刀本身的材质。
// 两张噪声往刀尖方向流动、相乘得到火纹；heat 越高阈值越低 → 火纹从刃口开始“长出来”、往刀背蔓延（smoothstep 阈值出现）。
// UV.x：栋(0) → 刃(1)；UV.y：刀根(0) → 刀尖(1)
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float heat = 0.0;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 flow_a = vec2(0.05, -1.6);
uniform vec2 flow_b = vec2(-0.08, -2.7);
uniform vec2 scale_a = vec2(0.8, 3.2);
uniform vec2 scale_b = vec2(1.6, 6.0);
uniform vec3 col_dark : source_color = vec3(0.6, 0.05, 0.0);
uniform vec3 col_mid : source_color = vec3(1.0, 0.36, 0.03);
uniform vec3 col_hot : source_color = vec3(1.0, 0.85, 0.5);
uniform float emission = 2.2;
uniform float push = 0.0012;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float n1 = texture(noise_tex, UV * scale_a + TIME * flow_a).r;
	float n2 = texture(noise_tex, UV * scale_b + TIME * flow_b + vec2(0.37, 0.11)).r;
	float flow = n1 * n2 * 2.2;
	float edge = mix(0.35, 1.0, smoothstep(0.2, 1.0, UV.x));
	float base_fade = smoothstep(0.0, 0.07, UV.y);
	float h = clamp(heat, 0.0, 1.6);
	float thr = mix(1.05, 0.15, clamp(h, 0.0, 1.0));
	float v = flow * edge * base_fade;
	float fire = smoothstep(thr, thr + 0.3, v);
	float temp = clamp(fire * (0.6 + 0.4 * h) + (v - thr) * 0.6, 0.0, 1.0);
	vec3 col = mix(col_dark, col_mid, smoothstep(0.0, 0.5, temp));
	col = mix(col, col_hot, smoothstep(0.55, 1.0, temp));
	ALBEDO = col * emission;
	ALPHA = fire * min(h * 1.5, 1.0);
}
