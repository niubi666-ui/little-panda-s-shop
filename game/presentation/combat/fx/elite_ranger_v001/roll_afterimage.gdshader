shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 body_tint : source_color;
uniform vec4 rim_tint : source_color;
uniform float energy;
uniform float opacity;
uniform float body_weight;
uniform float rim_power;
uniform float fade_power;
uniform float life;
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),rim_power);
 ALBEDO=mix(body_tint.rgb,rim_tint.rgb,rim)*energy;
 ALPHA=opacity*pow(life,fade_power)*(body_weight+(1.0-body_weight)*rim);
}
