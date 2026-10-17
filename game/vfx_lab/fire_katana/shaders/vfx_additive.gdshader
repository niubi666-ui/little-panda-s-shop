shader_type spatial;
// 发光类粒子（火星、闪光、冲击环、刀口月牙、蓄力光点）：灰度贴图 × 粒子颜色 × HDR，加色混合。
// billboard 关掉时用粒子自己的朝向（速度对齐的火星、贴在挥砍平面上的月牙）。
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
#include "res://vfx_lab/fire_katana/shaders/vfx_particle.gdshaderinc"

uniform sampler2D tex : hint_default_white, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float emission = 4.0;
uniform bool billboard = true;

void vertex() {
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.61803 + 0.17);
	v_quad_uv = UV;
	UV = atlas_uv(UV, INSTANCE_CUSTOM.z);
	if (billboard) {
		MODELVIEW_MATRIX = billboard_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX, INSTANCE_CUSTOM.x);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float a = texture(tex, UV).r;
	ALBEDO = tint.rgb * COLOR.rgb * emission;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
