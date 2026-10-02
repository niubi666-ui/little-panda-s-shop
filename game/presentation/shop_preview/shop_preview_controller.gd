class_name ShopPreviewController
extends Node
## Temporary input/presentation slice. No shop transactions, inventory or save writes.
## Parent injects world references, validated tuning and model-specific presentation.

const Definition = preload("res://content/shop_preview/shop_preview_definition.gd")
const Presentation = preload("res://presentation/shop_preview/shop_preview_presentation.gd")
const Selection = preload("res://presentation/shop_preview/shop_interaction_selection.gd")

signal interaction_opened(instance_id: StringName, definition_id: StringName)
signal interaction_closed

var _player: CharacterBody3D
var _camera: Camera3D
var _visual: Node3D
var _animation_player: AnimationPlayer
var _targets: Array[Node3D] = []
var _definition: Definition
var _presentation: Presentation
var _configured: bool = false
var _nearby_target: Node3D
var _opened_target: Node3D
var _dialog_open: bool = false
var _current_animation: StringName
var _external_ui_open := false

var _hud: Control
var _title: Label
var _language: Button
var _controls: Label
var _prompt_panel: PanelContainer
var _prompt: Label
var _modal: Control
var _dialog_title: Label
var _dialog_message: Label
var _close_button: Button
var _close_hint: Label


func _init() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)


func configure(
	player: CharacterBody3D,
	camera: Camera3D,
	visual: Node3D,
	animation_player: AnimationPlayer,
	targets: Array[Node3D],
	ui_parent: Node,
	definition: Definition,
	presentation: Presentation
) -> Error:
	if _configured or player == null or camera == null or visual == null or ui_parent == null or definition == null or presentation == null or presentation.theme == null:
		push_error("ShopPreviewController: configure requires valid injected dependencies and may only run once.")
		return ERR_INVALID_PARAMETER
	var checked_targets: Array[Node3D] = []
	for target: Node3D in targets:
		var target_error := _validate_target(target, checked_targets)
		if target_error != OK:
			return target_error
		checked_targets.append(target)
	for animation_name: StringName in [presentation.idle_animation, presentation.move_animation]:
		if not animation_name.is_empty() and (animation_player == null or not animation_player.has_animation(animation_name)):
			push_error("ShopPreviewController: configured animation is missing: " + str(animation_name))
			return ERR_INVALID_DATA
	_player = player
	_camera = camera
	_visual = visual
	_animation_player = animation_player
	_targets = checked_targets
	_definition = definition
	_presentation = presentation
	# Preserve a language already selected in the shared settings menu.
	if TranslationServer.get_locale() not in ["zh_CN", "en"]:
		TranslationServer.set_locale(_definition.get_default_locale())
	_create_ui(ui_parent)
	_configured = true
	set_physics_process(true)
	set_process_unhandled_input(true)
	refresh_nearby_target()
	_refresh_text()
	_play_animation(_presentation.idle_animation)
	return OK


func register_target(target: Node3D) -> Error:
	if not _configured:
		return ERR_UNCONFIGURED
	var error := _validate_target(target, _targets)
	if error != OK:
		return error
	_targets.append(target)
	refresh_nearby_target()
	return OK


func unregister_target(target: Node3D) -> void:
	# The parent/coordinator calls this before deleting or replacing a furniture instance.
	# No scene-tree scanning or implicit registration from model names.
	if not _configured:
		return
	_targets.erase(target)
	if target == _opened_target:
		close_interaction()
	refresh_nearby_target()


func _validate_target(target: Node3D, registered: Array[Node3D]) -> Error:
	if not is_instance_valid(target):
		return ERR_INVALID_PARAMETER
	for key: String in ["instance_id", "definition_id", "name_key", "action_key"]:
		if not target.has_meta(key):
			return ERR_INVALID_DATA
		var value: Variant = target.get_meta(key)
		if not (value is String or value is StringName) or str(value).is_empty():
			return ERR_INVALID_DATA
	for existing: Node3D in registered:
		if is_instance_valid(existing) and str(existing.get_meta("instance_id")) == str(target.get_meta("instance_id")):
			return ERR_ALREADY_EXISTS
	return OK


func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(_player):
		return
	var input_direction := Vector2.ZERO
	if not _dialog_open and not _external_ui_open:
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := _camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var direction := right * input_direction.x - forward * input_direction.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	_player.velocity.x = direction.x * _definition.get_speed_mps()
	_player.velocity.z = direction.z * _definition.get_speed_mps()
	if _player.is_on_floor():
		_player.velocity.y = 0.0
	else:
		_player.velocity.y -= _definition.get_gravity_mps2() * delta
	# Single movement authority for this preview; root must not move_and_slide elsewhere.
	_player.move_and_slide()
	var moving := not direction.is_zero_approx()
	if moving:
		var wanted_yaw := atan2(-direction.x, -direction.z) + deg_to_rad(_presentation.visual_yaw_offset_deg)
		_visual.global_rotation.y = rotate_toward(_visual.global_rotation.y, wanted_yaw, _definition.get_turn_speed_radps() * delta)
		_play_animation(_presentation.move_animation)
	else:
		_play_animation(_presentation.idle_animation)
	refresh_nearby_target()
	if _dialog_open and (not is_instance_valid(_opened_target) or not _opened_target.is_inside_tree()):
		close_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if not _configured or event.is_echo():
		return
	if event.is_action_pressed("toggle_language"):
		toggle_language()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _dialog_open:
		close_interaction()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if not _dialog_open:
			try_interact()
		get_viewport().set_input_as_handled()


