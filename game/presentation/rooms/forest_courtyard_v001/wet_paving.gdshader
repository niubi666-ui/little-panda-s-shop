shader_type spatial;
render_mode cull_disabled;
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 wet_a;
uniform vec4 wet_b;
uniform vec4 wet_c;
uniform vec4 wet_d;
uniform vec3 wet_tint : source_color;
uniform float dry_roughness;
uniform float wet_roughness;
uniform float wet_coat_roughness;
varying vec3 world_position;
float wet_mask(vec4 region) {
 float distance = length((world_position.xz - region.xy) / vec2(region.z, region.z * region.w));
 return 1.0 - smoothstep(0.7, 1.3, distance);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float wet = max(max(wet_mask(wet_a), wet_mask(wet_b)), max(wet_mask(wet_c), wet_mask(wet_d)));
 ALBEDO = texture(surface_color, UV).rgb * mix(vec3(1.0), wet_tint, wet);
 ROUGHNESS = mix(dry_roughness, wet_roughness, wet);
 CLEARCOAT = wet;
 CLEARCOAT_ROUGHNESS = wet_coat_roughness;
}
