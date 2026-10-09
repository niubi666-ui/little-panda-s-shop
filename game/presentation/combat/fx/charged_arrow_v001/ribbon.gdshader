shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float opacity;
uniform float time_value;
uniform float flow_frequency;
uniform float flow_speed;
void fragment() {
 vec2 uv=clamp(UV,vec2(0.0),vec2(1.0));
 float edge=pow(max(0.0,1.0-abs(uv.y*2.0-1.0)),2.0);
 float stream=0.75+0.25*sin(uv.x*flow_frequency-time_value*flow_speed);
 ALBEDO=tint.rgb*energy;
 ALPHA=edge*stream*opacity*COLOR.a;
}
