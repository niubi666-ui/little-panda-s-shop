shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// 敌人脚下的元素光环：带呼吸的亮环 + 淡淡的内圈。颜色由代码按元素设置，其余参数在 status_ring.tres。
uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.12;
uniform float intensity = 2.0;
uniform float fill = 0.15;
uniform float pulse_speed = 5.0;
uniform float pulse_depth = 0.35;
// 层数越多越亮（代码写入 0..1）
uniform float strength = 1.0;

// 沿视线把这块地面效果往镜头方向提前再做深度测试：地上的草（约半米高）不会把它挡住
uniform float depth_pull = 0.9;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= max(1.0 - depth_pull / max(length(view.xyz), 0.001), 0.05);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(r - (1.0 - thickness)));
	float inner = (1.0 - smoothstep(0.6, 1.0, r)) * fill;
	float pulse = 1.0 - pulse_depth + pulse_depth * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp((ring + inner) * pulse * mix(0.55, 1.0, strength) * color.a, 0.0, 1.0) * step(r, 1.0);
}
