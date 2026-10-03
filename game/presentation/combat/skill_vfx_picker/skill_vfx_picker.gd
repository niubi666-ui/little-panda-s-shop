extends Control
## A collapsible visual rehearsal panel. Emits requests; owns no combat state.
signal effect_requested(id: StringName)
signal replay_requested
signal clear_requested

var buttons: Dictionary = {}
var toggle: Button
var replay: Button
var clear: Button
var _panel: PanelContainer
var _body: VBoxContainer
var _style: Resource
var _texts: Dictionary = {}
var _available := false
var _has_selection := false
var _right_column_reserved := false

func configure(style: Resource, shared_theme: Theme) -> void:
	assert(style != null and style.valid() and shared_theme != null)
	_style = style
	theme = shared_theme
	name = "SkillVfxPicker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_force_pass_scroll_events = false
	_panel.add_theme_stylebox_override("panel", style.panel_style)
	_panel.custom_minimum_size.x = style.panel_width
	add_child(_panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, style.padding)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", style.row_gap)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", style.row_gap)
	column.add_child(heading)
	toggle = _button(heading, "training.skill_vfx.title")
	toggle.name = "SkillVfxToggle"
	toggle.add_theme_font_size_override("font_size", style.title_font_size)
	toggle.toggle_mode = true
	_compact_header_button(toggle, false)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", style.row_gap)
	column.add_child(_body)
	var effects := GridContainer.new()
	effects.columns = style.option_columns
	effects.add_theme_constant_override("h_separation", style.row_gap)
	effects.add_theme_constant_override("v_separation", style.row_gap)
	_body.add_child(effects)
	for id in style.effects:
		var button := _button(effects, style.name_keys[id])
		button.name = "Cast_" + String(id)
		button.add_theme_color_override("font_color", style.option_colors[id])
		button.pressed.connect(func():
			if _available: effect_requested.emit(id))
		buttons[id] = button
	replay = _button(heading, "training.skill_vfx.replay")
	replay.name = "ReplaySkillVfx"
	_compact_header_button(replay, true)
	replay.pressed.connect(func():
		if _available and _has_selection: replay_requested.emit())
	clear = _button(heading, "training.skill_vfx.clear")
	clear.name = "ClearSkillVfx"
	_compact_header_button(clear, true)
	clear.pressed.connect(func():
		if _available: clear_requested.emit())
	toggle.set_pressed_no_signal(true)
	toggle.toggled.connect(func(expanded: bool):
		_body.visible = expanded
		refresh_text())
	_panel.minimum_size_changed.connect(_layout.call_deferred)
	resized.connect(_layout)
	refresh_text()
	set_available(false)

func _button(parent: Node, key: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = _style.button_height
	button.add_theme_font_size_override("font_size", _style.body_font_size)
	_texts[button] = key
	parent.add_child(button)
	return button

func _compact_header_button(button: Button, icon: bool) -> void:
	button.custom_minimum_size.y = _style.header_height
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if icon:
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = _style.header_action_width

func set_available(available: bool) -> void:
	_available = available
	for button in buttons.values(): button.disabled = not available
	replay.disabled = not available or not _has_selection
	clear.disabled = not available

func set_selected(id: StringName) -> void:
	_has_selection = buttons.has(id)
	for key in buttons:
		buttons[key].add_theme_color_override("font_color", _style.option_colors[key])
	replay.disabled = not _available or not _has_selection

func refresh_text() -> void:
	for node in _texts:
		node.text = tr(_texts[node])
		if node is Button: node.tooltip_text = node.text
	toggle.text = ("▾ " if toggle.button_pressed else "▸ ") + tr("training.skill_vfx.title")
	toggle.tooltip_text = tr("training.skill_vfx.hint")
	replay.text = "↻"
	clear.text = "×"
	_layout.call_deferred()

func set_right_column_reserved(reserved: bool) -> void:
	_right_column_reserved = reserved
	_layout.call_deferred()

func _layout() -> void:
	if _panel == null: return
	_panel.size = _panel.get_combined_minimum_size()
	var x: float = (size.x - _panel.size.x) * 0.5 if _right_column_reserved else size.x - _style.right_margin - _panel.size.x
	var bottom: float = _style.center_bottom_margin if _right_column_reserved else _style.bottom_margin
	_panel.position = Vector2(maxf(0.0, x), maxf(0.0, size.y - bottom - _panel.size.y))
