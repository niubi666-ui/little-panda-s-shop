shader_type spatial;
render_mode specular_disabled;
// Characters: vertex colour (or a texture, for imported models), two-tone light, a rim
// so silhouettes separate from the ground, and a hit flash driven from script.
#include "res://presentation/shared/toon/toon_light.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_vertex_color = true;
uniform float saturation = 1.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.8);
uniform float rim_strength = 0.34;
uniform float rim_power = 2.8;
uniform float fill = 0.06;                   // self-lit floor so backlit fronts never go muddy
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash = 0.0;                   // 0..1, set by hit feedback
uniform vec3 glow_color : source_color = vec3(1.0, 0.5, 0.2);
uniform float glow = 0.0;                    // 0..1, attack telegraph pulse
// 身上的元素状态（着火、冰寒、感电、碎甲）：整体染色 + 轮廓发光。由元素表现每帧写入，0 为无
uniform vec3 element_color : source_color = vec3(1.0);
uniform float element_amount = 0.0;
uniform float dissolve = 0.0;                // 0..1, corpse fade (screen-door, so it still casts no sorting issues)

float screen_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	if (dissolve > 0.0 && screen_hash(floor(FRAGCOORD.xy)) < dissolve) discard;
	vec3 base = texture(albedo_tex, UV).rgb * tint;
	if (use_vertex_color) base *= COLOR.rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(grey), base, saturation);
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float upward = 0.35 + 0.65 * clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(base, flash_color, flash);
	ROUGHNESS = 1.0;
	// The telegraph glow hugs the silhouette so the character keeps its own colours.
	EMISSION = base * fill + rim_color * (edge * upward * rim_strength) + flash_color * flash * 1.6 + glow_color * glow * (0.08 + edge * 1.1);
	ALBEDO = mix(ALBEDO, element_color, element_amount * 0.35);
	EMISSION += element_color * element_amount * (0.18 + edge * 1.6);
}

void light() {
	DIFFUSE_LIGHT += toon_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
