shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 月牙刀光：UV.x 沿刀路（0 起点 → 1 终点），UV.y 横向（arc：0 内缘 → 1 外缘；thrust：两边 → 中线）。
// 外缘锐利的实心白，往内变成会散开的灰烟；两头收尖。reveal / fade 由 strike_view.gd 推进。
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 smoke_color : source_color = vec4(0.6, 0.62, 0.64, 1.0);
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float intensity = 1.5;
uniform float reveal = 1.0;
uniform float fade = 0.0;
uniform float thrust = 0.0;
uniform float seed = 0.0;
// 实心白占带宽的比例（从外缘算起）、烟雾的碎度
uniform float solid_fraction = 0.45;
uniform float wisp_scale = 14.0;
uniform float taper_power = 0.55;
uniform float wisp_alpha = 0.9;
// 沿视线往镜头方向提前做深度测试：不被地上的草挡住
uniform float depth_pull = 1.2;

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
	float u = UV.x;
	if (u > reveal) discard;
	float band = mix(UV.y, 1.0 - abs(UV.y * 2.0 - 1.0), thrust);
	// 已扫出部分的两头收尖：尾巴长、头部短
	float along = clamp(u / max(reveal, 0.001), 0.0, 1.0);
	float profile = pow(sin(along * 3.14159), taper_power);
	float depth = (band - (1.0 - profile)) / max(profile, 0.001);
	if (depth < 0.0) discard;
	float n = noise(vec2(u * wisp_scale + seed, band * 5.0 + seed * 0.7));
	float solid = smoothstep(1.0 - solid_fraction - 0.08, 1.0 - solid_fraction + 0.04, depth);
	// 烟雾：越靠外越浓，被噪声撕成丝缕
	float wisp = smoothstep(0.05, 0.75, depth - (1.0 - n) * 0.5) * pow(depth, 1.6);
	float edge = 1.0 - smoothstep(0.985, 1.0, band);
	float alpha = max(solid, wisp * wisp_alpha) * edge;
	// 消散：从内缘烟雾先散，最后才轮到外缘
	float d = noise(vec2(u * 9.0 + 3.1 + seed, UV.y * 7.0)) * 0.6 + depth * 0.4;
	alpha *= smoothstep(fade, fade + 0.12, d);
	// 烟雾靠近白边处渐亮，衔接成一道光滑的渐变
	vec3 color = mix(smoke_color.rgb, core_color.rgb, max(solid, smoothstep(0.4, 1.0 - solid_fraction, depth) * 0.6));
	color = mix(color, tint_color.rgb, tint_amount * (1.0 - solid * 0.7));
	ALBEDO = color * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
