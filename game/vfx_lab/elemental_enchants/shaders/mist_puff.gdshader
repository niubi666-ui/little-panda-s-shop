shader_type spatial;
// 寒雾 / 电晕团：软边雾团图集，颜色和透明度由粒子 Color Ramp 决定。
// 寒雾用普通透明混合（白天也看得见白雾），电晕把 additive 调到 1 当发光层用。
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha, fog_disabled;

uniform sampler2D tex : hint_default_black, repeat_disable, filter_linear_mipmap;
uniform int atlas_h = 4;
uniform int atlas_v = 4;
uniform float emission = 1.0;
uniform float opacity = 0.8;
uniform float additive = 0.0;   // 0 = 普通透明混合，1 = 纯加色

void vertex() {
	float hf = float(atlas_h);
	float vf = float(atlas_v);
	float frame = mod(floor(INSTANCE_CUSTOM.z * hf * vf), hf * vf);
	UV = UV / vec2(hf, vf) + vec2(mod(frame, hf) / hf, floor((frame + 0.5) / hf) / vf);
	float a = INSTANCE_CUSTOM.x;
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = texture(tex, UV).r;
	float a = clamp(t * opacity * COLOR.a, 0.0, 1.0);
	// 预乘：颜色按 a 乘进去；ALPHA 决定盖住背景多少（加色时不盖）
	ALBEDO = COLOR.rgb * emission * a;
	ALPHA = a * (1.0 - additive);
}
