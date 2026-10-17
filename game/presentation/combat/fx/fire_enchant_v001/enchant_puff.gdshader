shader_type spatial;
// 火元素附魔的火团：几百个带火丝的火团叠成一团连续的火（来自 vfx_lab/fire_katana）。
// 颜色由粒子 Color Ramp 决定（白黄 → 橙 → 红 → 黑烟）；年轻时发光强，老了变成不发光的烟。
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D tex : hint_default_black, repeat_disable, filter_linear_mipmap;
uniform int atlas_h = 4;
uniform int atlas_v = 4;
uniform float emission_young = 1.05;
uniform float emission_old = 0.8;
uniform float vein_boost = 1.1;
uniform float opacity = 1.15;
varying float v_age;

void vertex() {
	v_age = INSTANCE_CUSTOM.y;
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
	float glow = mix(emission_young, emission_old, smoothstep(0.25, 0.8, v_age));
	ALBEDO = COLOR.rgb * glow * (0.5 + vein_boost * t);
	ALPHA = clamp(t * opacity * COLOR.a, 0.0, 1.0);
}
