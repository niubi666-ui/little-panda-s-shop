shader_type spatial;
// 刀光最外沿的白热细线：加色混合
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
#include "res://vfx_lab/fire_katana/shaders/fire_ribbon.gdshaderinc"

void fragment() {
	float temp;
	float m = ribbon_mask(UV, UV2, temp);
	ALBEDO = mix(color_old.rgb, color_new.rgb, temp) * emission;
	ALPHA = clamp(m * opacity, 0.0, 1.0);
}
