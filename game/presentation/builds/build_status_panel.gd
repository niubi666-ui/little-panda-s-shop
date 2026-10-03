extends PanelContainer
signal test_offer_requested
signal test_preset_requested(id: String)

const Style = preload("res://presentation/builds/build_ui_style.tres")
var _catalog
var _selections: Array = []
var _program: Dictionary = {}
var _title: Label
var _summary: Label
var _notice: Label
var _notice_key := ""
var _notice_params: Dictionary = {}
var _test_button: Button
var _preset_menu: MenuButton
var _presets: Array = []


func configure(catalog, shared_theme: Theme, enable_test_presets: bool = false) -> void:
	assert(catalog != null and shared_theme != null)
	_catalog = catalog
	theme = shared_theme
	name = "BuildStatusPanel"
	position = Style.status_position
	custom_minimum_size.x = Style.status_width
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.status_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, Style.status_padding)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", Style.status_gap)
	margin.add_child(stack)
	_title = _label(stack)
	_title.theme_type_variation = &"PaperHeading"
	_title.add_theme_color_override("font_color", Style.gold_color)
	var divider := ColorRect.new()
	divider.color = Style.separator_color
	divider.custom_minimum_size.y = Style.separator_height
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(divider)
	var summary_scroll := ScrollContainer.new()
	summary_scroll.name = "BuildSummaryScroll"
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.custom_minimum_size.y = Style.status_summary_height
	stack.add_child(summary_scroll)
	_summary = _label(summary_scroll)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice = _label(stack)
	_notice.name = "BuildNotice"
	_notice.theme_type_variation = &"Muted"
	_notice.add_theme_color_override("font_color", Style.error_color)
	_test_button = Button.new()
	_test_button.name = "BuildTestOffer"
	_test_button.custom_minimum_size.y = Style.status_button_height
	_test_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_button.pressed.connect(func(): test_offer_requested.emit())
	stack.add_child(_test_button)
	if enable_test_presets:
		_presets = _catalog.test_presets()
		_preset_menu = MenuButton.new()
		_preset_menu.name = "BuildTestPresets"
		_preset_menu.custom_minimum_size.y = Style.status_button_height
		_preset_menu.get_popup().id_pressed.connect(func(index: int):
			if index >= 0 and index < _presets.size(): test_preset_requested.emit(_presets[index].id))
		stack.add_child(_preset_menu)
	refresh_text()


func update_state(selections: Array, program: Dictionary = {}) -> void:
	_selections = selections.duplicate(true)
	_program = program
	refresh_text()

func has_open_popup() -> bool:
	return _preset_menu != null and _preset_menu.get_popup().visible


func set_notice(key: String, params: Dictionary = {}) -> void:
	_notice_key = key
	_notice_params = params.duplicate(true)
	refresh_text()


func refresh_text() -> void:
	if _title == null:
		return
	_title.text = tr("build.owned")
	var lines: PackedStringArray = []
	for action_id in ["primary", "special", "global"]:
		var action_lines: PackedStringArray = []
		if _program.has("actions") and _program.actions.has(action_id):
			var form: Dictionary = _catalog.form(_program.actions[action_id].form_id)
			action_lines.append(tr("build.current_form").format({"form": tr(form.name_key)}))
		for selection in _selections:
			if selection.action_id != action_id: continue
			var entry: Dictionary = _catalog.upgrade(selection.upgrade_id)
			var rank_text := tr("build.rank").format({"rank": int(selection.rank), "max_rank": int(entry.max_rank)})
			action_lines.append(tr("build.layer." + entry.layer) + " · " + tr(entry.name_key) + "  " + rank_text)
		if not action_lines.is_empty():
			lines.append(_action_label(action_id))
			lines.append("\n".join(action_lines))
			lines.append("")
	_summary.text = tr("build.empty") if lines.is_empty() else "\n".join(lines)
	var params := _notice_params.duplicate(true)
	if params.has("name_key"):
		params.name = tr(params.name_key)
		params.erase("name_key")
	_notice.text = tr(_notice_key).format(params) if not _notice_key.is_empty() else ""
	_notice.visible = not _notice_key.is_empty()
	_test_button.text = tr("build.test_offer")
	if _preset_menu != null:
		_preset_menu.text = tr("build.preset.title")
		_preset_menu.tooltip_text = tr("build.preset.hint")
		var popup := _preset_menu.get_popup()
		popup.clear()
		for index in _presets.size(): popup.add_item(tr(_presets[index].name_key), index)
	reset_size()
	_fit_after_layout.call_deferred()


func _action_label(action_id: String) -> String:
	var label := tr("build.action." + action_id)
	var input_id: String = {"primary": "combat_attack", "special": "combat_special"}.get(action_id, "")
	if input_id.is_empty() or not InputMap.has_action(input_id): return label
	var events := InputMap.action_get_events(input_id)
	if events.is_empty(): return label
	var event: InputEvent = events[0]
	var key := event.as_text()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: key = tr("build.input.left_mouse")
		elif event.button_index == MOUSE_BUTTON_RIGHT: key = tr("build.input.right_mouse")
	return tr("build.action_binding").format({"action": label, "key": key})


func _fit_after_layout() -> void:
	# Measure wrapping at the actual container width, without a resize signal loop.
	await get_tree().process_frame
	if is_inside_tree(): reset_size()


func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
