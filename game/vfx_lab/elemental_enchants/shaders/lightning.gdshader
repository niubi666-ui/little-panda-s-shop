shader_type spatial;
// 闪电带子：UV.y 横跨带宽（0..1），中线最亮；COLOR.a 是这条闪电当前的亮度（寿命 + 闪烁）。
// 辉光层和白芯层用同一个着色器，颜色和 falloff 不同。
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.7, 1.0, 1.0);
uniform float emission = 4.0;
uniform float falloff = 3.0;

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float v = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	ALBEDO = color.rgb * emission;
	ALPHA = clamp(v * COLOR.a, 0.0, 1.0);
}
