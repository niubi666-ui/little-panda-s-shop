shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, ambient_light_disabled, fog_disabled;
// 浅溪，照着 Blender 的 BrookWater 材质做：水面本身没有颜色，
//   - 透过水面看到折射的水底，被水染上一层颜色，越深越暗
//   - 反射按菲涅耳（水的折射率 1.33）混入：正着看几乎全是水底，斜着看越来越像镜子
//   - 倒影在屏幕画面里追踪（岸上的石头、草、树都能映出来）；
//     追出画面的部分，用出画处附近的模糊颜色代替（多半是被阳光照亮的树林和薄雾）
//   - 太阳在波纹上的碎光由引擎的高光处理
// 岸边和石头周围有一圈很细的浮沫。参数在 water_material.tres 里调。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D screen_blur : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec3 transmit_tint : source_color = vec3(0.62, 0.7, 0.68);
uniform float clarity_m = 1.5;               // 多深之后水底开始明显变暗（米）
uniform vec3 murk : source_color = vec3(0.02, 0.05, 0.04);
uniform vec2 flow = vec2(0.3, 0.02);         // 水流方向与速度（米/秒）
uniform vec2 ripple_scale = vec2(2.8, 1.0);  // 波纹尺度（米）：沿水流方向拉长
uniform float ripple_strength = 0.35;
uniform float reflection_ripple = 0.4;       // 倒影被波纹扭动的程度（相对着色用的波纹）
uniform float refraction = 0.025;            // 波纹把水底图像扭曲多少（屏幕比例）
uniform float ior = 1.33;
uniform float roughness = 0.04;
// 倒影
uniform int reflection_steps = 40;
uniform float reflection_step_m = 0.2;       // 第一步多长（米）
uniform float reflection_step_growth = 1.12; // 之后每步加长的倍数
uniform float reflection_thickness_m = 0.6;  // 认为“打中”的深度容差（另加步长）
uniform float offscreen_blur = 3.0;          // 追出画面时取样的模糊级数
// 追不到时的倒影：低处是树林的暗色，高处是天光，朝着太阳的方向是被照亮的薄雾
uniform vec3 canopy_colour : source_color = vec3(0.2, 0.24, 0.16);
uniform vec3 sky_colour : source_color = vec3(0.44, 0.6, 0.67);
uniform float sky_low = 0.35;                // 反射方向朝上多少（世界 y）开始看到天
uniform float sky_high = 0.85;
uniform vec3 haze_colour : source_color = vec3(1.0, 0.86, 0.66);
uniform float haze_strength = 1.2;
uniform float haze_power = 6.0;
uniform vec3 sun_direction = vec3(-0.59, 0.63, -0.51);  // 指向太阳，由房间脚本填入
uniform float screen_fallback = 0.5;         // 追出画面时，出画处颜色占多少
// 浮沫
uniform vec3 foam_colour : source_color = vec3(0.85, 0.88, 0.84);
uniform float foam_width = 0.05;             // 水深小于此值的地方出浮沫（米）
uniform float foam_amount = 0.16;
uniform float shore_fade = 0.03;             // 岸边水面淡出的水深（米）
uniform int debug_view = 0;                  // 调试：1 只看倒影，2 只看水底，3 看菲涅耳

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, -1.0);
}

vec3 view_position(vec2 screen_uv, float raw_depth, mat4 inv_projection) {
	vec4 position = inv_projection * vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0);
	return position.xyz / position.w;
}

vec2 project(vec3 position, mat4 projection) {
	vec4 clip = projection * vec4(position, 1.0);
	return clip.xy / clip.w * 0.5 + 0.5;
}

