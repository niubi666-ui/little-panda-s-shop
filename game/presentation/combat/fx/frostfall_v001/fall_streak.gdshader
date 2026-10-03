shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float intensity;
uniform float visual_time;
uniform float filament_density;
uniform float flow_speed;
void fragment(){
 float along=clamp(UV.y,0.0,1.0);
 float width=mix(0.12,1.0,sqrt(along));
 float x=(UV.x-0.5)*2.0/width;
 float soft=exp(-x*x*5.0);
 float core=exp(-x*x*60.0);
 float ribs=pow(abs(sin(UV.x*filament_density+sin(UV.y*13.0-visual_time*flow_speed)*0.7)),8.0);
 float end=smoothstep(0.0,0.22,along)*(1.0-smoothstep(0.85,1.0,along));
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*energy;
 ALPHA=clamp((core*0.6+soft*(0.15+ribs*0.17))*end*intensity,0.0,1.0);
}
