shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// 反应冲击波：贴地扩散的光环。progress 0→1 由代码推进；颜色、厚度在 element_style.tres。
uniform vec4 color : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float thickness = 0.12;     // 环宽（相对半径）
uniform float intensity = 2.5;

// 沿视线把这块地面效果往镜头方向提前再做深度测试：地上的草（约半米高）不会把它挡住
uniform float depth_pull = 0.9;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= max(1.0 - depth_pull / max(length(view.xyz), 0.001), 0.05);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(r - progress));
	float inner = (1.0 - smoothstep(0.0, progress, r)) * 0.18;
	float fade = 1.0 - progress;
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp((ring + inner) * fade * color.a, 0.0, 1.0);
}
