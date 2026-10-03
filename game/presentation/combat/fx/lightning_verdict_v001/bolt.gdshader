shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float intensity;
uniform float visual_time;
uniform float softness;
void fragment(){
 float transverse=abs(UV.y*2.0-1.0);
 float filament=exp(-transverse*transverse*softness);
 float flow=0.9+0.1*sin(UV.x*81.0-visual_time*37.0);
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*energy;
 ALPHA=filament*flow*intensity;
}
