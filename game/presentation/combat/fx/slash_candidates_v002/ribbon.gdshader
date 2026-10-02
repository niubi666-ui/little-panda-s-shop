shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D ribbon_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 texture_region;
uniform vec4 edge_tint : source_color;
uniform vec4 body_tint : source_color;
uniform float brightness;
uniform float opacity;
uniform float edge_position;
uniform float edge_width;
uniform vec2 body_region;
uniform float body_strength;
uniform float front_strength;
uniform float texture_strength;
uniform float streak_amount;
uniform vec2 streak_frequency;

void fragment() {
	vec4 ink = texture(ribbon_texture, texture_region.xy + UV * texture_region.zw);
	float rim = exp(-pow((UV.y - edge_position) / edge_width, 2.0));
	float body = smoothstep(body_region.x, body_region.y, UV.y) * (1.0 - smoothstep(body_region.y, 1.0, UV.y));
	float front = pow(UV.x, 18.0) * sin(UV.y * 3.14159265) * front_strength;
	float taper = pow(sin(mix(0.04, 0.94, UV.x) * 3.14159265), 0.3);
	float grain = mix(1.0, smoothstep(0.12, 0.65, sin(dot(UV, streak_frequency)) * 0.5 + 0.5), streak_amount);
	float mask = (rim + body * body_strength + front + ink.a * texture_strength) * taper * grain;
	vec3 color = mix(body_tint.rgb, edge_tint.rgb, clamp(rim + front, 0.0, 1.0));
	ALBEDO = color;
	EMISSION = color * brightness;
	ALPHA = clamp(mask * COLOR.a * opacity, 0.0, 1.0);
}
