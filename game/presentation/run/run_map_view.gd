extends Control
## Displays an application snapshot. Node requests are revalidated by the Run session.
signal node_requested(id: String)
signal restart_requested
const Style = preload("res://presentation/run/run_map_style.tres")
const Paths = preload("res://presentation/run/run_map_paths.gd")
var buttons: Dictionary = {}
var _snapshot: Dictionary = {}
var _nodes: Dictionary = {}
var _busy := false
var _notice_key := ""
var _notice_params: Dictionary = {}
var _header: VBoxContainer
var _title: Label
var _subtitle: Label
var _progress: Label
var _build_hint: Label
var _scroll: ScrollContainer
var _canvas: Control
var _paths: Paths
var _footer: VBoxContainer
var _hint: Label
var _notice: Label
var _restart: Button
var _texts: Dictionary = {}


func configure(shared_theme: Theme) -> void:
	assert(shared_theme != null)
	theme = shared_theme
	name = "RunMapView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Style.background
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", Style.gap)
	add_child(_header)
	_title = _label(_header, Style.heading_font_size, Style.heading_color)
	_texts[_title] = "run.map.title"
	_subtitle = _label(_header, Style.hint_font_size, Style.muted_color)
	_texts[_subtitle] = "run.map.session_hint"
	_progress = _label(_header, Style.body_font_size, Style.text_color)
	_build_hint = _label(_header, Style.hint_font_size, Style.muted_color)
	_texts[_build_hint] = "run.map.build_hint"
	_scroll = ScrollContainer.new()
	_scroll.name = "RunRouteScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_force_pass_scroll_events = false
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.name = "RunRouteCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_canvas)
	_paths = Paths.new()
	_paths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_paths)
	_paths.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.resized.connect(_place_nodes)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", Style.gap)
	add_child(_footer)
	_hint = _label(_footer, Style.hint_font_size, Style.text_color)
	_notice = _label(_footer, Style.hint_font_size, Style.notice_color)
	_notice.name = "RunMapNotice"
	_restart = Button.new()
	_restart.name = "RunMapRestart"
	_restart.focus_mode = Control.FOCUS_NONE
	_restart.custom_minimum_size = Vector2(Style.restart_width, Style.button_height)
	_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_restart.add_theme_font_size_override("font_size", Style.body_font_size)
	_restart.pressed.connect(func():
		if not _busy: restart_requested.emit())
	_footer.add_child(_restart)
	_texts[_restart] = "run.restart"
	resized.connect(_layout)
	refresh_text()


