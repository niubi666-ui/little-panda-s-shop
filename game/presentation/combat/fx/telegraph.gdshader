shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 地面攻击预警：柔边 + 亮描边，内部随前摇进度从施放者一侧向外填满。
// UV.x = 横向 0..1（两侧为边），UV.y = 纵向 0..1（0 靠近施放者）。
// 外观参数都在材质 .tres 里（fx/telegraph_*.tres）；color、fill、hot 由代码每帧写入。
uniform vec4 color : source_color;
uniform float fill = 1.0;          // 前摇进度；填满的一刻就是出手
uniform float hot = 0.0;           // 0..1：判定帧，整体提亮

group_uniforms shape;
uniform float edge_soft;           // 两侧柔边宽度（UV 单位）
uniform float rim;                 // 亮描边宽度
uniform float fill_soft;           // 填充前沿的过渡宽度
uniform float front_width;         // 填充前沿亮线的宽度
// 沿视线把预警往镜头方向提前这么多米再做深度测试：地上的草（约半米高）不会把预警挡住。
// 只改深度不改画面位置；站在预警里的角色，脚踝以下会被染上一层预警色。
uniform float depth_pull;

group_uniforms opacity;
uniform float base_alpha;          // 未填充区域的不透明度（相对 color.a）
uniform float filled_alpha;        // 已填充区域的不透明度
// 内部始终保持半透明：预警不能盖住站在里面的角色
uniform float body_alpha_max;
uniform float border_alpha;
uniform float front_alpha;
uniform float hot_alpha;
uniform float max_alpha;

group_uniforms glow;
uniform vec3 highlight : source_color;   // 描边、前沿亮线、判定帧提亮时混入的颜色
uniform float border_glow;
uniform float front_glow;
uniform float hot_glow;
uniform float pulse_speed;         // 呼吸闪动的速度（弧度/秒）
uniform float pulse_scroll;        // 闪动沿纵向的流动
uniform float pulse_depth;         // 闪动幅度

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= max(1.0 - depth_pull / max(length(view.xyz), 0.001), 0.05);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float side = min(UV.x, 1.0 - UV.x);
	float far = 1.0 - UV.y;
	float border = 1.0 - smoothstep(0.0, rim, min(side, far));
	float soft = smoothstep(0.0, edge_soft, side);
	float filled = 1.0 - smoothstep(fill - fill_soft, fill, UV.y);
	// 填充前沿的一道亮线，表示“正在逼近”
	float front = (1.0 - smoothstep(0.0, front_width, abs(UV.y - fill))) * step(fill, 0.995);
	float pulse = 1.0 - pulse_depth + pulse_depth * sin(TIME * pulse_speed - UV.y * pulse_scroll);
	float body = mix(base_alpha, filled_alpha, filled) * soft;
	vec3 tone = mix(color.rgb, highlight, clamp(border * border_glow + front * front_glow + hot * hot_glow, 0.0, 1.0));
	ALBEDO = tone;
	float inside = min(color.a * body * pulse, body_alpha_max) + hot * hot_alpha;
	ALPHA = clamp(inside + color.a * (border * border_alpha + front * front_alpha), 0.0, max_alpha);
}
