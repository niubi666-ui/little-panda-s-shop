shader_type spatial;
// 火团粒子：大量叠加成一团连续的火（动态火焰那集的做法）。
// 颜色完全由粒子的 Color Ramp 决定（白黄 → 橙 → 红 → 黑烟）；年轻时发光强、老了变成不发光的烟。
// 贴图里的亮纹（火丝）再额外提亮一点，火才有内部细节，不是一块均匀的色片。
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://vfx_lab/fire_katana/shaders/vfx_particle.gdshaderinc"

uniform sampler2D tex : hint_default_black, repeat_disable, filter_linear_mipmap;
uniform float emission_young = 1.25;
uniform float emission_old = 0.8;
uniform float vein_boost = 1.1;
uniform float opacity = 1.15;

void vertex() {
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.61803 + 0.17);
	v_quad_uv = UV;
	UV = atlas_uv(UV, INSTANCE_CUSTOM.z);
	MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX, INSTANCE_CUSTOM.x);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float a = texture(tex, UV).r;
	float glow = mix(emission_young, emission_old, smoothstep(0.25, 0.8, v_age));
	ALBEDO = COLOR.rgb * glow * (0.5 + vein_boost * a);
	ALPHA = clamp(a * opacity * COLOR.a, 0.0, 1.0);
}
