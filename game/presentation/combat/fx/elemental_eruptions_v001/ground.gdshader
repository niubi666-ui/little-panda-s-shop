shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 crack_color : source_color;
uniform vec4 glow_color : source_color;
uniform float visual_time;
uniform float anticipation;
uniform float travel;
uniform float duration;
uniform float ice_mode;
uniform float opacity;
uniform float glow_strength;
uniform float pattern_seed;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7))+pattern_seed)*43758.5453);}
vec2 cell_edges(vec2 p) {
 vec2 i=floor(p), f=fract(p); float a=8.0; float b=8.0;
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
 vec2 g=vec2(float(x),float(y)); vec2 o=vec2(hash(i+g),hash(i+g+19.2)); float d=length(g+o-f);
 if(d<a){b=a;a=d;} else if(d<b){b=d;}
 }}return vec2(a,b-a);
}
void fragment(){
 // PlaneMesh UV.y=1 is the caster end; negative Z is the forward direction.
 float path_t=1.0-UV.y;
 vec2 p=vec2((UV.x-0.5)*4.0,path_t*10.0);
 vec2 cells=cell_edges(p*2.4);
 float width=1.0-smoothstep(0.65,1.65,abs(p.x));
 float longitudinal=smoothstep(0.0,0.055,path_t)*(1.0-smoothstep(0.91,1.0,path_t));
 float front=clamp((visual_time-anticipation)/travel,0.0,1.0);
 float wave=1.0-smoothstep(front,front+0.045,path_t);
 float fade=1.0-smoothstep(duration-1.0,duration,visual_time);
 float line=1.0-smoothstep(0.016,0.073,cells.y);
 float halo=exp(-cells.y*19.0);
 float leading=exp(-abs(path_t-front)*55.0)*(1.0-step(1.0,front));
 float grain=hash(floor(p*60.0));
 ALBEDO=crack_color.rgb;
 EMISSION=glow_color.rgb*(line*glow_strength*(0.24+leading*1.5)+halo*0.16*ice_mode);
 ALPHA=clamp((line*0.88+halo*0.2+ice_mode*0.07*grain)*width*longitudinal*wave*fade*opacity,0.0,1.0);
}
