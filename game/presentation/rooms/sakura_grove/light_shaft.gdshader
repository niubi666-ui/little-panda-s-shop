shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A soft beam of sunlight: additive, fading at both ends so it never meets the ground
// in a hard line. UV.y = 0 at the canopy end, 1 near the ground.

uniform vec3 beam_color : source_color = vec3(1.0, 0.86, 0.68);
uniform float intensity = 0.16;
uniform float phase = 0.0;

void fragment() {
	float across = sin(UV.x * PI);
	across *= across;
	float along = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.55, 0.97, UV.y));
	float streak = 0.75 + 0.25 * sin(UV.x * 23.0 + phase * 5.0) * sin(UV.x * 9.0 + TIME * 0.25 + phase);
	float breathe = 0.8 + 0.2 * sin(TIME * 0.4 + phase * 3.1);
	ALBEDO = beam_color * intensity * across * along * streak * breathe;
}
