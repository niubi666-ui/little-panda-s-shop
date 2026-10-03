extends Node3D
## Isolated presentation preview. No actors, combat rules, damage or persistent state.

@export var style: Resource

var _active: Node3D
var _skill_index := 0
var _paused := false
var _slow := false
var _looping := true
var _elapsed := 0.0
var _labels: Dictionary = {}
var _skill_buttons: Array[Button] = []
var _pause_button: Button
var _capture := false
var _capture_root := ""
var _capture_skill := ""
var _capture_at := -1.0
var _capture_frame_count := 0
var _capture_controls := false
var _locale_override := ""
var _controls: Control
var _title: Label
var _skill_label: Label

func _ready() -> void:
	if style == null:
		push_error("Eruption showcase requires its presentation Resource.")
		get_tree().quit(1)
		return
	_parse_args()
	for translation in style.translations:
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale(_locale_override if not _locale_override.is_empty() else style.initial_locale)
	get_window().content_scale_size = style.capture_resolution
	_build_stage()
	_build_lighting()
	_build_ui()
	_spawn_effect()
	if _capture:
		set_process(false)
		_capture_loop.call_deferred()

func _parse_args() -> void:
	_capture_frame_count = style.capture_frames
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-eruptions":
			_capture = true
		elif arg.begins_with("--capture-root="):
			_capture_root = arg.trim_prefix("--capture-root=")
		elif arg.begins_with("--capture-skill="):
			_capture_skill = arg.trim_prefix("--capture-skill=")
		elif arg.begins_with("--capture-at="):
			_capture_at = float(arg.trim_prefix("--capture-at="))
		elif arg.begins_with("--capture-frames="):
			_capture_frame_count = int(arg.trim_prefix("--capture-frames="))
		elif arg == "--capture-controls":
			_capture_controls = true
		elif arg.begins_with("--showcase-locale="):
			_locale_override = arg.trim_prefix("--showcase-locale=")
	if _capture and _capture_root.is_empty():
		_capture_root = ProjectSettings.globalize_path("res://../source_assets/vfx/elemental_eruptions_v001/previews")

func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += delta * _speed()
	if _looping and _elapsed >= style.loop_interval:
		_spawn_effect()

func _unhandled_key_input(event: InputEvent) -> void:
	if _capture or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_spawn_effect()
		KEY_1:
			_select_skill(0)
		KEY_2:
			_select_skill(1)
		KEY_L:
			_toggle_language()
		_:
			return
	get_viewport().set_input_as_handled()

func _speed() -> float:
	return style.slow_speed if _slow else 1.0

func _spawn_effect() -> void:
	if is_instance_valid(_active):
		remove_child(_active)
		_active.queue_free()
	_active = style.effects[_skill_index].instantiate() as Node3D
	add_child(_active)
	_active.call("set_time_running", not _paused and not _capture)
	_active.call("set_playback_speed", _speed())
	_elapsed = 0.0
	_refresh_text()

func _select_skill(index: int) -> void:
	_skill_index = index
	_spawn_effect()

func _set_paused(pressed: bool) -> void:
	_paused = pressed
	if is_instance_valid(_active):
		_active.call("set_time_running", not _paused)
	_refresh_text()

func _set_slow(pressed: bool) -> void:
	_slow = pressed
	if is_instance_valid(_active):
		_active.call("set_playback_speed", _speed())

func _toggle_language() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")
	_refresh_text()

func _refresh_text() -> void:
	for control in _labels:
		control.text = tr(_labels[control])
	if _pause_button != null:
		_pause_button.text = tr("vfx.showcase.resume" if _paused else "vfx.showcase.pause")
	for index in _skill_buttons.size():
		_skill_buttons[index].set_pressed_no_signal(index == _skill_index)
	if _skill_label != null:
		_skill_label.text = tr(style.effect_keys[_skill_index])
		_skill_label.add_theme_color_override("font_color", style.ice_color if _skill_index == 0 else style.rock_color)