func refresh_nearby_target() -> void:
	if not _configured:
		return
	var selected := Selection.find_nearest(_player.global_position, _targets, _definition.get_interaction_distance_m())
	if selected != _nearby_target:
		_nearby_target = selected
		_refresh_text()
	_prompt_panel.visible = not _dialog_open and not _external_ui_open and is_instance_valid(_nearby_target)


func try_interact() -> bool:
	if not _configured or _dialog_open or _external_ui_open:
		return false
	refresh_nearby_target()
	if not is_instance_valid(_nearby_target):
		return false
	_opened_target = _nearby_target
	_dialog_open = true
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	_modal.show()
	_prompt_panel.hide()
	_refresh_text()
	_close_button.grab_focus()
	_play_animation(_presentation.idle_animation)
	interaction_opened.emit(StringName(_opened_target.get_meta("instance_id")), StringName(_opened_target.get_meta("definition_id")))
	return true


func close_interaction() -> void:
	if not _dialog_open:
		return
	_dialog_open = false
	_opened_target = null
	_modal.hide()
	_close_button.release_focus()
	refresh_nearby_target()
	interaction_closed.emit()


func is_interaction_open() -> bool:
	return _dialog_open

func set_external_ui_open(open: bool) -> void:
	if open:
		close_interaction()
	_external_ui_open = open
	refresh_nearby_target()

func use_foliage_shell() -> void:
	_title.hide()
	_language.hide()
	_controls.hide()
	var footer_space := Control.new()
	footer_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_space.custom_minimum_size.y = _presentation.theme.get_constant("footer_height", "Foliage")
	_controls.get_parent().add_child(footer_space)


func get_nearby_instance_id() -> StringName:
	if not is_instance_valid(_nearby_target):
		return &""
	return StringName(_nearby_target.get_meta("instance_id"))


func is_interaction_prompt_visible() -> bool:
	return _configured and _prompt_panel.visible


func toggle_language() -> void:
	var next_locale := "en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN"
	TranslationServer.set_locale(next_locale)
	_refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _configured:
		_refresh_text()


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()


func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null or animation_name.is_empty() or animation_name == _current_animation:
		return
	_current_animation = animation_name
	_animation_player.play(animation_name, _presentation.animation_blend_sec)


func _refresh_text() -> void:
	if not _configured:
		return
	_title.text = _message("shop.preview.title")
	_language.text = _message("shop.preview.language", {"key": _key_label("toggle_language")})
	_controls.text = _message("shop.preview.controls", {
		"move_keys": "/".join([_key_label("move_forward"), _key_label("move_left"), _key_label("move_back"), _key_label("move_right")]),
		"interact_key": _key_label("interact")
	})
	if is_instance_valid(_nearby_target):
		_prompt.text = _message("shop.preview.prompt", {
			"key": _key_label("interact"),
			"action": _message(str(_nearby_target.get_meta("action_key"))),
			"target": _message(str(_nearby_target.get_meta("name_key")))
		})
	if is_instance_valid(_opened_target):
		_dialog_title.text = _message(str(_opened_target.get_meta("name_key")))
	_dialog_message.text = _message("shop.preview.pending")
	_close_button.text = _message("shop.preview.close")
	_close_hint.text = _message("shop.preview.close_hint", {"key": _key_label("ui_cancel")})


func _message(key: String, parameters: Dictionary = {}) -> String:
	return str(TranslationServer.translate(StringName(key))).format(parameters)


func _key_label(action: StringName) -> String:
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event
			var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			return OS.get_keycode_string(keycode)
	# Missing input mappings are integration errors, never a fabricated key hint.
	push_error("ShopPreviewController: no keyboard binding for %s" % action)
	return "[" + str(action) + "]"


func _create_ui(ui_parent: Node) -> void:
	_hud = Control.new()
	_hud.name = "ShopPreviewHUD"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = _presentation.theme
	ui_parent.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, _presentation.hud_margin_px)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_language = Button.new()
	_language.focus_mode = Control.FOCUS_NONE
	_language.flat = true
	_language.pressed.connect(toggle_language)
	header.add_child(_language)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var prompt_center := CenterContainer.new()
	prompt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(prompt_center)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.hide()
	prompt_center.add_child(_prompt_panel)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt)
	var gap := Control.new()
	gap.custom_minimum_size.y = _presentation.prompt_bottom_px
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	_controls = Label.new()
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_controls)
	_create_modal()


func _create_modal() -> void:
	_modal = Control.new()
	_modal.name = "InteractionPlaceholder"
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = _presentation.dim_color
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = _presentation.dialog_width_px
	center.add_child(panel)
	var padding := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, _presentation.dialog_padding_px)
	panel.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", _presentation.dialog_gap_px)
	padding.add_child(content)
	_dialog_title = Label.new()
	_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_dialog_title)
	_dialog_message = Label.new()
	_dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_dialog_message)
	_close_button = Button.new()
	_close_button.pressed.connect(close_interaction)
	content.add_child(_close_button)
	_close_hint = Label.new()
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_close_hint)
	_modal.hide()
