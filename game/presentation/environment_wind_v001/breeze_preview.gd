extends Node3D
## Standalone presentation experiment; no session, gameplay RNG, or global classes.

const PROFILE_SCRIPT = preload("res://presentation/environment_wind_v001/breeze_profile.gd")
const WIND_SHADER = preload("res://presentation/environment_wind_v001/breeze.gdshader")

@export var profile: Resource

@onready var sample_slot: Node3D = $Samples
@onready var camera: Camera3D = $Camera3D
@onready var stage: MeshInstance3D = $Stage
@onready var title_label: Label = $PreviewUI/Margin/VBox/Title
@onready var status_label: Label = $PreviewUI/Margin/VBox/Status
@onready var help_label: Label = $PreviewUI/Margin/VBox/Help

var wind_time: float = 0.0
var wind_paused: bool = false
var strength_index: int = 0
var wind_materials: Array[ShaderMaterial] = []
var _material_cache: Dictionary = {}
var _shaders_by_cull: Dictionary = {}
var _focus_bounds: Array[AABB] = []
var _focus_points: Array[PackedVector3Array] = []
var _focus_names: PackedStringArray = PackedStringArray()
var _focus_index: int = 0
var _camera_target: Vector3 = Vector3.ZERO
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _mesh_count: int = 0
var _surface_count: int = 0
var _asset_errors: PackedStringArray = PackedStringArray()

func _ready() -> void:
	title_label.text = "NATURAL BREEZE  /  GPU MATERIAL STUDY"
	help_label.text = "Space pause   1 Gentle / 2 Natural / 3 Stronger   Tab focus sample\nWheel zoom   Right drag orbit   R reset time   H hide labels   Esc exit"
	if profile == null or profile.get_script() != PROFILE_SCRIPT:
		_fail("A breeze_profile.gd Resource is required.")
		return
	var validation: PackedStringArray = profile.validation_errors()
	if not validation.is_empty():
		_fail("Invalid breeze profile:\n" + "\n".join(validation))
		return
	strength_index = profile.initial_strength_index
	_camera_yaw = deg_to_rad(profile.camera_yaw_degrees)
	_camera_pitch = deg_to_rad(profile.camera_pitch_degrees)
	if not _load_samples():
		set_process(false)
		return
	_fit_stage(_focus_bounds[0])
	focus_sample(0)
	_apply_capture_arguments()
	_update_status()
	print("BREEZE_PREVIEW_READY meshes=%d surfaces=%d shared_materials=%d focus_groups=%d" % [
		_mesh_count, _surface_count, wind_materials.size(), _focus_bounds.size() - 1])

func _process(delta: float) -> void:
	if not wind_paused:
		set_wind_time(wind_time + delta)

func set_wind_time(value: float) -> void:
	wind_time = value
	for material in wind_materials:
		material.set_shader_parameter("wind_time", wind_time)

func set_wind_paused(value: bool) -> void:
	wind_paused = value
	_update_status()

func set_wind_strength_index(value: int) -> void:
	if profile == null or value < 0 or value >= profile.strength_levels.size():
		return
	strength_index = value
	for material in wind_materials:
		material.set_shader_parameter("wind_strength", profile.strength_levels[strength_index])
	_update_status()

