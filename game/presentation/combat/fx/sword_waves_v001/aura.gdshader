shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float emission_strength;
uniform float opacity;
uniform float visual_time;
uniform float exit_progress;
void fragment(){
 float end_fade=pow(max(sin(UV.x*3.14159265),0.0),0.55);
 float edge=exp(-UV.y*4.0);
 float streak=0.72+0.28*sin(UV.x*47.0-visual_time*12.0);
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*emission_strength;
 ALPHA=end_fade*edge*streak*opacity*(1.0-exit_progress);
}