func show_route(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_nodes.clear()
	for button in buttons.values():
		_canvas.remove_child(button)
		button.queue_free()
	buttons.clear()
	for entry in _snapshot.nodes:
		var id: String = entry.id
		_nodes[id] = entry
		var button := Button.new()
		button.name = "RunNode_" + id
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_force_pass_scroll_events = false
		button.custom_minimum_size = Style.node_size
		button.add_theme_font_size_override("font_size", Style.node_font_size)
		button.add_theme_color_override("font_color", Style.text_color)
		button.pressed.connect(_request_node.bind(id))
		_canvas.add_child(button)
		buttons[id] = button
	refresh_text()
	_layout()
	_focus_current_layer.call_deferred()
	show()


func set_busy(busy: bool) -> void:
	_busy = busy
	_sync_buttons()
	_refresh_status()


func set_notice(key: String, params: Dictionary = {}) -> void:
	_notice_key = key
	_notice_params = params.duplicate(true)
	_refresh_notice()


func refresh_text() -> void:
	for control in _texts: control.text = tr(_texts[control])
	for id in buttons:
		var entry: Dictionary = _nodes[id]
		buttons[id].text = tr("run.map.node").format({"room": int(entry.layer) + 1, "kind": tr("run.kind." + entry.kind), "state": tr("run.node." + entry.state)})
		buttons[id].tooltip_text = buttons[id].text
	_sync_buttons()
	_refresh_status()
	_refresh_notice()
	_layout.call_deferred()


func _sync_buttons() -> void:
	for id in buttons:
		var entry: Dictionary = _nodes[id]
		var button: Button = buttons[id]
		var surface: StyleBox = Style.node_styles[entry.state]
		for slot in ["normal", "disabled", "pressed"]: button.add_theme_stylebox_override(slot, surface)
		button.add_theme_stylebox_override("hover", Style.available_hover if entry.state == "available" else surface)
		button.add_theme_color_override("font_disabled_color", Style.muted_color if entry.state == "locked" else Style.text_color)
		button.disabled = _busy or entry.state != "available"
	if _restart != null: _restart.disabled = _busy


func _refresh_status() -> void:
	if _progress == null: return
	if _snapshot.is_empty():
		_progress.text = ""
		_hint.text = ""
		return
	_progress.text = tr("run.map.progress").format({"count": int(_snapshot.room_count), "phase": tr("run.phase." + str(_snapshot.phase))})
	var hint_key := "run.map.choose"
	if _busy: hint_key = "run.map.loading"
	elif _snapshot.phase == "completed": hint_key = "run.map.completed"
	elif _snapshot.phase == "defeated": hint_key = "run.map.defeated"
	_hint.text = tr(hint_key)


func _refresh_notice() -> void:
	if _notice == null: return
	_notice.text = tr(_notice_key).format(_notice_params) if not _notice_key.is_empty() else ""
	_notice.visible = not _notice_key.is_empty()
	_layout.call_deferred()


func _request_node(id: String) -> void:
	if _busy or not _nodes.has(id) or _nodes[id].state != "available": return
	node_requested.emit(id)


func _layout() -> void:
	if _header == null or _scroll == null or _footer == null: return
	var width := maxf(0.0, size.x - Style.margin * 2.0)
	var footer_height := maxf(Style.footer_height, _footer.get_combined_minimum_size().y + Style.margin)
	_header.position = Vector2(Style.margin, Style.margin)
	_header.size = Vector2(width, Style.header_height)
	_scroll.position = Vector2(Style.margin, Style.header_height + Style.margin)
	_scroll.size = Vector2(width, maxf(0.0, size.y - Style.header_height - footer_height - Style.margin * 2.0))
	_footer.position = Vector2(Style.margin, size.y - footer_height)
	_footer.size = Vector2(width, footer_height - Style.margin)
	_place_nodes()


func _place_nodes() -> void:
	if _canvas == null or _nodes.is_empty(): return
	var max_layer := 0
	var min_column := 0
	var max_column := 0
	for entry in _nodes.values():
		max_layer = maxi(max_layer, int(entry.layer))
		min_column = mini(min_column, int(entry.column))
		max_column = maxi(max_column, int(entry.column))
	var graph_width: float = (max_column - min_column) * Style.column_pitch + Style.node_size.x
	_canvas.custom_minimum_size = Vector2(graph_width + Style.canvas_padding * 2.0, max_layer * Style.layer_pitch + Style.node_size.y + Style.canvas_padding * 2.0)
	var origin_x := maxf(Style.canvas_padding, (_canvas.size.x - graph_width) / 2.0)
	for id in buttons:
		var entry: Dictionary = _nodes[id]
		var button: Button = buttons[id]
		button.size = Style.node_size
		button.position = Vector2(origin_x + (int(entry.column) - min_column) * Style.column_pitch, Style.canvas_padding + (max_layer - int(entry.layer)) * Style.layer_pitch)
	var connections: Array[Dictionary] = []
	for edge in _snapshot.edges:
		if not buttons.has(edge.from) or not buttons.has(edge.to): continue
		var source: Button = buttons[edge.from]
		var target: Button = buttons[edge.to]
		var line_state := "locked"
		if _nodes[edge.from].state == "completed" and _nodes[edge.to].state in ["completed", "current"]: line_state = "completed"
		elif _nodes[edge.to].state == "available": line_state = "available"
		connections.append({"from": source.position + Vector2(source.size.x / 2.0, 0.0), "to": target.position + Vector2(target.size.x / 2.0, target.size.y), "state": line_state})
	_paths.set_paths(connections)


func _focus_current_layer() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	if _snapshot.has("current_node_id") and buttons.has(_snapshot.current_node_id):
		_scroll.ensure_control_visible(buttons[_snapshot.current_node_id])
	elif not _snapshot.available_node_ids.is_empty() and buttons.has(_snapshot.available_node_ids[0]):
		_scroll.ensure_control_visible(buttons[_snapshot.available_node_ids[0]])


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse: accept_event()
