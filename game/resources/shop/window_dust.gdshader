shader_type fog;

uniform vec4 dust_color : source_color = vec4(0.72, 0.57, 0.34, 1.0);
uniform float density : hint_range(0.0, 0.1) = 0.012;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.15;

void fog() {
	vec2 cross_section = (UVW.xy - vec2(0.5)) * 2.0;
	float edge = 1.0 - smoothstep(0.35, 1.0, length(cross_section));
	float ends = smoothstep(0.0, 0.18, UVW.z) * (1.0 - smoothstep(0.65, 1.0, UVW.z));
	DENSITY = density * edge * ends;
	ALBEDO = dust_color.rgb;
	EMISSION = dust_color.rgb * emission_strength * edge * ends;
}
