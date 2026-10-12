// 森林遗迹溪流：屏幕空间折射 + 深度吸收 + 顺流波纹 + 白沫（白沫强度来自顶点色 R）
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.55, 0.72, 0.64);
uniform vec3 deep_color : source_color = vec3(0.05, 0.17, 0.15);
uniform float absorb_depth = 0.9;
uniform vec2 flow = vec2(0.0, 0.55);          // 世界 xz 方向，溪流整体向 +z（镜头方向）流
uniform float ripple_strength = 0.35;
uniform float refraction = 0.025;

varying vec3 world_pos;
varying float foam_v;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.07 + 13.1; a *= 0.5; } return v; }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	foam_v = COLOR.r;
}

float waves(vec2 p) {
	vec2 q = p * vec2(1.0, 0.35);
	return fbm(q * 2.4 - flow * TIME * 1.6) * 0.65 + fbm(q * 6.0 - flow * TIME * 2.6 + 7.0) * 0.35;
}

void fragment() {
	vec2 p = world_pos.xz;
	float e = 0.06;
	float h0 = waves(p);
	vec3 n = normalize(vec3((h0 - waves(p + vec2(e, 0))) * ripple_strength / e, 1.0, (h0 - waves(p + vec2(0, e))) * ripple_strength / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// 水深：场景深度 - 水面深度
	float zs = texture(depth_tex, SCREEN_UV).r;
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zs, 1.0);
	float scene_d = -vpos.z / vpos.w;
	float depth = clamp(scene_d - (-VERTEX.z), 0.0, 10.0);

	vec2 ruv = SCREEN_UV + n.xz * refraction * clamp(depth * 2.0, 0.0, 1.0);
	float zr = texture(depth_tex, ruv).r;
	vec4 vr = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, zr, 1.0);
	if (-vr.z / vr.w < -VERTEX.z) ruv = SCREEN_UV;          // 折射采到水面前方的物体时退回
	vec3 under = textureLod(screen_tex, ruv, 0.0).rgb;

	float t = 1.0 - exp(-depth / absorb_depth);
	vec3 col = mix(under * shallow_color * 1.25, deep_color, t);

	// 白沫：顶点色给出位置，噪声给出破碎形态，并顺流移动
	float fn = fbm(p * vec2(3.0, 1.2) * 1.6 - flow * TIME * 1.8);
	float edge_foam = smoothstep(0.12, 0.0, depth) * 0.8;
	float foam = clamp(smoothstep(0.35, 0.75, foam_v * 0.9 + fn * 0.55) + edge_foam * fn, 0.0, 1.0);
	col = mix(col, vec3(0.93, 0.96, 0.94), foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.04, 0.6, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = clamp(0.88 + foam, 0.0, 1.0) * smoothstep(0.0, 0.04, depth + foam_v * 0.04);
}
