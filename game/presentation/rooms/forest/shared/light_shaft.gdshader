shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, world_vertex_coords, fog_disabled, shadows_disabled;
// 一道光柱：一张沿太阳方向拉长、始终侧对镜头的发光片。体积雾负责整体的空气感，
// 这些片负责“看得出一道一道”的光。节点原点是光柱落地点，节点的 Y 轴指向太阳。

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D streaks : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(1.0, 0.93, 0.78);
uniform float strength = 0.25;
uniform float width = 3.0;                    // 米
uniform float beam_length = 24.0;             // 米
uniform float ground_fade = 0.12;             // 靠近地面的一段淡出（占全长的比例）
uniform float drift = 0.02;                   // 光柱内条纹的漂移速度
uniform float soft_depth = 1.5;               // 与场景相交处柔化的距离（米）
uniform float near_fade = 6.0;                // 离镜头这么近时完全淡出，避免糊脸

instance uniform float seed = 0.0;
instance uniform float scale_width = 1.0;
instance uniform float scale_strength = 1.0;

varying float view_distance;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 centre = foot + axis * (UV.y * beam_length);
	vec3 side = normalize(cross(axis, CAMERA_POSITION_WORLD - centre));
	VERTEX = centre + side * ((UV.x - 0.5) * width * scale_width);
	view_distance = length(CAMERA_POSITION_WORLD - VERTEX);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	float along = smoothstep(0.0, ground_fade, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float grain = texture(streaks, vec2(UV.x * 0.9 + seed, UV.y * 0.08 + TIME * drift + seed * 3.7)).r;
	grain = mix(0.45, 1.25, grain);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).x, 1.0);
	float gap = VERTEX.z - scene.z / scene.w;
	float soft = clamp(gap / soft_depth, 0.0, 1.0);
	float near = smoothstep(near_fade * 0.5, near_fade, view_distance);
	ALBEDO = color;
	ALPHA = strength * scale_strength * across * along * grain * soft * near;
}
