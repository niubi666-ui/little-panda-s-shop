shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 base_tint : source_color;
uniform vec4 top_tint : source_color;
uniform float energy;
uniform float opacity;
uniform float life;
uniform float travel;
uniform float rise;
uniform float time_value;
uniform float tick_sec;
uniform float plume_scale;
uniform float flow_speed;
uniform float vertical_power;
uniform float layer_phase;
float hash21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p){return noise(p)*0.57+noise(p*2.03+17.2)*0.29+noise(p*4.17+41.1)*0.14;}
void vertex(){VERTEX.y*=rise;}
void fragment(){
 if(UV.x>travel) discard;
 float y=clamp(UV.y,0.0,1.0);
 vec2 p=vec2(UV.x*plume_scale,y*3.6-time_value*flow_speed)+vec2(layer_phase,layer_phase*0.37);
 vec2 warp=vec2(fbm(p*0.71+vec2(0,time_value*0.11)),fbm(p*0.93+vec2(8,0)))-0.5;
 float cloud=fbm(p+warp*2.6);
 float cluster=noise(vec2(UV.x*plume_scale*0.57+layer_phase,y*1.4-time_value*0.19));
 float density=smoothstep(0.32+y*0.25,0.68+y*0.20,cloud+cluster*0.10);
 float feet=exp(-y*20.0)*(0.025+cloud*0.10);
 float pockets=smoothstep(0.17,0.60,cluster);
 float veil=density*pow(1.0-y,vertical_power)*pockets+feet;
 float edge=smoothstep(0.0,0.024,UV.x)*(1.0-smoothstep(0.955,1.0,UV.x));
 float pulse=pow(1.0-fract(time_value/tick_sec),5.0);
 ALBEDO=mix(base_tint.rgb,top_tint.rgb,smoothstep(0.04,0.74,y))*energy;
 ALPHA=veil*opacity*life*edge*(1.0+pulse*0.16);
}
