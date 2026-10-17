shader_type spatial;
// 挥剑甩出的火星：沿速度拉长（GPUParticles3D 的 transform_align 负责朝向），加色发光。
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;

uniform sampler2D tex : hint_default_white, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform float emission = 5.0;

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb * emission;
	ALPHA = clamp(texture(tex, UV).r * COLOR.a, 0.0, 1.0);
}
