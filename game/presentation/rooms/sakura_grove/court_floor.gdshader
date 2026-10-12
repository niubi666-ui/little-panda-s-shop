shader_type spatial;
render_mode specular_disabled;
// Flagstone court, generated in world space. Cool, quiet stone so that the warm light,
// the petals and the characters carry the colour.
#include "res://presentation/shared/toon/toon_light.gdshaderinc"
#include "res://presentation/rooms/sakura_grove/ground_common.gdshaderinc"

uniform vec2 half_extent = vec2(11.6, 9.6);
uniform vec3 stone_a : source_color = vec3(0.56, 0.54, 0.54);
uniform vec3 stone_b : source_color = vec3(0.67, 0.65, 0.64);
uniform vec3 grout : source_color = vec3(0.34, 0.33, 0.35);
uniform vec3 moss : source_color = vec3(0.34, 0.45, 0.30);
uniform vec3 emblem : source_color = vec3(0.80, 0.74, 0.80);
uniform vec3 petal_a : source_color = vec3(0.93, 0.56, 0.71);
uniform vec3 petal_b : source_color = vec3(0.99, 0.84, 0.89);
uniform float row_height = 1.3;
uniform float wall_shade = 0.7;
uniform float petal_density_centre = 0.02;
uniform float petal_density_edge = 0.34;

varying vec3 world_pos;

float band(float x, float centre, float half_width) {
	return 1.0 - smoothstep(half_width * 0.6, half_width, abs(x - centre));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Running bond with a per-row stone width, and some stones split in two.
	float row = floor(p.y / row_height);
	float width = mix(1.5, 2.4, hash11(row + 3.0));
	float shift = hash11(row * 1.7 + 9.0) * width;
	float column = floor((p.x + shift) / width);
	vec2 local = vec2(fract((p.x + shift) / width) * width, fract(p.y / row_height) * row_height);
	vec2 size = vec2(width, row_height);
	float id = hash21(vec2(column, row));
	if (id > 0.62) {
		float cut = width * mix(0.38, 0.62, hash11(id * 91.0));
		if (local.x > cut) { local.x -= cut; size.x = width - cut; id = fract(id * 7.31); }
		else { size.x = cut; id = fract(id * 3.17); }
	}
	float edge = min(min(local.x, size.x - local.x), min(local.y, size.y - local.y));
	float joint = 1.0 - smoothstep(0.025, 0.06, edge);
	float face = smoothstep(0.05, 0.22, edge);

	vec3 color = mix(stone_a, stone_b, id);
	color *= mix(0.93, 1.0, face);
	color *= 0.95 + 0.1 * vnoise(p * 0.3 + 4.0);

	float border = min(half_extent.x - abs(p.x), half_extent.y - abs(p.y));
	float near_wall = 1.0 - smoothstep(0.2, 4.5, border);
	float patch_noise = vnoise(p * 0.5 + 21.0) * 0.6 + vnoise(p * 1.6 + 5.0) * 0.4;
	float moss_mask = joint * (0.15 + 0.85 * near_wall) + smoothstep(0.66, 0.84, patch_noise + near_wall * 0.32) * 0.7;
	color = mix(color, grout, joint);
	color = mix(color, moss * (0.9 + 0.2 * id), clamp(moss_mask, 0.0, 1.0) * 0.8);

	// Inlaid emblem at the centre of the court: a focal point without any geometry.
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float rings = band(radius, 3.3, 0.07) + band(radius, 3.75, 0.035) + band(radius, 1.0, 0.05);
	float ticks = band(fract(angle / TAU * 16.0), 0.5, 0.06) * step(3.3, radius) * step(radius, 3.75);
	color = mix(color, emblem, clamp(rings + ticks, 0.0, 1.0) * 0.4 * (1.0 - joint));

	// Fallen petals: a light dusting in the middle, drifts along the walls and in the joints.
	float drift = smoothstep(0.45, 0.8, vnoise(p * 0.35 + 50.0));
	float density = mix(petal_density_centre, petal_density_edge, near_wall * near_wall) + drift * 0.12 + joint * 0.1;
	color = apply_petals(color, p, density, petal_a, petal_b);

	// Soft contact shadow where the court meets the walls.
	color *= mix(wall_shade, 1.0, smoothstep(0.0, 1.5, border));

	ALBEDO = color;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
