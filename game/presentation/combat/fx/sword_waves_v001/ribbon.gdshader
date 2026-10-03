shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float visual_time;
uniform float opacity;
uniform float wave_amount;
uniform float exit_progress;
void vertex(){
 VERTEX.y+=sin(UV.x*11.0-visual_time*13.0+COLOR.r*9.0)*UV.x*wave_amount;
 VERTEX.x+=sin(UV.x*7.0-visual_time*8.0+COLOR.r*12.0)*UV.x*wave_amount;
}
void fragment(){
 float lateral=pow(max(sin(UV.y*3.14159265),0.0),1.8);
 float length_fade=pow(1.0-UV.x,1.5)*smoothstep(0.0,0.065,UV.x);
 float flow=0.55+0.45*sin(UV.x*37.0-visual_time*23.0+COLOR.r*13.0);
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*energy;
 ALPHA=lateral*length_fade*flow*opacity*(1.0-exit_progress);
}
