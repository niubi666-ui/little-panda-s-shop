extends PanelContainer

signal effect_selected(effect_id: StringName)

var buttons: Dictionary = {}
var selected_id: StringName
var _texts: Dictionary = {}
var _button_group: ButtonGroup


func configure(palette: Resource, shared_theme: Theme) -> void:
	assert(palette != null and shared_theme != null, "Effect picker requires its palette and shared theme.")
	assert(palette.panel_width > 0.0 and palette.margin >= 0.0, "Invalid effect picker dimensions.")
	assert(palette.column_gap >= 0 and palette.row_gap >= 0, "Invalid effect picker spacing.")
	assert(palette.title_font_size > 0 and palette.hint_font_size > 0 and palette.button_font_size > 0 and palette.button_height > 0.0, "Invalid effect picker typography.")
	assert(not palette.options.is_empty(), "Effect picker requires effect options.")
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	_texts.clear()
	selected_id = &""
	theme = shared_theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.x = palette.panel_width
	_button_group = ButtonGroup.new()
	var margin_container := MarginContainer.new()
	margin_container.mouse_filter = Control.MOUSE_FILTER_PASS
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin_container.add_theme_constant_override(edge, int(palette.margin))
	add_child(margin_container)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", palette.row_gap)
	margin_container.add_child(stack)
	var title := _add_label(stack, "combat.fx.title")
	title.add_theme_font_size_override("font_size", palette.title_font_size)
	var hint := _add_label(stack, "combat.fx.hint")
	hint.theme_type_variation = &"Muted"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", palette.hint_font_size)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", palette.column_gap)
	grid.add_theme_constant_override("v_separation", palette.row_gap)
	stack.add_child(grid)
	for option in palette.options:
		assert(option != null and not option.id.is_empty() and not option.name_key.is_empty() and option.scene != null, "Invalid effect picker option.")
		assert(not buttons.has(option.id), "Duplicate effect picker ID: " + String(option.id))
		var button := Button.new()
		button.name = String(option.id)
		button.toggle_mode = true
		button.button_group = _button_group
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = palette.button_height
		button.add_theme_font_size_override("font_size", palette.button_font_size)
		button.pressed.connect(_request_selection.bind(option.id))
		grid.add_child(button)
		buttons[option.id] = button
		_texts[button] = option.name_key
	refresh_text()


func set_selected(id: StringName) -> void:
	assert(buttons.has(id), "Unknown effect picker ID: " + String(id))
	selected_id = id
	_sync_buttons()


func refresh_text() -> void:
	for node in _texts:
		node.text = tr(_texts[node])
		if node is Button:
			node.tooltip_text = node.text


func _add_label(parent: Node, key: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	_texts[label] = key
	return label


func _request_selection(id: StringName) -> void:
	# The application confirms the active effect through set_selected().
	_sync_buttons()
	effect_selected.emit(id)


func _sync_buttons() -> void:
	for id in buttons:
		buttons[id].set_pressed_no_signal(id == selected_id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
