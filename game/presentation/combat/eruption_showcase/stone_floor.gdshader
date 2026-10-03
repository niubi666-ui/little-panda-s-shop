shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 stone_dark : source_color;
uniform vec4 stone_light : source_color;
uniform vec4 seam_color : source_color;
uniform float tile_size;
uniform float seam_width;
uniform float metallic_value;
uniform float roughness_value;
uniform float surface_variation;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise(vec2 p) {
	vec2 a = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(a), hash(a + vec2(1.0, 0.0)), u.x),
		mix(hash(a + vec2(0.0, 1.0)), hash(a + vec2(1.0)), u.x), u.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz / tile_size;
	vec2 cell = floor(p);
	vec2 edge = min(fract(p), 1.0 - fract(p));
	float grout = smoothstep(seam_width, seam_width * 2.3, min(edge.x, edge.y));
	float cloud = noise(world_pos.xz * 3.3) * 0.52 + noise(world_pos.xz * 17.0) * 0.30 + noise(world_pos.xz * 91.0) * 0.18;
	vec3 base = mix(stone_dark.rgb, stone_light.rgb, hash(cell) * 0.56 + cloud * 0.44);
	ALBEDO = mix(seam_color.rgb, base, grout);
	ROUGHNESS = clamp(roughness_value + (cloud - 0.5) * surface_variation, 0.1, 1.0);
	METALLIC = metallic_value;
	float ridge_x = smoothstep(0.01, 0.06, edge.x);
	float ridge_y = smoothstep(0.01, 0.06, edge.y);
	NORMAL_MAP = normalize(vec3((noise(world_pos.xz * 91.0) - 0.5) * 0.06, (ridge_x - ridge_y) * 0.045, 1.0)) * 0.5 + 0.5;
}
