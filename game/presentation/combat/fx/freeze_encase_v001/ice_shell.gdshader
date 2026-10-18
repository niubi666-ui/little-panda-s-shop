shader_type spatial;
// 冰壳：挂在敌人模型自己的 MeshInstance3D 上（material_overlay），顶点沿法线往外推一点，
// 所以冰完全贴合身体轮廓（含武器、道具，也跟着骨骼动画）。
// progress 0..1：冰从脚往上爬到头顶；shatter 0..1：沿裂纹亮一下后按噪声碎掉。
// 受场景光照：半透明玻璃感、高光、菲涅尔冷光边、冰裂纹；正在冻结的前沿是一条白霜。
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform float progress = 0.0;
uniform float shatter = 0.0;
uniform float ground_y = 0.0;
uniform float body_height = 1.0;
uniform float thickness = 0.02;            // 米
uniform sampler2D cells_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 ice_color : source_color = vec3(0.6, 0.8, 1.0);
uniform vec3 rim_color : source_color = vec3(0.72, 0.9, 1.0);
uniform float body_alpha = 0.42;
uniform float rim_alpha = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	float sc = max(length(MODEL_MATRIX[0].xyz), 1e-4);
	VERTEX += NORMAL * thickness / sc;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = abs(n);
	w /= max(w.x + w.y + w.z, 1e-4);
	return texture(t, p.yz * s).r * w.x + texture(t, p.xz * s).r * w.y + texture(t, p.xy * s).r * w.z;
}

void fragment() {
	float h = (wpos.y - ground_y) / max(body_height, 0.01);
	float n = tri(noise_tex, wpos, wnrm, 1.3);
	float front = progress * 1.15 - h + (n - 0.5) * 0.18;
	if (front < 0.0) discard;
	float cells = tri(cells_tex, wpos, wnrm, 2.6);
	float cracks = smoothstep(0.8, 0.95, cells);
	float band = 1.0 - smoothstep(0.0, 0.07, front);          // 正在往上爬的白霜前沿
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float base_frost = smoothstep(0.35, 0.0, h) * 0.35;           // 脚下霜更厚
	ALBEDO = mix(ice_color * 0.5, vec3(0.94, 0.97, 1.0), clamp(cracks * 0.7 + band * 0.7 + base_frost, 0.0, 1.0));
	ROUGHNESS = mix(0.06, 0.5, max(cracks, band));
	SPECULAR = 0.85;
	METALLIC = 0.0;
	EMISSION = rim_color * fres * 0.9 + vec3(0.6, 0.85, 1.0) * (band * 1.3 + cracks * 0.22) + ice_color * 0.07;
	float alpha = max(mix(body_alpha, rim_alpha, fres), cracks * 0.75 + band);
	// 碎裂：先沿裂纹亮一下，再按噪声一块块消失
	float gone = smoothstep(n * 0.8, n * 0.8 + 0.18, shatter * 1.2);
	EMISSION += vec3(0.85, 0.95, 1.0) * smoothstep(0.0, 0.25, shatter) * (1.0 - gone) * (cracks * 3.0 + 0.4);
	ALPHA = clamp(alpha * (1.0 - gone), 0.0, 1.0);
}
