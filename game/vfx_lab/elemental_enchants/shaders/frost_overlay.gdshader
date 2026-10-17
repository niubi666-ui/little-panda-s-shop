shader_type spatial;
// 刀身结霜：作为刀身材质的 next_pass。冰晶网纹（细胞噪声的边）× 覆盖遮罩，从刃口往刀背长；
// heat（这里当作“寒气强度”）越高霜越多。霜是白色哑光层（普通混合），里面夹着会闪的冰晶亮点。
// UV.x：栋(0) → 刃(1)；UV.y：刀根(0) → 刀尖(1)
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

uniform float heat = 0.0;
uniform sampler2D cells_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 frost_color : source_color = vec3(0.86, 0.94, 1.0);
uniform vec3 deep_color : source_color = vec3(0.55, 0.78, 1.0);
uniform float emission = 1.1;
uniform float push = 0.0012;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float cells = texture(cells_tex, UV * vec2(1.4, 5.0)).r;          // 边缘处亮
	float n = texture(noise_tex, UV * vec2(0.9, 3.0)).r;
	float edge = smoothstep(0.15, 1.0, UV.x);
	float p = clamp(heat, 0.0, 1.5);
	float thr = mix(1.1, 0.25, clamp(p, 0.0, 1.0));
	float cover = smoothstep(thr, thr + 0.25, edge * 0.7 + n * 0.5);
	float lines = smoothstep(0.55, 0.85, cells);
	float frost = clamp(cover * (0.45 + 0.55 * lines), 0.0, 1.0) * smoothstep(0.0, 0.06, UV.y);
	// 冰晶闪点：高频噪声过阈值，随时间换位置
	float sp = texture(noise_tex, UV * vec2(9.0, 40.0) + vec2(floor(TIME * 6.0) * 0.137, 0.0)).r;
	float sparkle = smoothstep(0.82, 0.9, sp) * cover;
	vec3 col = mix(deep_color, frost_color, lines) * emission + vec3(1.0) * sparkle * 2.5;
	ALBEDO = col;
	ALPHA = clamp(frost * 0.85 + sparkle, 0.0, 1.0);
}
