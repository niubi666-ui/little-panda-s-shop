extends "res://presentation/combat/eruption_showcase/showcase.gd"

func _parse_args() -> void:
	super._parse_args()
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-frostfall": _capture = true
	if _capture and _capture_root.is_empty():
		_capture_root = ProjectSettings.globalize_path("res://../source_assets/vfx/frostfall_v001/previews")

func _build_ui() -> void:
	super._build_ui()
	for control in _labels:
		if _labels[control] == "vfx.showcase.title": _labels[control] = "vfx.frostfall.title"
		elif _labels[control] == "vfx.showcase.subtitle": _labels[control] = "vfx.frostfall.subtitle"
		elif _labels[control] == "vfx.showcase.hint": _labels[control] = "vfx.frostfall.hint"
	_refresh_text()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_2: return
	super._unhandled_key_input(event)

func _capture_loop() -> void:
	get_window().size = style.capture_resolution
	var folder := _capture_root.path_join("frostfall")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Cannot create frostfall capture folder: " + folder)
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var count: int = 1 if _capture_at >= 0.0 else _capture_frame_count
	for frame: int in count:
		var time: float = _capture_at if _capture_at >= 0.0 else float(frame) / style.capture_fps
		_active.seek_visual(time)
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(folder.path_join("frame_%04d.png" % frame)) != OK:
			push_error("Frostfall frame write failed: " + str(frame))
			get_tree().quit(1)
			return
		await get_tree().process_frame
	print("FROSTFALL_CAPTURE_DONE frames=", count, " path=", folder)
	get_tree().quit()
