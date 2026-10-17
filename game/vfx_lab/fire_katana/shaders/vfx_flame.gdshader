shader_type spatial;
// 火团 / 烟团粒子：火焰形状图集 × 滚动噪声，按粒子年龄溶解（课程第 5 集的侵蚀火焰）。
// 透明混合 + HDR 颜色：既有实体又会发光。烟用同一个着色器，把颜色调暗、emission 调到 1。
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://vfx_lab/fire_katana/shaders/vfx_particle.gdshaderinc"

uniform sampler2D shape_tex : hint_default_black, repeat_disable, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec4 hot_color : source_color = vec4(1.0, 0.78, 0.38, 1.0);
uniform vec4 cool_color : source_color = vec4(0.75, 0.1, 0.02, 1.0);
uniform float emission = 3.0;
uniform float opacity = 1.0;
uniform float noise_scale = 0.7;
uniform float noise_speed = 0.9;
uniform float dissolve_softness = 0.25;
uniform float dissolve_start = 0.1;
uniform float cooling = 0.8;
uniform bool billboard = true;   // 关掉时用粒子自身朝向（余火的十字交叉面片）

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
	float shape = texture(shape_tex, UV).r;
	float n = texture(noise_tex, v_quad_uv * noise_scale + vec2(v_seed * 7.3, v_seed * 3.1 - v_age * noise_speed)).r;
	float erode = clamp((v_age - dissolve_start) / max(1.0 - dissolve_start, 0.001), 0.0, 1.0);
	float thr = mix(-dissolve_softness, 1.0, erode);
	float v = shape * mix(0.45, 1.0, n);
	float mask = smoothstep(thr, thr + dissolve_softness, v) * smoothstep(0.0, 0.45, v);
	// 只有火团中心够热才发黄，边缘和老去的部分偏红
	float heat = smoothstep(0.45, 0.95, shape * mix(0.75, 1.0, n) * (1.0 - erode * cooling));
	vec3 edge_color = cool_color.rgb * 0.45;
	vec3 body = mix(edge_color, cool_color.rgb, smoothstep(0.0, 0.5, shape));
	ALBEDO = mix(body, hot_color.rgb, heat) * emission * COLOR.rgb;
	ALPHA = clamp(mask * opacity * COLOR.a, 0.0, 1.0);
}
