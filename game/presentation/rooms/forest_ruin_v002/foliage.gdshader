// 叶片 / 草 / 藤蔓：顶点色着色、alpha 剪裁、逆光透光、随风摆动
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = true;
uniform float alpha_cut = 0.5;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.06;                  // 摆动幅度（米）
uniform float sway_height = 6.0;            // 摆动随高度增长的参考高度
uniform float backlight = 0.55;
uniform bool grass_mode = false;            // 草：根部固定、按 UV.y/局部高度弯曲；颜色来自 INSTANCE_CUSTOM

varying float shade;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	if (grass_mode) {
		float k = clamp(VERTEX.y / 0.55, 0.0, 1.0); k *= k;
		vec2 gust = vec2(sin(t * 1.7 + wp.x * 0.35 + wp.z * 0.2), cos(t * 1.3 + wp.z * 0.3)) * 0.5 + vec2(0.3, 0.1);
		VERTEX.xz += (inverse(mat3(MODEL_MATRIX)) * vec3(gust.x, 0.0, gust.y)).xz * k * 0.18;
		COLOR = vec4(mix(vec3(0.23, 0.36, 0.13), vec3(0.6, 0.68, 0.28), INSTANCE_CUSTOM.r) * (0.3 + 0.7 * clamp(VERTEX.y / 0.5, 0.0, 1.0)), 1.0);
	} else {
		float k = clamp((wp.y) / sway_height, 0.0, 1.5);
		vec3 w = vec3(sin(t * 1.1 + wp.x * 0.4 + wp.y * 0.3), sin(t * 2.3 + wp.z * 0.7) * 0.5, cos(t * 0.9 + wp.z * 0.35));
		VERTEX += (inverse(mat3(MODEL_MATRIX)) * w) * sway * k;
	}
	shade = COLOR.a;
}

void fragment() {
	vec4 tex = use_texture ? texture(leaf_tex, UV) : vec4(1.0);
	if (tex.a < alpha_cut) discard;
	ALBEDO = COLOR.rgb * tex.rgb * tint;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
	BACKLIGHT = ALBEDO * backlight + vec3(0.05, 0.06, 0.0) * backlight;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
