shader_type spatial;
// 火焰本体 / 烟：普通透明混合 + HDR 颜色。亮地面上也有实体感，同时会被 Glow 带出光晕。
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://vfx_lab/fire_katana/shaders/fire_ribbon.gdshaderinc"

void fragment() {
	float temp;
	float m = ribbon_mask(UV, UV2, temp);
	ALBEDO = mix(color_old.rgb, color_new.rgb, temp) * emission;
	ALPHA = clamp(m * opacity, 0.0, 1.0);
}
