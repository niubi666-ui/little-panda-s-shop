shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec4 body_color : source_color;
uniform vec4 edge_color : source_color;
uniform vec4 vein_color : source_color;
uniform float roughness_value;
uniform float crystal;
uniform float emission_strength;
uniform float visual_time;
uniform float exit_progress;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
 float dissolve=clamp(exit_progress*3.0,0.0,1.0);
 float grain=fract(sin(dot(floor(local_pos*130.0),vec3(17.1,113.7,41.3)))*43758.54);
 if(grain<dissolve){discard;}
 float edge=1.0-smoothstep(0.04,0.38,UV.y);
 float facet=0.5+0.5*sin(local_pos.x*22.0+local_pos.z*9.0);
 float vein_d=abs(sin(local_pos.x*11.0+local_pos.z*17.0+sin(local_pos.x*9.0)*0.5));
 float vein_aa=max(fwidth(vein_d),0.012);
 float vein=1.0-smoothstep(0.04-vein_aa,0.04+vein_aa,vein_d);
 float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 ALBEDO=mix(body_color.rgb,edge_color.rgb,edge*0.9)*(0.9+facet*0.1);
 METALLIC=mix(0.38,0.12,crystal);
 ROUGHNESS=roughness_value;
 SPECULAR=0.8;
 EMISSION=edge_color.rgb*edge*emission_strength+vein_color.rgb*(rim*0.3+vein*crystal*0.7)*(0.88+sin(visual_time*13.0+local_pos.x*6.0)*0.12);
}
