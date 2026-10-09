shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float opacity;
void vertex() {
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment() {
 vec2 p = (clamp(UV, vec2(0.0), vec2(1.0)) - 0.5) * 2.0;
 float radial = max(0.0, 1.0-dot(p,p));
 float swirl = 0.65 + 0.35*sin(p.x*8.0+p.y*6.0)*sin(p.y*11.0-p.x*4.0);
 ALBEDO=tint.rgb;
 ALPHA=radial*radial*swirl*opacity*COLOR.a;
}
