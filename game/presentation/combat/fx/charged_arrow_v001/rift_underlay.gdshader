shader_type spatial;
render_mode cull_disabled;
#include "res://presentation/combat/fx/charged_arrow_v001/rift_cut.gdshaderinc"
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_texture;
uniform vec4 base_tint : source_color;
uniform float roughness_value;
uniform float metallic_value;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(inside_rift(world_position))discard;
 ALBEDO=base_tint.rgb*(use_texture?texture(surface_color,UV).rgb:vec3(1));
 ROUGHNESS=roughness_value;
 METALLIC=metallic_value;
}
