shader_type spatial;
render_mode unshaded, cull_front;
uniform float outline_width;
uniform vec4 outline_color : source_color;
uniform float emission_energy;
void vertex() { VERTEX += NORMAL * outline_width; }
void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * emission_energy;
}
