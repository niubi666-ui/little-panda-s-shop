shader_type spatial;
// 闪光点（冰晶、电火花）：星芒/软点贴图，加色；twinkle > 0 时每颗按自己的节奏闪烁。
// billboard 关掉时用粒子自身朝向（速度对齐的电火花）。
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

uniform sampler2D tex : hint_default_white, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float emission = 4.0;
uniform float twinkle = 0.0;
uniform float twinkle_speed = 14.0;
uniform bool billboard = true;
varying float v_seed;

void vertex() {
	v_seed = fract(float(INSTANCE_ID) * 0.61803 + 0.29);
	if (billboard) {
		float a = INSTANCE_CUSTOM.x;
		mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float t = texture(tex, UV).r;
	float tw = 1.0;
	if (twinkle > 0.0) {
		tw = mix(1.0, pow(0.5 + 0.5 * sin(TIME * twinkle_speed * (0.6 + v_seed) + v_seed * 40.0), 3.0), twinkle);
	}
	ALBEDO = tint.rgb * COLOR.rgb * emission;
	ALPHA = clamp(t * COLOR.a * tw, 0.0, 1.0);
}
