shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 熔岩区域：圆形地面上缓慢流动的亮纹。fade 由代码驱动（出现/消失）；颜色和流速在 element_style.tres。
uniform vec4 hot : source_color = vec4(1.0, 0.75, 0.25, 1.0);
uniform vec4 cool : source_color = vec4(0.35, 0.05, 0.02, 1.0);
uniform float flow_speed = 0.25;
uniform float scale = 4.0;
uniform float intensity = 3.0;
uniform float fade = 1.0;

// 沿视线把这块地面效果往镜头方向提前再做深度测试：地上的草（约半米高）不会把它挡住
uniform float depth_pull = 0.9;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= max(1.0 - depth_pull / max(length(view.xyz), 0.001), 0.05);
	POSITION = PROJECTION_MATRIX * view;
}

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * scale;
	float t = TIME * flow_speed;
	float n = noise(p + vec2(t, -t)) * 0.6 + noise(p * 2.1 - vec2(t * 1.3, t * 0.7)) * 0.4;
	float veins = smoothstep(0.45, 0.75, n);
	float r = length(UV - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.75, 1.0, r);
	vec3 col = mix(cool.rgb, hot.rgb * intensity, veins);
	ALBEDO = col;
	ALPHA = edge * fade * mix(0.55, 1.0, veins);
}
