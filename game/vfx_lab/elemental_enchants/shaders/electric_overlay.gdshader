shader_type spatial;
// 刀身电纹：作为刀身材质的 next_pass。噪声的“山脊”取成细亮线，位置每隔几十毫秒跳一次（电流感，不是平滑流动）；
// heat（这里当作“电量”）越高线越多越亮。加色。
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float heat = 0.0;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 core_color : source_color = vec3(0.85, 0.92, 1.0);
uniform vec3 glow_color : source_color = vec3(0.35, 0.5, 1.0);
uniform float emission = 3.5;
uniform float jump_rate = 22.0;
uniform float push = 0.0012;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float step_t = floor(TIME * jump_rate);
	vec2 jitter = vec2(fract(step_t * 0.618), fract(step_t * 0.381));
	float n = texture(noise_tex, UV * vec2(1.2, 4.0) + jitter).r;
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float n2 = texture(noise_tex, UV * vec2(2.5, 9.0) - jitter * 1.7).r;
	float ridge2 = 1.0 - abs(n2 * 2.0 - 1.0);
	float p = clamp(heat, 0.0, 1.5);
	float width = mix(0.985, 0.94, clamp(p, 0.0, 1.0));
	float core = smoothstep(width, 1.0, ridge) + smoothstep(width + 0.01, 1.0, ridge2) * 0.7;
	float glow = smoothstep(width - 0.08, 1.0, ridge) * 0.35;
	float mask = mix(0.4, 1.0, smoothstep(0.2, 1.0, UV.x)) * smoothstep(0.0, 0.06, UV.y);
	vec3 col = core_color * core + glow_color * glow;
	ALBEDO = col * emission;
	ALPHA = clamp((core + glow) * mask * min(p * 1.4, 1.0), 0.0, 1.0);
}
