shader_type spatial;
// 写实角色：标准 PBR 光照，保留模型自带贴图。在此之上只加战斗需要的四样东西：
// 受击闪白、前摇泛光、尸体消散，以及一圈很淡的轮廓光（角色站进树影里也能看清）。
// 参数名与 toon 版角色材质一致，RiggedActorVisual 不用区分两者。

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool use_normal_tex = false;
uniform bool use_vertex_color = false;
// 顶点色道具（从色块模型上拿来的弩、锤、旗）是按“最终颜色”画的，直接当 PBR 底色会过亮发白
uniform float vertex_color_gain = 1.0;
uniform float roughness = 0.75;
uniform float metallic = 0.0;
uniform float saturation = 1.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.93, 0.8);
uniform float rim_strength = 0.16;
uniform float rim_power = 3.2;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float flash = 0.0;                   // 0..1，受击
uniform vec3 glow_color : source_color = vec3(1.0, 0.5, 0.2);
uniform float glow = 0.0;                    // 0..1，出招前摇
// 身上的元素状态（着火、冰寒、感电、碎甲）：整体染色 + 轮廓发光。由元素表现每帧写入，0 为无
uniform vec3 element_color : source_color = vec3(1.0);
uniform float element_amount = 0.0;
uniform float dissolve = 0.0;                // 0..1，尸体消散（网点式，不产生透明排序问题）

float screen_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	if (dissolve > 0.0 && screen_hash(floor(FRAGCOORD.xy)) < dissolve) discard;
	vec3 base = texture(albedo_tex, UV).rgb * tint;
	if (use_vertex_color) base *= COLOR.rgb * vertex_color_gain;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(grey), base, saturation);
	if (use_normal_tex) NORMAL_MAP = texture(normal_tex, UV).rgb;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float upward = 0.35 + 0.65 * clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(base, flash_color, flash);
	ROUGHNESS = roughness;
	// 场景没有环境反射，纯金属会发黑：压低金属度，留一点高光即可
	METALLIC = metallic * 0.45;
	SPECULAR = 0.4;
	EMISSION = rim_color * (edge * upward * rim_strength) + flash_color * flash * 1.6 + glow_color * glow * (0.08 + edge * 1.1);
	ALBEDO = mix(ALBEDO, element_color, element_amount * 0.35);
	EMISSION += element_color * element_amount * (0.18 + edge * 1.6);
}
