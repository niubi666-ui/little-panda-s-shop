shader_type spatial;
render_mode specular_disabled;
// Vertex-coloured props (stone, wood, foliage, blossom). No textures.
#include "res://presentation/shared/toon/toon_light.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.0;            // metres of wind sway at sway_height above the origin
uniform float sway_height = 6.0;
uniform float sway_speed = 1.1;
uniform float emission_strength = 0.0;
uniform float translucency = 0.0;    // light let through thin foliage / petals from behind

void vertex() {
	if (sway > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float gust = sin(TIME * sway_speed + world.x * 0.55 + world.z * 0.4) + 0.5 * sin(TIME * sway_speed * 1.9 + world.z * 1.3 + 1.7);
		float amount = sway * clamp(world.y / sway_height, 0.0, 1.0);
		VERTEX.x += gust * amount;
		VERTEX.z += gust * amount * 0.5;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * emission_strength;
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * translucency * max(dot(-NORMAL, LIGHT), 0.0) / PI;
}
