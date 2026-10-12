shader_type canvas_item;
// 受伤 / 低血量时屏幕四周的红色压暗。strength 由 combat_juice.gd 驱动。
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(0.86, 0.1, 0.16);

void fragment() {
	vec2 centred = (UV - 0.5) * vec2(1.0, 1.1);
	float edge = smoothstep(0.28, 0.82, length(centred));
	COLOR = vec4(tint, edge * strength * 0.75);
}
