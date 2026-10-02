shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform sampler2D ribbon_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 texture_region;
uniform vec4 tint : source_color;
uniform float brightness;
uniform float opacity;
uniform float streak_amount;
uniform vec2 streak_frequency;
uniform float core_width;
uniform float texture_strength;

void fragment() {
	vec2 sample_uv = texture_region.xy + UV * texture_region.zw;
	vec4 ink = texture(ribbon_texture, sample_uv);
	float grain = mix(1.0, smoothstep(0.12, 0.6, sin(dot(UV, streak_frequency)) * 0.5 + 0.5), streak_amount);
	float fade = COLOR.a * opacity;
	float core = exp(-pow((UV.y - 0.78) / core_width, 2.0));
	float mask = (core + ink.a * texture_strength) * grain;
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * brightness;
	ALPHA = mask * fade;
}
