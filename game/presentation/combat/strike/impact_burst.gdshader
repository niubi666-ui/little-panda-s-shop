shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
// 重击/击杀爆团：一团带尖角的灰白色爆开形状，中心更白，快速胀开后从边缘碎散。progress 0→1 由 strike_view.gd 推进。
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 body_color : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform float intensity = 1.4;
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform float spikes = 7.0;
uniform float spike_length = 0.35;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
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
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float grow = 1.0 - pow(1.0 - clamp(progress * 3.0, 0.0, 1.0), 3.0);
	// 轮廓：块状起伏 + 尖角
	float lumpy = 0.42 + 0.18 * noise(vec2(a * 2.2 + seed, seed));
	float spike = pow(max(0.0, cos(a * spikes + seed * 3.0)), 24.0) * spike_length * (0.6 + 0.4 * hash(vec2(floor((a + 3.14159) * spikes / 6.2832), seed)));
	float outline = (lumpy + spike) * grow;
	float inside = 1.0 - smoothstep(outline - 0.015, outline, r);
	// 碎散：从外往里被噪声吃掉
	float eat = smoothstep(0.35, 1.0, progress);
	float n = noise(p * 6.0 + seed) * 0.7 + (1.0 - r / max(outline, 0.001)) * 0.3;
	inside *= step(eat, n);
	float core = 1.0 - smoothstep(0.0, outline * 0.55, r);
	ALBEDO = mix(body_color.rgb, core_color.rgb, core) * intensity;
	ALPHA = inside;
}
