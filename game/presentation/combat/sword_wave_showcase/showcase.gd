extends "res://presentation/combat/eruption_showcase/showcase.gd"
## Isolated sword-wave art demonstration; the target is only a scale reference.

func _parse_args() -> void:
	super._parse_args()
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-sword-waves":
			_capture = true
	if _capture and _capture_root.is_empty():
		_capture_root = ProjectSettings.globalize_path(style.capture_default_directory)

func _build_ui() -> void:
	super._build_ui()
	for control in _labels:
		var key: String = _labels[control]
		if style.heading_keys.has(key):
			_labels[control] = style.heading_keys[key]
	_refresh_text()

func _build_stage() -> void:
	super._build_stage()
	var config: Dictionary = style.target_marker
	var origin: Vector3 = config["position"]
	var stone: Material = _solid(config["stone_color"], config["stone_metallic"])
	var accent: Material = _solid(config["accent_color"], config["accent_metallic"])
	_add_cylinder(origin + Vector3.UP * float(config["base_height"]) * 0.5, config["base_radius"], config["base_height"], stone)
	_add_cylinder(origin + Vector3.UP * float(config["shaft_height"]) * 0.5, config["shaft_radius"], config["shaft_height"], stone)
	var torus := TorusMesh.new()
	torus.inner_radius = config["ring_inner_radius"]
	torus.outer_radius = config["ring_outer_radius"]
	torus.rings = config["segments"]
	torus.ring_segments = config["ring_segments"]
	var marker := MeshInstance3D.new()
	marker.name = "StaticScaleTarget"
	marker.mesh = torus
	marker.material_override = accent
	marker.position = origin + config["ring_center_offset"]
	marker.rotation_degrees = config["ring_rotation"]
	add_child(marker)
	_box(origin + config["ring_center_offset"], config["cross_size"], accent)

func _add_cylinder(pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = style.target_marker["segments"]
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)

func _capture_loop() -> void:
	get_window().size = style.capture_resolution
	var skills: Array[int] = []
	for index in style.skill_slugs.size():
		if _capture_skill.is_empty() or _capture_skill == style.skill_slugs[index]:
			skills.append(index)
	if skills.is_empty():
		push_error("Unknown sword-wave capture selection: " + _capture_skill)
		get_tree().quit(1)
		return
	for index in skills:
		_skill_index = index
		_spawn_effect()
		var slug: String = style.skill_slugs[index]
		var folder := _capture_root.path_join(slug)
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			push_error("Cannot create preview folder: " + folder)
			get_tree().quit(1)
			return
		await get_tree().process_frame
		var count := 1 if _capture_at >= 0.0 else _capture_frame_count
		for frame in count:
			var time: float = _capture_at if _capture_at >= 0.0 else float(frame) / style.capture_fps
			if is_instance_valid(_active):
				_active.call("seek_visual", time)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var filename := "frame_%04d.png" % frame
			if image.save_png(folder.path_join(filename)) != OK:
				push_error("Cannot write preview image: " + filename)
				get_tree().quit(1)
				return
			await get_tree().process_frame
		print("SWORD_WAVE_CAPTURE_DONE ", slug, " frames=", count, " path=", folder)
	get_tree().quit()
