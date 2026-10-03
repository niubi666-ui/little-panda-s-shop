extends Control
## Run room identity and navigation only. Health/progression stay application-owned.
signal map_requested
signal restart_requested
const Style = preload("res://presentation/run/run_map_style.tres")
var _panel: PanelContainer
var _number: Label
var _kind_label: Label
var _health: Label
var _phase_label: Label
var _action: Button
var _controls_panel: PanelContainer
var _controls: Label
var _ordinal := 0
var _kind := ""
var _hp := 0.0
var _max_hp := 0.0
var _phase := ""
var _busy := false


func configure(shared_theme: Theme) -> void:
	assert(shared_theme != null)
	theme = shared_theme
	name = "RoomProgressHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "RoomProgressPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_force_pass_scroll_events = false
	_panel.add_theme_stylebox_override("panel", Style.panel_style)
	_panel.custom_minimum_size.x = Style.room_width
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, Style.room_padding)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", Style.gap)
	margin.add_child(column)
	_number = _label(column, Style.room_number_font_size, Style.heading_color)
	_number.name = "RunRoomNumber"
	_kind_label = _label(column, Style.body_font_size, Style.text_color)
	_health = _label(column, Style.body_font_size, Style.text_color)
	_health.name = "RunPlayerHealth"
	_phase_label = _label(column, Style.hint_font_size, Style.heading_color)
	_action = Button.new()
	_action.name = "RunRoomAction"
	_action.focus_mode = Control.FOCUS_NONE
	_action.mouse_filter = Control.MOUSE_FILTER_STOP
	_action.custom_minimum_size.y = Style.button_height
	_action.add_theme_font_size_override("font_size", Style.body_font_size)
	_action.pressed.connect(_request_action)
	column.add_child(_action)
	_controls_panel = PanelContainer.new()
	_controls_panel.name = "RunControlsPanel"
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_panel.add_theme_stylebox_override("panel", Style.panel_style)
	add_child(_controls_panel)
	var controls_margin := MarginContainer.new()
	controls_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		controls_margin.add_theme_constant_override(side, Style.room_padding)
	_controls_panel.add_child(controls_margin)
	_controls = _label(controls_margin, Style.hint_font_size, Style.text_color)
	_controls.name = "RunControlsHint"
	_controls_panel.minimum_size_changed.connect(_layout.call_deferred)
	_panel.minimum_size_changed.connect(_layout.call_deferred)
	resized.connect(_layout)
	_panel.hide()
	_controls_panel.hide()


func display(ordinal: int, kind: String, hp: float, max_hp: float, phase: String) -> void:
	if _ordinal == ordinal and _kind == kind and _hp == hp and _max_hp == max_hp and _phase == phase: return
	_ordinal = ordinal
	_kind = kind
	_hp = hp
	_max_hp = max_hp
	_phase = phase
	_panel.show()
	_controls_panel.show()
	refresh_text()


func set_busy(busy: bool) -> void:
	_busy = busy
	if _action != null: _action.disabled = busy


func refresh_text() -> void:
	if _number == null or _phase.is_empty(): return
	_number.text = tr("run.room.number").format({"room": _ordinal})
	_kind_label.text = tr("run.kind." + _kind)
	_health.text = tr("run.room.health").format({"hp": ceili(_hp), "max_hp": ceili(_max_hp)})
	_phase_label.text = tr("run.phase." + _phase)
	_phase_label.visible = _phase != "combat"
	_action.visible = _phase in ["cleared", "completed", "defeated"]
	_action.text = tr("run.return_map" if _phase == "cleared" else "run.restart")
	_action.disabled = _busy
	_controls.text = tr("run.room.controls")
	_layout.call_deferred()


func _request_action() -> void:
	if _busy: return
	if _phase == "cleared": map_requested.emit()
	elif _phase in ["completed", "defeated"]: restart_requested.emit()


func _layout() -> void:
	if _panel == null: return
	_panel.size = Vector2(Style.room_width, 0.0)
	_panel.reset_size()
	_panel.position = Vector2(maxf(Style.margin, (size.x - _panel.size.x) / 2.0), Style.margin)
	_controls_panel.size = Vector2(maxf(0.0, size.x - Style.margin * 2.0), _controls_panel.get_combined_minimum_size().y)
	_controls_panel.position = Vector2(Style.margin, size.y - Style.margin - _controls_panel.size.y)


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
