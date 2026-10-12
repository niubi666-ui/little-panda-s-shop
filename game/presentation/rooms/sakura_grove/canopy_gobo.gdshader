shader_type spatial;
render_mode unshaded, cull_disabled;
// Shadow-only "branches overhead": an invisible sheet whose cut-out pattern lets the sun
// through in dapples. The pattern is laid out in the space where the shadow lands, so the
// middle of the court can be kept more open than its edges.
#include "res://presentation/rooms/sakura_grove/ground_common.gdshaderinc"

uniform vec3 to_sun = vec3(-0.6, 0.62, 0.5);
uniform vec2 court_half = vec2(11.0, 9.0);
uniform float cover_centre = 0.16;
uniform float cover_edge = 0.6;
uniform float sway = 0.14;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 landing = world_pos.xz - to_sun.xz / to_sun.y * world_pos.y;
	vec2 q = landing + vec2(sin(TIME * 0.55 + landing.y * 0.31), cos(TIME * 0.47 + landing.x * 0.27)) * sway;
	float n = vnoise(q * 0.5) * 0.4 + vnoise(q * 1.5 + 7.0) * 0.34 + vnoise(q * 4.2 + 19.0) * 0.26;
	float d = length(landing / court_half);
	float cover = mix(cover_centre, cover_edge, smoothstep(0.2, 1.05, d));
	// Value noise clusters around 0.5: map the wanted coverage onto a threshold.
	float threshold = 0.69 - 0.36 * cover;
	ALBEDO = vec3(0.0);
	ALPHA = step(threshold, n);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