bool on_screen(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

void fragment() {
	vec2 uv = world_pos.xz / ripple_scale;
	vec3 a = texture(ripple, uv + flow * TIME * 0.4).rgb;
	vec3 b = texture(ripple, uv * 1.7 - flow.yx * TIME * 0.25 + flow * TIME * 0.6).rgb;
	vec3 wave = mix(a, b, 0.5);
	NORMAL_MAP = wave;
	NORMAL_MAP_DEPTH = ripple_strength;
	vec2 slope = (wave.xy * 2.0 - 1.0) * ripple_strength;
	vec3 wavy = normalize(NORMAL + TANGENT * slope.x + BINORMAL * slope.y);

	// —— 水底（折射）——
	vec3 bed_view = view_position(SCREEN_UV, texture(depth_tex, SCREEN_UV).x, INV_PROJECTION_MATRIX);
	float depth_m = max(world_pos.y - (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).y, 0.0);
	vec2 bent_uv = SCREEN_UV + slope * refraction * clamp(depth_m * 4.0, 0.0, 1.0);
	vec3 bent_view = view_position(bent_uv, texture(depth_tex, bent_uv).x, INV_PROJECTION_MATRIX);
	if (VERTEX.z - bent_view.z < 0.0) bent_uv = SCREEN_UV;      // 偏移后取到了水面之前的东西：不偏移
	vec3 bed = texture(screen_tex, bent_uv).rgb * transmit_tint;
	bed = mix(murk, bed, exp(-depth_m / clarity_m));

	// —— 倒影：沿反射方向在深度图里步进，打中后二分细化 ——
	vec3 view_dir = normalize(-VERTEX);
	vec3 mirror_normal = normalize(NORMAL + (TANGENT * slope.x + BINORMAL * slope.y) * reflection_ripple);
	vec3 ray = reflect(-view_dir, mirror_normal);
	vec3 position = VERTEX;
	vec2 last_uv = SCREEN_UV;
	float step_length = reflection_step_m;
	vec3 world_ray = (INV_VIEW_MATRIX * vec4(ray, 0.0)).xyz;
	vec3 fallback = mix(canopy_colour, sky_colour, smoothstep(sky_low, sky_high, world_ray.y));
	fallback += haze_colour * haze_strength * pow(max(dot(world_ray, normalize(sun_direction)), 0.0), haze_power);
	vec3 reflected = fallback;
	bool resolved = false;
	for (int i = 0; i < reflection_steps; i++) {
		vec3 next = position + ray * step_length;
		vec2 next_uv = project(next, PROJECTION_MATRIX);
		if (!on_screen(next_uv) || next.z > -0.05) break;
		float scene_z = view_position(next_uv, texture(depth_tex, next_uv).x, INV_PROJECTION_MATRIX).z;
		float behind = scene_z - next.z;
		if (behind > 0.0) {
			if (behind < reflection_thickness_m + step_length) {
				vec3 lo = position;
				vec3 hi = next;
				for (int j = 0; j < 5; j++) {
					vec3 mid = (lo + hi) * 0.5;
					vec2 mid_uv = project(mid, PROJECTION_MATRIX);
					float mid_z = view_position(mid_uv, texture(depth_tex, mid_uv).x, INV_PROJECTION_MATRIX).z;
					if (mid_z - mid.z > 0.0) hi = mid; else lo = mid;
				}
				vec2 hit_uv = project(hi, PROJECTION_MATRIX);
				vec2 edge = smoothstep(vec2(0.0), vec2(0.06), hit_uv) * smoothstep(vec2(0.0), vec2(0.06), 1.0 - hit_uv);
				reflected = mix(textureLod(screen_blur, hit_uv, offscreen_blur).rgb, texture(screen_tex, hit_uv).rgb, edge.x * edge.y);
				resolved = true;
			}
			break;
		}
		position = next;
		last_uv = next_uv;
		step_length *= reflection_step_growth;
	}
	if (!resolved) {
		// 追出画面或被挡住：倒影里的东西就在出画处附近，用那里模糊后的颜色
		reflected = mix(fallback, textureLod(screen_blur, last_uv, offscreen_blur).rgb, screen_fallback * smoothstep(0.02, 0.2, distance(last_uv, SCREEN_UV)));
	}

	// —— 菲涅耳 ——
	float f0 = pow((ior - 1.0) / (ior + 1.0), 2.0);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - clamp(dot(wavy, view_dir), 0.0, 1.0), 5.0);

	float foam = (1.0 - smoothstep(0.0, foam_width, depth_m)) * smoothstep(0.3, 0.7, texture(foam_noise, world_pos.xz * 0.9 + flow * TIME * 0.5).r) * foam_amount;
	ALBEDO = foam_colour * foam;
	EMISSION = mix(bed, reflected, fresnel) * (1.0 - foam);
	ROUGHNESS = mix(roughness, 0.6, foam);
	SPECULAR = clamp(f0 / 0.08, 0.0, 1.0);     // 太阳碎光：引擎按 GGX 处理
	METALLIC = 0.0;
	ALPHA = smoothstep(0.0, shore_fade, depth_m);
	if (debug_view == 1) { EMISSION = reflected; ALBEDO = vec3(0.0); SPECULAR = 0.0; ALPHA = 1.0; }
	if (debug_view == 2) { EMISSION = bed; ALBEDO = vec3(0.0); SPECULAR = 0.0; ALPHA = 1.0; }
	if (debug_view == 3) { EMISSION = vec3(fresnel); ALBEDO = vec3(0.0); SPECULAR = 0.0; ALPHA = 1.0; }
}
