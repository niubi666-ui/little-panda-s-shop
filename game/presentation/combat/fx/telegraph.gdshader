shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 地面攻击预警：柔边 + 亮描边，内部随前摇进度从施放者一侧向外填满。
// UV.x = 横向 0..1（两侧为边），UV.y = 纵向 0..1（0 靠近施放者）。
uniform vec4 color : source_color = vec4(1.0, 0.3, 0.1, 0.5);
uniform float fill = 1.0;          // 前摇进度；填满的一刻就是出手
uniform float edge_soft = 0.14;
uniform float rim = 0.05;
uniform float base_alpha = 0.28;   // 未填充区域的不透明度（相对 color.a）
uniform float hot = 0.0;           // 0..1：判定帧，整体提亮

void fragment() {
	float side = min(UV.x, 1.0 - UV.x);
	float far = 1.0 - UV.y;
	float border = 1.0 - smoothstep(0.0, rim, min(side, far));
	float soft = smoothstep(0.0, edge_soft, side);
	float filled = 1.0 - smoothstep(fill - 0.03, fill, UV.y);
	// 填充前沿的一道亮线，表示“正在逼近”
	float front = (1.0 - smoothstep(0.0, 0.05, abs(UV.y - fill))) * step(fill, 0.995);
	float pulse = 0.88 + 0.12 * sin(TIME * 12.0 - UV.y * 8.0);
	// 内部始终保持半透明：预警不能盖住站在里面的角色。
	float body = mix(base_alpha, 0.62, filled) * soft;
	vec3 tone = mix(color.rgb, vec3(1.0, 0.95, 0.85), clamp(border * 0.55 + front * 0.6 + hot * 0.2, 0.0, 1.0));
	ALBEDO = tone;
	float inside = min(color.a * body * pulse, 0.46) + hot * 0.08;
	ALPHA = clamp(inside + color.a * (border * 0.9 + front * 0.8), 0.0, 0.95);
}
