shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float health_ratio;
uniform float trailing_ratio;
uniform vec4 health_color : source_color;
uniform vec4 trailing_color : source_color;
uniform vec4 background_color : source_color;
uniform vec4 border_color : source_color;
uniform vec2 border_fraction;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 inner = (UV - border_fraction) / (vec2(1.0) - 2.0 * border_fraction);
	vec3 color = background_color.rgb;
	if (inner.x <= trailing_ratio) { color = trailing_color.rgb; }
	if (inner.x <= health_ratio) { color = health_color.rgb; }
	if (inner.x < 0.0 || inner.x > 1.0 || inner.y < 0.0 || inner.y > 1.0) { color = border_color.rgb; }
	ALBEDO = color;
}
