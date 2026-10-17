shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
// 命中尖刺：几道又尖又白的射线从命中点迸出，先猛地伸长再变细消失。progress 0→1 由 strike_view.gd 推进。
uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.8;
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform int rays = 5;
uniform float ray_width = 0.16;
uniform float core_radius = 0.16;

void vertex() {
	// 面向镜头
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float hash(float x) { return fract(sin(x * 127.1 + seed * 311.7) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float grow = 1.0 - pow(1.0 - clamp(progress * 2.5, 0.0, 1.0), 3.0);
	float thin = 1.0 - smoothstep(0.35, 1.0, progress);
	float alpha = 0.0;
	for (int i = 0; i < rays; i++) {
		float angle = hash(float(i)) * 6.2832;
		float len = mix(0.55, 1.0, hash(float(i) + 7.0)) * grow;
		float diff = abs(mod(a - angle + 3.14159, 6.2832) - 3.14159);
		float width = ray_width * thin * (1.0 - r / max(len, 0.001));
		alpha = max(alpha, step(r, len) * step(diff * r, width));
	}
	alpha = max(alpha, step(r, core_radius * thin * grow));
	ALBEDO = color.rgb * intensity;
	ALPHA = alpha * color.a;
}
