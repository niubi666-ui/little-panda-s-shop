shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 瀑布（森林系列共用）。两种用法：
//  - 水帘（pool_mode = false）：网格 UV.x 横向、UV.y 自上而下。两层噪声条纹沿下落方向流动，
//    两侧和顶端渐隐，越往下越白，底部化成白沫。
//  - 潭面白沫（pool_mode = true）：圆盘网格，UV 以圆心为 (0.5, 0.5)。一圈圈白沫从落水点往外扩散。
// 逆光时（太阳在瀑布后方）水帘透亮。参数在各场景的瀑布材质 .tres 里。

uniform vec3 colour : source_color = vec3(0.9, 0.95, 0.97);       // 白水
uniform vec3 deep_colour : source_color = vec3(0.42, 0.56, 0.58);  // 水帘里较薄、透出后面岩石的部分
uniform sampler2D streak_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float speed = 1.1;               // 条纹下落速度（每秒流过多少个 UV 单位）
uniform vec2 streak_scale = vec2(4.0, 0.7);
uniform float opacity = 0.9;
uniform float edge_soft = 0.2;           // 两侧渐隐宽度（UV）
uniform float top_fade = 0.05;           // 顶端渐隐
uniform float foam_start = 0.7;          // 从这里往下渐渐全白
uniform float backlight = 0.7;           // 逆光透亮程度
uniform float strand_wobble = 0.25;     // 两侧边缘摆动幅度
uniform float strand_count = 1.4;       // 横向分成几股（越大股越多）
uniform float strand_gap = 0.3;         // 股与股之间断开的多少（0 不断开）
uniform bool pool_mode = false;
uniform float ring_speed = 0.3;          // 潭面白沫往外扩散的速度

void fragment() {
	vec2 uv = UV;
	if (pool_mode) {
		vec2 c = uv - 0.5;
		float r = length(c) * 2.0;
		float angle = atan(c.y, c.x) / 6.2832;
		float n1 = texture(streak_noise, vec2(angle * 3.0, r * 1.4 - TIME * ring_speed)).r;
		float n2 = texture(streak_noise, vec2(angle * 5.0 + 0.31, r * 2.2 - TIME * ring_speed * 1.7)).r;
		float churn = smoothstep(0.3, 0.85, n1 * 0.6 + n2 * 0.5);
		float fade = 1.0 - smoothstep(0.35, 1.0, r);
		ALBEDO = colour;
		ALPHA = clamp(churn * fade + (1.0 - smoothstep(0.0, 0.5, r)) * 0.45, 0.0, 1.0) * opacity;
		ROUGHNESS = 0.7;
		BACKLIGHT = colour * backlight * 0.5;
	} else {
		float t = uv.y;
		float n1 = texture(streak_noise, vec2(uv.x * streak_scale.x, t * streak_scale.y - TIME * speed)).r;
		float n2 = texture(streak_noise, vec2(uv.x * streak_scale.x * 1.9 + 0.37, t * streak_scale.y * 1.6 - TIME * speed * 1.35)).r;
		float streak = smoothstep(0.3, 0.72, n1 * 0.65 + n2 * 0.45);
		// 两侧边缘随高度摆动，水帘里断开成几股：不是一整块规整的布
		float wobble = (texture(streak_noise, vec2(t * 0.9, 0.31 + TIME * 0.03)).r - 0.5) * strand_wobble;
		float edges = smoothstep(0.0, edge_soft, uv.x + wobble) * smoothstep(1.0, 1.0 - edge_soft, uv.x - wobble);
		float strands = smoothstep(strand_gap, strand_gap + 0.18, texture(streak_noise, vec2(uv.x * strand_count + 0.17, t * 0.12 - TIME * 0.04)).r);
		float foam = smoothstep(foam_start, 1.0, t);
		vec3 tone = mix(deep_colour, colour, max(streak, foam));
		ALBEDO = tone;
		ALPHA = clamp((0.15 + 0.85 * streak + foam) * edges * mix(strands, 1.0, foam) * smoothstep(0.0, top_fade, t), 0.0, 1.0) * opacity;
		ROUGHNESS = 0.25;
		SPECULAR = 0.6;
		BACKLIGHT = tone * backlight;
	}
}
