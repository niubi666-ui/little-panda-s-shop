shader_type canvas_item;
// 画面四角压暗：把视线收向中间的战斗，也模拟样板图里“被暗处的树围着”的构图。
uniform vec3 color : source_color = vec3(0.02, 0.04, 0.03);
uniform float strength = 0.4;
uniform float inner = 0.55;      // 从离中心多远开始变暗（0 中心，1 画面短边的一半）
uniform float outer = 1.25;

void fragment() {
	vec2 centred = (UV - 0.5) * 2.0;
	float distance_from_centre = length(centred * vec2(1.0, 0.85));
	COLOR = vec4(color, strength * smoothstep(inner, outer, distance_from_centre));
}
