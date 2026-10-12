shader_type canvas_item;
render_mode blend_premul_alpha;
// Screen-space mood: a soft plum vignette and a warm light leak from the sun's corner.

uniform vec3 vignette_color : source_color = vec3(0.1, 0.07, 0.16);
uniform float vignette_strength = 0.36;
uniform vec3 leak_color : source_color = vec3(1.0, 0.72, 0.5);
uniform float leak_strength = 0.2;
uniform vec2 leak_origin = vec2(0.0, 0.0);

void fragment() {
	vec2 centred = (UV - 0.5) * vec2(1.0, 1.12);
	float edge = smoothstep(0.42, 0.92, length(centred)) * vignette_strength;
	float leak = pow(1.0 - clamp(distance(UV, leak_origin) / 1.1, 0.0, 1.0), 2.4) * leak_strength;
	COLOR = vec4(vignette_color * edge + leak_color * leak, edge);
}
