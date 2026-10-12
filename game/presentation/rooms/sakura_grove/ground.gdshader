shader_type spatial;
render_mode specular_disabled;
// Grass outside the court: soft greens under a carpet of petals, a dirt path through
// both gates, darkening with distance so the court stays the focus.
#include "res://presentation/shared/toon/toon_light.gdshaderinc"
#include "res://presentation/rooms/sakura_grove/ground_common.gdshaderinc"

uniform vec2 court_half = vec2(11.9, 9.9);
uniform vec3 grass_a : source_color = vec3(0.25, 0.42, 0.28);
uniform vec3 grass_b : source_color = vec3(0.42, 0.58, 0.32);
uniform vec3 dirt : source_color = vec3(0.47, 0.40, 0.36);
uniform vec3 petal_a : source_color = vec3(0.93, 0.56, 0.71);
uniform vec3 petal_b : source_color = vec3(0.99, 0.84, 0.89);
uniform float path_half_width = 1.7;
uniform float falloff_start = 9.0;
uniform float falloff_end = 34.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float blotch = vnoise(p * 0.22) * 0.65 + vnoise(p * 0.7 + 8.0) * 0.35;
	vec3 color = mix(grass_a, grass_b, smoothstep(0.3, 0.7, blotch));
	float wobble = (vnoise(p * 0.4 + 3.0) - 0.5) * 1.6;
	float path = 1.0 - smoothstep(path_half_width * 0.55, path_half_width, abs(p.x + wobble));
	path *= step(court_half.y - 0.4, abs(p.y));
	color = mix(color, dirt * (0.92 + 0.16 * vnoise(p * 1.3)), path * 0.9);
	// Petal carpet: thick drifts with clearer patches between them.
	float drift = smoothstep(0.3, 0.75, vnoise(p * 0.3 + 70.0) * 0.6 + vnoise(p * 0.9 + 11.0) * 0.4);
	color = apply_petals(color, p, 0.1 + drift * 0.42, petal_a, petal_b);
	color = mix(color, mix(petal_a, petal_b, 0.4), drift * 0.14);
	vec2 outside = max(abs(p) - court_half, vec2(0.0));
	float distance_out = length(outside);
	color *= mix(0.72, 1.0, smoothstep(0.0, 1.4, distance_out));           // contact shade at the walls
	color *= mix(1.0, 0.45, smoothstep(falloff_start, falloff_end, distance_out));
	ALBEDO = color;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
