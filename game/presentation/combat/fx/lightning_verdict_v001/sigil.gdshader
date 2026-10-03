shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float visual_time;
uniform float charge_sec;
uniform float duration_sec;
uniform float energy;
uniform float opacity;
float band(float r,float target,float width){return exp(-pow((r-target)/width,2.0));}
void fragment(){
 vec2 p=(UV-0.5)*2.0;
 float r=length(p),a=atan(p.y,p.x);
 float charge=smoothstep(0.0,charge_sec,visual_time);
 float decay=1.0-smoothstep(charge_sec+0.7,duration_sec,visual_time);
 float outer=band(r,0.66+sin(a*17.0)*0.008,0.008);
 float inner=band(r,0.42,0.005);
 float orbit=band(r,0.55,0.006)*smoothstep(-0.2,0.85,sin(a*7.0+visual_time*1.5));
 float broken=smoothstep(-0.6,0.6,sin(a*11.0))*0.7+0.3;
 float spokes=pow(abs(cos(a*6.0)),40.0)*smoothstep(0.44,0.5,r)*(1.0-smoothstep(0.58,0.64,r));
 float scar=band(r,0.21+sin(a*9.0)*0.012+sin(a*21.0)*0.008,0.006);
 float halo=exp(-r*r*8.0)*0.025;
 ALBEDO=tint.rgb;
 EMISSION=tint.rgb*energy;
 ALPHA=(outer*broken+inner*0.55+orbit*0.7+spokes*0.7+scar+halo)*charge*decay*opacity;
}
