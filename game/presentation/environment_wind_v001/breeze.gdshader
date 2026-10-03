shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// COLOR.r is deformation data only. It must never tint the imported material.
uniform vec4 base_color : source_color;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo_texture;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal_texture;
uniform float normal_scale;
uniform float roughness_value;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_roughness_texture;
uniform vec4 roughness_channel;
uniform float metallic_value;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_metallic_texture;
uniform vec4 metallic_channel;
uniform float specular_value;
uniform float alpha_scissor_threshold;
uniform bool alpha_scissor_enabled;
uniform vec2 uv_scale;
uniform vec2 uv_offset;

// The host owns this time. No TIME builtin: pause freezes every wave exactly.
uniform float wind_time;
uniform float wind_strength;
uniform vec2 wind_direction_xz;
uniform float sway_amplitude_m;
uniform vec2 sway_frequency_hz;
uniform float steady_push_ratio;
uniform float gust_amplitude_m;
uniform vec2 gust_frequency_hz;
uniform float flutter_amplitude_m;
uniform vec2 flutter_frequency_hz;
uniform float spatial_phase_per_m;
uniform float instance_phase_spread;
uniform float normal_bend_reference_m;
// Set once per plant/root group, shared by stems, leaves and attached bells.
// Explicit index keeps the layout identical in each cull-mode shader variant.
instance uniform vec3 wind_group_origin : instance_index(0);

const float TAU_VALUE = 6.28318530718;

vec3 rotate_small_bend(vec3 value, vec3 axis, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return value * cosine + cross(axis, value) * sine + axis * dot(axis, value) * (1.0 - cosine);
}

void vertex() {
	UV = UV * uv_scale + uv_offset;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 instance_origin = wind_group_origin;
	vec2 direction = normalize(wind_direction_xz);
	vec2 side_direction = vec2(-direction.y, direction.x);
	float phase = dot(world_position.xz, direction) * spatial_phase_per_m;
	float instance_phase = sin(dot(instance_origin.xz, vec2(1.731, 2.417))) * instance_phase_spread;
	float sway = 0.72 * sin(wind_time * TAU_VALUE * sway_frequency_hz.x + phase + instance_phase)
		+ 0.28 * sin(wind_time * TAU_VALUE * sway_frequency_hz.y + phase * 0.63 + instance_phase * 1.31);
	float gust_envelope = smoothstep(0.12, 0.92,
		0.5 + 0.32 * sin(wind_time * TAU_VALUE * gust_frequency_hz.x + phase * 0.39)
		+ 0.18 * sin(wind_time * TAU_VALUE * gust_frequency_hz.y + phase * 0.21 + 1.4));
	float flutter = 0.65 * sin(wind_time * TAU_VALUE * flutter_frequency_hz.x + phase * 3.1 + instance_phase)
		+ 0.35 * sin(wind_time * TAU_VALUE * flutter_frequency_hz.y + phase * 2.3 + instance_phase * 1.73);
	float weight = clamp(COLOR.r, 0.0, 1.0);
	float anchored_weight = weight * weight;
	float bend_distance = wind_strength * (sway_amplitude_m * (steady_push_ratio + sway) + gust_amplitude_m * gust_envelope);
	float flutter_distance = wind_strength * flutter_amplitude_m * flutter * (0.45 + 0.55 * gust_envelope);
	vec3 displacement = vec3(direction.x, 0.0, direction.y) * bend_distance * anchored_weight;
	displacement += vec3(side_direction.x, 0.0, side_direction.y) * flutter_distance * anchored_weight * weight;
	world_position += displacement;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;

	// Approximate the bend derivative (d(weight^2)/d(height)) with a small
	// rotation. Rotate the entire tangent frame so normal maps follow the bend.
	vec3 wind_vector = vec3(direction.x * bend_distance + side_direction.x * flutter_distance,
		0.0, direction.y * bend_distance + side_direction.y * flutter_distance);
	float bend_angle = atan(length(wind_vector) * 2.0 * weight / normal_bend_reference_m);
	vec3 bend_axis = cross(vec3(0.0, 1.0, 0.0), normalize(wind_vector + vec3(0.0000001, 0.0, 0.0)));
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_normal = rotate_small_bend(world_normal, bend_axis, bend_angle);
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * world_normal);
	if (length(TANGENT) > 0.001) {
		vec3 world_tangent = normalize(mat3(MODEL_MATRIX) * TANGENT);
		world_tangent = rotate_small_bend(world_tangent, bend_axis, bend_angle);
		TANGENT = normalize(inverse(mat3(MODEL_MATRIX)) * world_tangent);
	}
	if (length(BINORMAL) > 0.001) {
		vec3 world_binormal = normalize(mat3(MODEL_MATRIX) * BINORMAL);
		world_binormal = rotate_small_bend(world_binormal, bend_axis, bend_angle);
		BINORMAL = normalize(inverse(mat3(MODEL_MATRIX)) * world_binormal);
	}
}

void fragment() {
	vec4 surface_color = base_color;
	if (has_albedo_texture) {
		surface_color *= texture(albedo_texture, UV);
	}
	ALBEDO = surface_color.rgb;
	ALPHA = alpha_scissor_enabled ? surface_color.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_enabled ? alpha_scissor_threshold : 0.0;
	ROUGHNESS = roughness_value;
	if (has_roughness_texture) {
		ROUGHNESS *= dot(texture(roughness_texture, UV), roughness_channel);
	}
	METALLIC = metallic_value;
	if (has_metallic_texture) {
		METALLIC *= dot(texture(metallic_texture, UV), metallic_channel);
	}
	SPECULAR = specular_value;
	// Godot already flips the back-face normal for cull_disabled before this
	// function. Flipping again here would break two-sided leaf lighting.
	if (has_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