func _solid(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = style.details["solid_roughness"]
	return mat

func _emissive(color: Color) -> StandardMaterial3D:
	var mat := _solid(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = style.edge_energy
	return mat

func _box(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)
	return node

func _build_stage() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = style.floor_size
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = style.floor_material
	floor_node.position = style.floor_center
	add_child(floor_node)
	_box(style.platform_position, style.platform_size, style.floor_material)
	var stone := _solid(style.stone_color)
	var metal := _solid(style.metal_color, style.details["metal_metallic"])
	var edge := _emissive(style.edge_color)
	var half: Vector3 = style.platform_size * 0.5
	var center: Vector3 = style.platform_position
	for side in [-1.0, 1.0]:
		_box(Vector3(side * half.x, style.details["edge_elevation"], center.z), Vector3(style.details["edge_width"], style.details["edge_height"], style.platform_size.z), edge)
		_box(Vector3(0, style.details["edge_elevation"], center.z + side * half.z), Vector3(style.platform_size.x, style.details["edge_height"], style.details["edge_width"]), metal)
	for pos in style.pillar_positions:
		_box(pos + Vector3.UP * style.pillar_size.y * 0.5, style.pillar_size, stone)
		_box(pos + Vector3.UP * style.pillar_size.y, style.pillar_cap_size, metal)
		_box(pos + Vector3.UP * (style.pillar_size.y - style.pillar_cap_size.y), style.pillar_band_size, edge)
		var light := OmniLight3D.new()
		light.position = pos + Vector3.UP * style.pillar_light_height
		light.light_color = style.edge_color
		light.light_energy = style.pillar_light_energy
		light.omni_range = style.pillar_light_range
		add_child(light)
	for pos in style.stage_line_positions:
		_box(pos, Vector3(style.stage_line_length, style.details["line_height"], style.stage_line_width), metal)
	var camera := Camera3D.new()
	camera.position = style.camera_position
	camera.fov = style.camera_fov
	add_child(camera)
	camera.look_at(style.camera_target)
	camera.current = true

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = style.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = style.ambient_color
	environment.ambient_light_energy = style.ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = style.glow_intensity
	environment.glow_bloom = style.details["glow_bloom"]
	environment.glow_hdr_threshold = style.details["glow_threshold"]
	environment.ssao_enabled = true
	environment.ssao_radius = style.details["ssao_radius"]
	environment.ssao_intensity = style.details["ssao_intensity"]
	environment.fog_enabled = true
	environment.fog_light_color = style.fog_color
	environment.fog_density = style.fog_density
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_add_spot(style.key_position, style.key_color, style.key_energy, style.key_size)
	_add_spot(style.fill_position, style.fill_color, style.fill_energy, style.fill_size)

func _add_spot(pos: Vector3, color: Color, energy: float, source_size: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.light_size = source_size * style.details["light_size_ratio"]
	light.omni_range = source_size * style.details["light_range_ratio"]
	light.shadow_enabled = true
	add_child(light)

func _label(parent: Node, key: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_y", style.details["shadow_offset"])
	parent.add_child(label)
	_labels[label] = key
	return label

func _button(parent: Node, key: String, toggle: bool = false) -> Button:
	var button := Button.new()
	button.toggle_mode = toggle
	button.custom_minimum_size = style.button_min_size
	button.add_theme_font_size_override("font_size", style.control_size)
	parent.add_child(button)
	_labels[button] = key
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = style.theme.duplicate() as Theme
	root.theme.default_font = style.font
	root.theme.default_font_size = style.control_size
	layer.add_child(root)
	var heading := VBoxContainer.new()
	heading.position = Vector2(style.ui_margin, style.ui_margin)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	_title = _label(heading, "vfx.showcase.title", style.title_size, style.text_color)
	_label(heading, "vfx.showcase.subtitle", style.subtitle_size, style.muted_color)
	_skill_label = _label(heading, "", style.title_size, style.ice_color)
	var disclaimer := Label.new()
	disclaimer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	disclaimer.offset_left = -style.details["disclaimer_width"]
	disclaimer.offset_right = -style.ui_margin
	disclaimer.offset_top = style.ui_margin
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	disclaimer.add_theme_font_size_override("font_size", style.info_size)
	disclaimer.modulate = style.muted_color
	root.add_child(disclaimer)
	_labels[disclaimer] = "vfx.showcase.presentation"
	_controls = VBoxContainer.new()
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_controls.offset_left = style.ui_margin
	_controls.offset_right = -style.ui_margin
	_controls.offset_top = -style.details["controls_height"]
	_controls.offset_bottom = -style.ui_margin
	root.add_child(_controls)
	var hint := _label(_controls, "vfx.showcase.hint", style.info_size, style.muted_color)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var center := CenterContainer.new()
	_controls.add_child(center)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = style.panel_color
	box.content_margin_left = style.details["panel_margin_x"]
	box.content_margin_right = style.details["panel_margin_x"]
	box.content_margin_top = style.details["panel_margin_y"]
	box.content_margin_bottom = style.details["panel_margin_y"]
	box.corner_radius_top_left = style.details["panel_radius"]
	box.corner_radius_top_right = style.details["panel_radius"]
	box.corner_radius_bottom_left = style.details["panel_radius"]
	box.corner_radius_bottom_right = style.details["panel_radius"]
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", style.details["button_separation"])
	panel.add_child(row)
	for index in style.effect_keys.size():
		var choose := _button(row, style.effect_keys[index], true)
		choose.pressed.connect(_select_skill.bind(index))
		_skill_buttons.append(choose)
	_button(row, "vfx.showcase.play").pressed.connect(_spawn_effect)
	_pause_button = _button(row, "vfx.showcase.pause", true)
	_pause_button.toggled.connect(_set_paused)
	_button(row, "vfx.showcase.slow", true).toggled.connect(_set_slow)
	var loop := _button(row, "vfx.showcase.loop", true)
	loop.button_pressed = _looping
	loop.toggled.connect(func(value: bool) -> void: _looping = value)
	var language := _button(row, "vfx.showcase.language")
	language.custom_minimum_size.x = style.details["language_button_width"]
	language.pressed.connect(_toggle_language)
	_controls.visible = not _capture or _capture_controls
	_refresh_text()

func _capture_loop() -> void:
	get_window().size = style.capture_resolution
	var skills: Array[int] = [0, 1]
	if _capture_skill == "ice":
		skills = [0]
	elif _capture_skill == "rock":
		skills = [1]
	for index in skills:
		_skill_index = index
		_spawn_effect()
		var slug := "ice" if index == 0 else "rock"
		var folder := _capture_root.path_join(slug)
		var mkdir_error := DirAccess.make_dir_recursive_absolute(folder)
		if mkdir_error != OK:
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
			var err := image.save_png(folder.path_join(filename))
			if err != OK:
				push_error("Cannot write preview image: " + filename)
				get_tree().quit(1)
				return
			await get_tree().process_frame
		print("ERUPTION_CAPTURE_DONE ", slug, " frames=", count, " path=", folder)
	get_tree().quit()
