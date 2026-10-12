// Shared two-tone lighting for the combat visual pass.
// A soft terminator instead of Lambert falloff: forms read as a lit side and a shade side,
// and the shade side is filled by the (cool) ambient colour of the room's Environment.
uniform float toon_wrap = 0.18;
uniform float toon_soft = 0.22;

vec3 toon_diffuse(vec3 n, vec3 l, vec3 light_color, float attenuation) {
	float lit = smoothstep(-toon_wrap, toon_soft, dot(n, l));
	return light_color * (lit * attenuation) / PI;
}
