shader_type spatial;
uniform vec4 stone_color : source_color;
uniform vec4 joint_color : source_color;
uniform float tile_scale;
uniform float joint_width;
uniform float surface_roughness;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 tile = world_position.xz * tile_scale;
	tile.x += mod(floor(tile.y), 2.0) * 0.5;
	vec2 cell = floor(tile);
	vec2 edge = min(fract(tile), 1.0 - fract(tile));
	float stone = smoothstep(joint_width, joint_width + fwidth(tile.x), min(edge.x, edge.y));
	float variation = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	ALBEDO = mix(joint_color.rgb, stone_color.rgb * mix(0.85, 1.15, variation), stone);
	ROUGHNESS = surface_roughness;
}
