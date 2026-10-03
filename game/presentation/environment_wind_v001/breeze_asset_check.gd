extends SceneTree
## Actual imported sample contract and camera framing; safe under --headless.

var _failures: PackedStringArray = PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://assets/environment_wind_v001/breeze_samples.glb") as PackedScene
	if packed == null:
		push_error("Actual sample is unavailable or not imported")
		quit(1)
		return
	var source := packed.instantiate()
	root.add_child(source)
	var source_meshes: Array[MeshInstance3D] = []
	_collect_meshes(source, source_meshes)
	var zero_weight_count := 0
	var nonzero_weight_count := 0
	var source_materials: Dictionary = {}
	for mesh in source_meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null:
				source_materials[material.get_instance_id()] = material
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for color in colors:
				_check(color.r >= 0.0 and color.r <= 1.0, "weight range")
				if color.r == 0.0:
					zero_weight_count += 1
				else:
					nonzero_weight_count += 1
	for id in source_materials:
		var material: StandardMaterial3D = source_materials[id]
		print("BREEZE_SOURCE_MATERIAL name=%s transparency=%d cull=%d alpha_scissor=%.3f normal_scale=%.3f" % [
			material.resource_name, material.transparency, material.cull_mode, material.alpha_scissor_threshold, material.normal_scale])
	source.free()
	var preview = load("res://presentation/environment_wind_v001/breeze_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	_check(preview._asset_errors.is_empty(), "actual materials convert")
	_check(preview._mesh_count == 6, "six sample meshes")
	_check(preview._surface_count == 12, "twelve material surfaces")
	_check(preview._focus_bounds.size() == 4, "overview plus three sample groups")
	for index in range(preview._focus_bounds.size()):
		preview.focus_sample(index)
		var bounds: AABB = preview._focus_bounds[index]
		_check(bounds.size.x > 0.0 and bounds.size.y > 0.0, "focus bounds contain geometry")
		for point in preview._focus_points[index]:
			var screen: Vector2 = preview.camera.unproject_position(point)
			_check(root.get_visible_rect().has_point(screen), "focus %s bounds fit viewport" % preview._focus_names[index])
		print("BREEZE_FOCUS index=%d name=%s bounds=%s camera_size=%.3f" % [index, preview._focus_names[index], bounds, preview.camera.size])
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(preview.sample_slot, meshes)
	var group_origins: Dictionary = {}
	for mesh in meshes:
		var origin: Variant = mesh.get_instance_shader_parameter("wind_group_origin")
		_check(origin is Vector3, "group origin was assigned")
		group_origins[origin] = true
	_check(group_origins.size() == 3, "stems/leaves/bells share exactly three group phase origins")
	_check(zero_weight_count > 0 and nonzero_weight_count > 0, "asset contains fixed roots and flexible vertices")
	preview.set_wind_time(7.0)
	preview.set_wind_paused(true)
	preview._process(1.0)
	_check(is_equal_approx(preview.wind_time, 7.0), "actual sample pause freezes host time")
	print("BREEZE_WEIGHTS fixed=%d flexible=%d group_origins=%s" % [zero_weight_count, nonzero_weight_count, group_origins.keys()])
	preview.free()
	for failure in _failures:
		push_error(failure)
	print("BREEZE_ASSET_CHECK failures=%d (GPU pixels/shadows unverified)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)

func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
