shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float life;
uniform float travel;
uniform float time_value;
void fragment(){
 if(UV.x>travel) discard;
 float edge=pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),2.0);
 ALBEDO=tint.rgb*energy;
 float pockets=0.16+0.84*pow(0.5+0.5*sin(UV.x*39.0+sin(UV.x*101.0)-time_value*1.3),2.0);
 ALPHA=edge*life*pockets;
}
