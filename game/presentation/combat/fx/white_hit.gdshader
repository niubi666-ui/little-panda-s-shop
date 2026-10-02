shader_type spatial;
render_mode unshaded;
uniform vec4 flash_color : source_color;
uniform float emission_energy;
void fragment() {
	ALBEDO = flash_color.rgb;
	EMISSION = flash_color.rgb * emission_energy;
}