func focus_sample(index: int) -> void:
	if _focus_bounds.is_empty():
		return
	_focus_index = posmod(index, _focus_bounds.size())
	var bounds := _focus_bounds[_focus_index]
	_camera_target = bounds.get_center()
	_update_camera()
	# Fit each mesh's bounds rather than the eight corners of the whole scene
	# AABB, which invents empty upper corners between low ferns and high canopy.
	var projected_min := Vector2(INF, INF)
	var projected_max := Vector2(-INF, -INF)
	for point in _focus_points[_focus_index]:
		var relative := point - _camera_target
		var projected := Vector2(relative.dot(camera.global_basis.x), relative.dot(camera.global_basis.y))
		projected_min = projected_min.min(projected)
		projected_max = projected_max.max(projected)
	# Leave room for the strongest configured horizontal wind displacement.
	var wind_padding := Vector2(_maximum_wind_displacement_m(), _maximum_wind_displacement_m() * absf(sin(_camera_pitch)))
	projected_min -= wind_padding
	projected_max += wind_padding
	var projected_center := Vector2((projected_min.x + projected_max.x) * 0.5,
		lerpf(projected_min.y, projected_max.y, profile.camera_focus_height_ratio))
	_camera_target += camera.global_basis.x * projected_center.x + camera.global_basis.y * projected_center.y
	_update_camera()
	var projected_size := Vector2(projected_max.x - projected_min.x,
		maxf(projected_max.y - projected_center.y, projected_center.y - projected_min.y) * 2.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	camera.size = clampf(maxf(projected_size.y, projected_size.x / aspect) * profile.camera_fit_margin,
		profile.camera_min_size_m, profile.camera_max_size_m)
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE:
				set_wind_paused(not wind_paused)
			KEY_1, KEY_2, KEY_3:
				set_wind_strength_index(event.keycode - KEY_1)
			KEY_TAB:
				focus_sample(_focus_index + 1)
			KEY_R:
				set_wind_time(0.0)
			KEY_H:
				$PreviewUI.visible = not $PreviewUI.visible
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and profile != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(profile.camera_min_size_m, camera.size / profile.camera_zoom_ratio)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(profile.camera_max_size_m, camera.size * profile.camera_zoom_ratio)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT and profile != null:
		_camera_yaw -= deg_to_rad(event.relative.x * profile.camera_drag_degrees_per_pixel)
		_camera_pitch = clampf(_camera_pitch + deg_to_rad(event.relative.y * profile.camera_drag_degrees_per_pixel), deg_to_rad(5.0), deg_to_rad(80.0))
		_update_camera()

func _load_samples() -> bool:
	if not ResourceLoader.exists(profile.sample_scene_path):
		_fail("Sample asset has not been imported:\n%s" % profile.sample_scene_path)
		return false
	var packed := ResourceLoader.load(profile.sample_scene_path, "PackedScene") as PackedScene
	if packed == null:
		_fail("Sample asset is not a PackedScene: %s" % profile.sample_scene_path)
		return false
	var sample := packed.instantiate()
	if not sample is Node3D:
		sample.free()
		_fail("The sample scene root must be Node3D.")
		return false
	sample_slot.add_child(sample)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(sample, meshes)
	if meshes.is_empty():
		_fail("The sample contains no MeshInstance3D geometry.")
		return false
	var scene_bounds := _bounds_of(meshes)
	_focus_bounds.append(scene_bounds)
	_focus_points.append(_framing_points_of(meshes))
	_focus_names.append("All samples")
	# glTF can wrap the three sample roots in an extra exported collection node.
	var group_parent: Node = sample
	while group_parent.get_child_count() == 1 and not group_parent.get_child(0) is MeshInstance3D:
		group_parent = group_parent.get_child(0)
	for group in group_parent.get_children():
		var group_meshes: Array[MeshInstance3D] = []
		_collect_meshes(group, group_meshes)
		if not group_meshes.is_empty():
			_focus_bounds.append(_bounds_of(group_meshes))
			_focus_points.append(_framing_points_of(group_meshes))
			_focus_names.append(str(group.name))
			for mesh_instance in group_meshes:
				mesh_instance.set_instance_shader_parameter("wind_group_origin", group.global_position)
	for mesh_instance in meshes:
		_convert_mesh_materials(mesh_instance)
	if not _asset_errors.is_empty():
		_fail("Sample material/weight contract failed:\n" + "\n".join(_asset_errors))
		return false
	return true

func _collect_meshes(node: Node, destination: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		destination.append(node)
	for child in node.get_children():
		_collect_meshes(child, destination)

func _bounds_of(meshes: Array[MeshInstance3D]) -> AABB:
	var bounds := meshes[0].global_transform * meshes[0].mesh.get_aabb()
	for index in range(1, meshes.size()):
		bounds = bounds.merge(meshes[index].global_transform * meshes[index].mesh.get_aabb())
	return bounds

func _framing_points_of(meshes: Array[MeshInstance3D]) -> PackedVector3Array:
	var points := PackedVector3Array()
	for mesh in meshes:
		var bounds := mesh.mesh.get_aabb()
		for corner_index in range(8):
			points.append(mesh.global_transform * bounds.get_endpoint(corner_index))
	return points

func _convert_mesh_materials(mesh_instance: MeshInstance3D) -> void:
	_mesh_count += 1
	# CPU updates no geometry. Expand culling bounds once for the maximum
	# configured shader displacement, including the strongest preset.
	mesh_instance.extra_cull_margin = _maximum_wind_displacement_m()
	for surface in range(mesh_instance.mesh.get_surface_count()):
		_surface_count += 1
		if not mesh_instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
			_asset_errors.append("%s surface %d: COLOR.r wind weights are missing" % [mesh_instance.name, surface])
			continue
		var original := mesh_instance.get_active_material(surface) as StandardMaterial3D
		if original == null:
			_asset_errors.append("%s surface %d: StandardMaterial3D is required" % [mesh_instance.name, surface])
			continue
		if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and original.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			_asset_errors.append("%s: only opaque and alpha-scissor sample materials are supported" % original.resource_name)
			continue
		var cache_key := original.get_instance_id()
		if not _material_cache.has(cache_key):
			_material_cache[cache_key] = _convert_material(original)
		mesh_instance.set_surface_override_material(surface, _material_cache[cache_key])

func _maximum_wind_displacement_m() -> float:
	var max_strength: float = 0.0
	for strength in profile.strength_levels:
		max_strength = maxf(max_strength, strength)
	return max_strength * (profile.sway_amplitude_m * (1.0 + profile.steady_push_ratio)
		+ profile.gust_amplitude_m + profile.flutter_amplitude_m)

func _convert_material(original: StandardMaterial3D) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.resource_name = original.resource_name + " | breeze"
	result.shader = _shader_for_cull(original.cull_mode)
	var parameters := {
		"base_color": original.albedo_color,
		"has_albedo_texture": original.albedo_texture != null,
		"albedo_texture": original.albedo_texture,
		"has_normal_texture": original.normal_enabled and original.normal_texture != null,
		"normal_texture": original.normal_texture,
		"normal_scale": original.normal_scale,
		"roughness_value": original.roughness,
		"has_roughness_texture": original.roughness_texture != null,
		"roughness_texture": original.roughness_texture,
		"roughness_channel": _texture_channel(original.roughness_texture_channel),
		"metallic_value": original.metallic,
		"has_metallic_texture": original.metallic_texture != null,
		"metallic_texture": original.metallic_texture,
		"metallic_channel": _texture_channel(original.metallic_texture_channel),
		"specular_value": original.metallic_specular,
		"alpha_scissor_enabled": original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
		"alpha_scissor_threshold": original.alpha_scissor_threshold,
		"uv_scale": Vector2(original.uv1_scale.x, original.uv1_scale.y),
		"uv_offset": Vector2(original.uv1_offset.x, original.uv1_offset.y),
		"wind_time": wind_time,
		"wind_strength": profile.strength_levels[strength_index],
		"wind_direction_xz": profile.direction_xz.normalized(),
		"sway_amplitude_m": profile.sway_amplitude_m,
		"sway_frequency_hz": profile.sway_frequency_hz,
		"steady_push_ratio": profile.steady_push_ratio,
		"gust_amplitude_m": profile.gust_amplitude_m,
		"gust_frequency_hz": profile.gust_frequency_hz,
		"flutter_amplitude_m": profile.flutter_amplitude_m,
		"flutter_frequency_hz": profile.flutter_frequency_hz,
		"spatial_phase_per_m": profile.spatial_phase_per_m,
		"instance_phase_spread": profile.instance_phase_spread,
		"normal_bend_reference_m": profile.normal_bend_reference_m,
	}
	for parameter in parameters:
		result.set_shader_parameter(parameter, parameters[parameter])
	wind_materials.append(result)
	return result

func _shader_for_cull(cull_mode: int) -> Shader:
	if _shaders_by_cull.has(cull_mode):
		return _shaders_by_cull[cull_mode]
	var cull_token: String
	match cull_mode:
		BaseMaterial3D.CULL_BACK:
			cull_token = "cull_back"
		BaseMaterial3D.CULL_FRONT:
			cull_token = "cull_front"
		BaseMaterial3D.CULL_DISABLED:
			cull_token = "cull_disabled"
		_:
			push_error("Unknown source material cull mode: %d" % cull_mode)
			return WIND_SHADER
	var shader := Shader.new()
	shader.code = WIND_SHADER.code.replace("cull_disabled,", cull_token + ",")
	_shaders_by_cull[cull_mode] = shader
	return shader

func _texture_channel(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_RED:
			return Vector4(1.0, 0.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:
			return Vector4(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 0.0)
	push_error("Unknown texture channel: %d" % channel)
	return Vector4.ZERO

func _fit_stage(bounds: AABB) -> void:
	var box := stage.mesh as BoxMesh
	box.size = Vector3(bounds.size.x + 2.0 * profile.stage_margin_m, profile.stage_depth_m,
		bounds.size.z + 2.0 * profile.stage_margin_m)
	stage.position = Vector3(bounds.get_center().x, bounds.position.y - profile.stage_depth_m * 0.5 - 0.002, bounds.get_center().z)

func _update_camera() -> void:
	# Distance affects clipping only for an orthographic preview camera.
	var distance: float = camera.far * 0.25
	var horizontal := cos(_camera_pitch) * distance
	camera.position = _camera_target + Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * distance, cos(_camera_yaw) * horizontal)
	camera.look_at(_camera_target, Vector3.UP)

func _update_status() -> void:
	if not is_node_ready() or profile == null or _focus_names.is_empty():
		return
	status_label.text = "%s  |  %s  |  %s\n%d meshes / %d surfaces / %d shared wind materials" % [
		profile.strength_labels[strength_index], "Paused" if wind_paused else "Playing", _focus_names[_focus_index],
		_mesh_count, _surface_count, wind_materials.size()]

func _apply_capture_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--breeze-paused":
			set_wind_paused(true)
		elif argument.begins_with("--breeze-time="):
			set_wind_time(argument.get_slice("=", 1).to_float())
		elif argument.begins_with("--breeze-strength="):
			set_wind_strength_index(argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--breeze-focus="):
			focus_sample(argument.get_slice("=", 1).to_int())
		elif argument == "--breeze-hide-ui":
			$PreviewUI.visible = false

func _fail(message: String) -> void:
	push_error(message)
	status_label.text = message
	status_label.modulate = Color(1.0, 0.62, 0.51)
	set_process(false)
