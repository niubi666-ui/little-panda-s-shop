shader_type canvas_item;
// 受伤 / 低血量时屏幕四周的红色压暗。strength 由 combat_juice.gd 驱动；其余参数在 hurt_vignette.tres。
uniform float strength = 0.0;
uniform vec3 tint : source_color;
// 从屏幕中心算起，压暗开始与达到最深的半径（屏幕 UV 单位）
uniform float inner;
uniform float outer;
uniform float max_alpha;
// 椭圆形状：竖向略扁
uniform vec2 aspect;

void fragment() {
	vec2 centred = (UV - 0.5) * aspect;
	float edge = smoothstep(inner, outer, length(centred));
	COLOR = vec4(tint, edge * strength * max_alpha);
}
