shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_opaque;
// 飘落的樱花瓣（粒子绘制用）。花瓣形状在着色器里画（椭圆 + 尖端一个小缺口），
// 每片按自己的节奏翻转；逆光时透出粉色。
// 为了不挡战斗画面：离镜头太近的花瓣淡出；刚出生和快落地时也淡出，不会突然出现/消失。

uniform vec3 colour : source_color = vec3(1.0, 0.82, 0.88);
uniform float colour_variation = 0.15;   // 每片深浅不同
uniform float translucency = 1.0;
uniform float tumble_speed = 2.2;        // 翻转快慢（弧度/秒）
uniform float near_fade_m = 7.0;         // 离镜头这么近时完全看不见
uniform float near_fade_band_m = 4.0;    // 从完全看不见到完全看见的过渡距离
uniform float life_fade = 0.12;          // 寿命开头和结尾各有这么一段淡入淡出（0..0.5）

varying float seed;
varying float life;

mat3 rotation(vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float o = 1.0 - c;
	return mat3(
		vec3(o * axis.x * axis.x + c, o * axis.x * axis.y + axis.z * s, o * axis.z * axis.x - axis.y * s),
		vec3(o * axis.x * axis.y - axis.z * s, o * axis.y * axis.y + c, o * axis.y * axis.z + axis.x * s),
		vec3(o * axis.z * axis.x + axis.y * s, o * axis.y * axis.z - axis.x * s, o * axis.z * axis.z + c));
}

float screen_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	life = INSTANCE_CUSTOM.y;
	vec3 axis = vec3(sin(seed * 31.0), cos(seed * 17.0), sin(seed * 7.0) * 0.5 + 0.5);
	mat3 spin = rotation(axis, TIME * tumble_speed * (0.6 + seed) + seed * 6.283);
	VERTEX = spin * VERTEX;
	NORMAL = spin * NORMAL;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float body = 1.0 - smoothstep(0.75, 1.0, length(c * vec2(1.6, 1.0)));
	float notch = smoothstep(0.1, 0.28, length(c - vec2(0.0, 1.0)));
	float distance_m = length(VERTEX);
	float visible = smoothstep(near_fade_m, near_fade_m + near_fade_band_m, distance_m);
	visible *= smoothstep(0.0, life_fade, life) * (1.0 - smoothstep(1.0 - life_fade, 1.0, life));
	// 网点式淡出：不走透明排序，和草、树混在一起也不会闪
	if (screen_hash(floor(FRAGCOORD.xy) + seed * 97.0) > visible) discard;
	ALPHA = body * notch;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 tone = colour * (1.0 - colour_variation + colour_variation * 2.0 * seed);
	ALBEDO = tone * mix(0.82, 1.0, UV.y);
	BACKLIGHT = tone * translucency;
	ROUGHNESS = 0.6;
}
