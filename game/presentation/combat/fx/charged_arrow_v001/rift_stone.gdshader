shader_type spatial;
render_mode cull_disabled, blend_mix, depth_prepass_alpha;
uniform vec4 top_color : source_color;
uniform vec4 depth_color : source_color;
uniform vec4 glow_color : source_color;
uniform float glow_energy;
uniform float roughness_value;
uniform float travel;
uniform float life;
uniform float time_value;
uniform float grain_scale;
float hash21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
 if(UV.x>travel) discard;
 float n=fract(sin(dot(UV*grain_scale,vec2(12.9898,78.233)))*43758.5453);
 vec2 p=vec2(UV.x*grain_scale*0.35,UV.y*4.0);
 float rock=noise(p+noise(p*0.57)*2.0)*0.7+noise(p*3.1)*0.3;
 float vein=(1.0-smoothstep(0.005,0.04,abs(rock-0.52)))*smoothstep(0.25,0.9,UV.y)*noise(p*0.43+9.0);
 ALBEDO=mix(top_color.rgb,depth_color.rgb,UV.y)*(0.78+n*0.22);
 EMISSION=glow_color.rgb*vein*glow_energy;
 ROUGHNESS=roughness_value;
 ALPHA=life;
}
