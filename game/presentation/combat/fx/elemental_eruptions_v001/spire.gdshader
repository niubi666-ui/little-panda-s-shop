shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color;
uniform vec4 tip_color : source_color;
uniform vec4 glow_color : source_color;
uniform float roughness_value;
uniform float metallic_value;
uniform float crystal_mode;
uniform float vein_scale;
uniform float emission_strength;
uniform float rim_strength;
uniform float visual_time;
uniform float reveal;
varying vec3 object_pos;
float hash3(vec3 p) { return fract(sin(dot(p, vec3(17.13,113.7,37.9))) * 43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { object_pos=VERTEX; }
void fragment() {
 float h=clamp(object_pos.y,0.0,1.0);
 float n=noise3(object_pos*vein_scale);
 float strata=sin(object_pos.y*27.0+noise3(object_pos*5.0)*4.0)*0.5+0.5;
 float vein_distance=abs(sin((object_pos.x*2.1+object_pos.z*1.4+object_pos.y*0.7+n*0.33)*vein_scale));
 float vein_aa=max(fwidth(vein_distance)*0.65,0.015);
 float veins=1.0-smoothstep(0.055-vein_aa,0.055+vein_aa,vein_distance);
 float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 vec3 stone=mix(base_color.rgb,tip_color.rgb,smoothstep(0.0,1.0,h))*(0.74+n*0.38+strata*0.12);
 vec3 ice=mix(base_color.rgb,tip_color.rgb,clamp(h*0.78+n*0.3,0.0,1.0));
 ALBEDO=mix(stone,ice,crystal_mode)*COLOR.rgb;
 ROUGHNESS=clamp(roughness_value+(n-0.5)*0.12,0.02,1.0);
 METALLIC=metallic_value;
 SPECULAR=0.85;
 float pulse=exp(-visual_time*2.5);
 EMISSION=glow_color.rgb*(veins*emission_strength*(0.25+pulse)*reveal+rim*rim_strength*reveal+crystal_mode*pow(h,5.0)*0.18);
}
