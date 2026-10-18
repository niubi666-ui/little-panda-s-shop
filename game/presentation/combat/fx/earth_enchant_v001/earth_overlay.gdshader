shader_type spatial;
uniform float effect_time = 0.0;
// 刀身岩壳（游戏版）：挂在剑模型的 material_overlay 上。坐标用刀身本地位置换算（world_to_blade），
// 不依赖剑模型自己的 UV。从刀背一侧往刃口长出一层岩壳，岩缝透出金光；heat 越高岩壳越厚、裂缝越亮。
// blade_uv.x：栋(0) → 刃(1)；blade_uv.y：刀根(0) → 刀尖(1)
render_mode unshaded, blend_mix, depth_draw_always, cull_back, fog_disabled;

uniform float heat = 0.0;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D cells_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 rock_dark : source_color = vec3(0.16, 0.13, 0.1);
uniform vec3 rock_light : source_color = vec3(0.42, 0.36, 0.28);
uniform vec3 crack_color : source_color = vec3(1.0, 0.72, 0.28);
uniform float crack_emission = 2.2;
uniform float push = 0.0018;

uniform mat4 world_to_blade;
uniform float blade_length = 1.0;
uniform float blade_width_ratio = 0.08;
varying vec2 blade_uv;

void vertex() {
	vec3 blade_pos = (world_to_blade * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	blade_uv = vec2(clamp(0.5 + (blade_pos.x + blade_pos.y) / (blade_length * blade_width_ratio), 0.0, 1.0), clamp(0.5 - blade_pos.z / blade_length, 0.0, 1.0));
	VERTEX += NORMAL * push;
}

void fragment() {
	float n = texture(noise_tex, blade_uv * vec2(1.2, 4.0)).r;
	float p = clamp(heat, 0.0, 1.5);
	float spine = 1.0 - blade_uv.x;
	float thr = mix(1.1, 0.35, clamp(p, 0.0, 1.0));
	float cover = smoothstep(thr, thr + 0.12, spine * 0.75 + n * 0.45) * smoothstep(0.0, 0.05, blade_uv.y);
	if (cover < 0.02) discard;
	float cells = texture(cells_tex, blade_uv * vec2(1.6, 6.0)).r;
	float crack = smoothstep(0.82, 0.95, cells) * smoothstep(0.3, 0.7, cover);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 rock = mix(rock_dark, rock_light, n * 0.7 + facing * 0.3);
	float pulse = 0.75 + 0.25 * sin(effect_time * 2.0 + blade_uv.y * 9.0);
	ALBEDO = mix(rock, crack_color * crack_emission * pulse * (0.4 + 0.6 * min(p, 1.0)), crack);
	ALPHA = clamp(cover, 0.0, 1.0);
}
