shader_type spatial;
render_mode cull_disabled, depth_draw_never;
#include "res://presentation/combat/fx/charged_arrow_v001/rift_cut.gdshaderinc"
uniform vec4 base_tint : source_color;
uniform float roughness_value;
uniform float metallic_value;
uniform float coat;
uniform float coat_roughness;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(inside_rift(world_position))discard;
 ALBEDO=base_tint.rgb;
 ALPHA=base_tint.a;
 ROUGHNESS=roughness_value;
 METALLIC=metallic_value;
 CLEARCOAT=coat;
 CLEARCOAT_ROUGHNESS=coat_roughness;
}
