// 粒子通用部分：面向镜头（带粒子自转）、图集随机帧。varying 只能在 vertex() 里赋值，所以这里只放纯函数。

uniform int atlas_h = 1;
uniform int atlas_v = 1;
varying float v_age;
varying float v_seed;
varying vec2 v_quad_uv;

vec2 atlas_uv(vec2 uv, float frame_f) {
	if (atlas_h * atlas_v <= 1) {
		return uv;
	}
	float hf = float(atlas_h);
	float vf = float(atlas_v);
	float total = hf * vf;
	float frame = mod(floor(frame_f * total), total);
	uv /= vec2(hf, vf);
	return uv + vec2(mod(frame, hf) / hf, floor((frame + 0.5) / hf) / vf);
}

mat4 billboard_modelview(mat4 view, mat4 inv_view, mat4 model, float angle) {
	mat4 w = mat4(normalize(inv_view[0]), normalize(inv_view[1]), normalize(inv_view[2]), model[3]);
	w = w * mat4(vec4(cos(angle), -sin(angle), 0.0, 0.0), vec4(sin(angle), cos(angle), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mat4 mv = view * w;
	return mv * mat4(vec4(length(model[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(model[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(model[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
