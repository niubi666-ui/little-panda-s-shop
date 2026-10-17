// 刀光拖尾带（网格由 fire_ribbon_trail.gd 每帧在世界坐标里重建）
// UV.x = 这一截的年龄（秒），UV.y = 刀根(0) → 刀尖外延(1)
// UV2.x = 这一截的出生时间（噪声跟着它走，不会在带子上滑动），UV2.y = 招式强度

uniform float life = 0.3;
uniform float fade_in = 0.0;
uniform float rise = 0.5;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 noise_scale = vec2(2.5, 1.2);
uniform float noise_drift = 1.2;
uniform float band_center = 0.8;
uniform float band_width = 0.3;
uniform float dissolve_softness = 0.25;
uniform vec4 color_new : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 color_old : source_color = vec4(0.8, 0.12, 0.02, 1.0);
uniform float emission = 3.0;
uniform float opacity = 1.0;

void vertex() {
	VERTEX.y += rise * UV.x * UV.x;
}

// 返回遮罩，同时输出用于取色的“温度”
float ribbon_mask(vec2 uv, vec2 uv2, out float temperature) {
	float age01 = uv.x / life;
	float s = uv.y;
	float n1 = texture(noise_tex, vec2(uv2.x * noise_scale.x, s * noise_scale.y - uv.x * noise_drift)).r;
	float n2 = texture(noise_tex, vec2(uv2.x * noise_scale.x * 3.1 + 0.37, s * noise_scale.y * 2.3 - uv.x * noise_drift * 1.7)).r;
	float n = n1 * 0.6 + n2 * 0.4;
	float band = exp(-pow((s - band_center) / band_width, 2.0));
	float v = band * mix(0.15, 1.0, n);
	// 刚划出来时噪声就已经在边缘咬出火舌，越老咬得越狠
	float thr = mix(0.05, 1.0, clamp(age01, 0.0, 1.0));
	float m = smoothstep(thr, thr + dissolve_softness, v);
	if (fade_in > 0.0) {
		m *= smoothstep(0.0, fade_in, uv.x);
	}
	m *= step(age01, 1.0);
	temperature = smoothstep(0.25, 1.0, (1.0 - age01 * 1.3) * mix(0.6, 1.0, n) * band);
	return m * clamp(uv2.y, 0.0, 2.0);
}
