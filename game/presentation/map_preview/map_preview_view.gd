extends Control
signal close_requested
signal new_map_requested
signal seed_requested(seed_text: String)
const Canvas = preload("res://presentation/map_preview/map_graph_canvas.gd")
var style: Resource
var graph: Control
var seed_edit: LineEdit
var new_button: Button
var apply_button: Button
var close_button: Button
var scroll: ScrollContainer
var details: Label
var stats: Label
var notice: Label
var _labels: Dictionary = {}
var _plan: Dictionary = {}
var _selected := ""
var _error_key := ""

func configure(shared_theme: Theme, value: Resource) -> void:
	style = value
	theme = shared_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = style.background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, style.margin)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", style.gap)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_text(heading, "title", style.title_size)
	_text(heading, "subtitle", style.body_size)
	close_button = _button(header, "close")
	close_button.pressed.connect(func(): close_requested.emit())
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", style.gap)
	stack.add_child(toolbar)
	_text(toolbar, "seed", style.body_size)
	seed_edit = LineEdit.new()
	seed_edit.max_length = 64 # Technical input limit; not a gameplay value.
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(seed_edit)
	seed_edit.text_submitted.connect(func(value): seed_requested.emit(value))
	apply_button = _button(toolbar, "apply")
	apply_button.pressed.connect(func(): seed_requested.emit(seed_edit.text))
	new_button = _button(toolbar, "new")
	new_button.pressed.connect(func(): new_map_requested.emit())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", style.gap)
	stack.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = style.sidebar_width
	sidebar.add_theme_constant_override("separation", style.gap)
	body.add_child(sidebar)
	_text(sidebar, "legend", style.body_size)
	for kind in style.icons:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", style.gap)
		sidebar.add_child(row)
		var icon := TextureRect.new()
		icon.texture = style.icons[kind]
		icon.custom_minimum_size = Vector2.ONE * style.icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = style.node_colors[kind].lightened(0.3)
		row.add_child(icon)
		_text(row, "kind." + kind, style.body_size)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	details = _plain_label(style.body_size)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = style.sidebar_width
	sidebar.add_child(details)
	stats = _plain_label(style.small_size)
	sidebar.add_child(stats)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	graph = Canvas.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(graph)
	graph.configure(style)
	graph.node_inspected.connect(_inspect)
	notice = _plain_label(style.body_size)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(notice)
	_text(stack, "hint", style.small_size)
	refresh_text()

func _plain_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _text(parent: Node, key: String, font_size: int) -> Label:
	var label := _plain_label(font_size)
	parent.add_child(label)
	_labels[key] = label
	return label

func _button(parent: Node, key: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = style.button_height
	button.add_theme_font_size_override("font_size", style.body_size)
	parent.add_child(button)
	_labels[key] = button
	return button

func show_plan(plan: Dictionary) -> void:
	_plan = plan
	_selected = ""
	_error_key = ""
	seed_edit.text = plan.seed
	graph.show_plan(plan)
	refresh_text()
	_scroll_to_start.call_deferred()

func _scroll_to_start() -> void:
	await get_tree().process_frame
	if is_inside_tree(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func show_error(key: String) -> void:
	_error_key = key
	refresh_text()

func _inspect(id: String) -> void:
	_selected = id
	refresh_text()

func refresh_text() -> void:
	if details == null: return
	for key in _labels: _labels[key].text = tr("map_preview." + key)
	notice.text = tr(_error_key) if not _error_key.is_empty() else tr("map_preview.notice")
	details.text = tr("map_preview.details")
	if not _plan.is_empty():
		stats.text = tr("map_preview.stats").format({"nodes": _plan.nodes.size(), "layers": _plan.rows})
		for node in _plan.nodes:
			if node.id != _selected: continue
			var successors := 0
			for edge in _plan.edges:
				if edge.from == node.id: successors += 1
			details.text = tr("map_preview.selected").format({"layer": node.layer + 1, "kind": tr("map_preview.kind." + node.kind), "id": node.id, "next": successors})
	graph.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: refresh_text()
