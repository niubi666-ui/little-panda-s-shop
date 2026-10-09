extends Control
## Display positions are derived; clicking can only inspect a node.
signal node_inspected(id: String)
const VisualLayout = preload("res://presentation/map_preview/map_visual_layout.gd")
var style: Resource
var plan: Dictionary = {}
var positions: Dictionary = {}
var visual_layout: Dictionary = {}
var _layout_plan: Dictionary = {}
var _layout_extent := Vector2.ZERO
var selected := ""
var hovered := ""

func configure(value: Resource) -> void:
	style = value
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	mouse_exited.connect(func(): hovered = ""; queue_redraw())

func show_plan(value: Dictionary) -> void:
	plan = value
	selected = ""
	hovered = ""
	custom_minimum_size = VisualLayout.new().minimum_size(plan, style)
	_layout()
	queue_redraw()

func _layout() -> void:
	if plan.is_empty(): return
	# Containers may not have resolved the requested minimum size yet.
	var extent := Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	if not visual_layout.is_empty() and extent == _layout_extent and plan == _layout_plan: return
	visual_layout = VisualLayout.new().build(plan, style, extent)
	positions = visual_layout.positions
	_layout_extent = extent
	_layout_plan = plan
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next := _at(event.position)
		if next != hovered:
			hovered = next
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hovered.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var id := _at(event.position)
		if not id.is_empty():
			selected = id
			node_inspected.emit(id)
			queue_redraw()
		accept_event()

func _at(point: Vector2) -> String:
	for id in positions:
		if point.distance_to(positions[id]) <= style.node_radius: return id
	return ""

func _draw() -> void:
	if style == null: return
	draw_rect(Rect2(Vector2.ZERO, size), style.paper)
	if plan.is_empty() or visual_layout.is_empty(): return
	var font := get_theme_default_font()
	for layer in int(plan.rows):
		var padding: float = (custom_minimum_size.y - (int(plan.rows) - 1) * style.row_pitch) / 2.0
		var y: float = padding + (int(plan.rows) - 1 - layer) * style.row_pitch
		draw_string(font, Vector2(style.gap, y), "%02d" % (layer + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, style.small_size, style.muted)
	for path in visual_layout.paths:
		_draw_path(path.points, selected in [path.from, path.to] or hovered in [path.from, path.to])
	for node in plan.nodes:
		var point: Vector2 = positions[node.id]
		if node.id == selected or node.id == hovered:
			draw_circle(point, style.node_radius + style.line_width * 2.0, style.accent, false, style.line_width, true)
		draw_circle(point, style.node_radius, style.node_colors[node.kind], true, -1, true)
		var icon_extent: Vector2 = Vector2.ONE * style.icon_size
		draw_texture_rect(style.icons[node.kind], Rect2(point - icon_extent / 2.0, icon_extent), false)
		var caption := tr("map_preview.kind." + node.kind)
		var caption_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_font_size)
		var caption_origin: Vector2 = point + Vector2(-caption_size.x / 2.0, style.node_radius)
		draw_rect(Rect2(caption_origin, Vector2(caption_size.x, style.node_font_size + style.line_width)), style.paper)
		_center_text(font, caption, point + Vector2(0, style.node_radius + style.node_font_size), style.node_font_size, style.ink)
	draw_circle(visual_layout.start, style.marker_radius, style.accent, true, -1, true)
	draw_circle(visual_layout.end, style.marker_radius, style.accent, true, -1, true)
	_center_text(font, tr("map_preview.start"), visual_layout.start + Vector2(0, style.small_size + style.marker_radius), style.small_size, style.ink)
	_center_text(font, tr("map_preview.end"), visual_layout.end - Vector2(0, style.gap), style.small_size, style.ink)

func _draw_path(points: PackedVector2Array, active: bool) -> void:
	if active:
		draw_polyline(points, style.accent, style.line_width * 2.0, true)
		return
	var distance := 0.0
	var period: float = style.path_dash_length + style.path_dash_gap
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var travelled := 0.0
		while travelled < length:
			var phase := fposmod(distance + travelled, period)
			var ink: bool = phase < style.path_dash_length
			var step := minf(length - travelled, (style.path_dash_length if ink else period) - phase)
			# Floating-point boundary guard for the dash phase.
			if step < 0.0001:
				travelled += 0.0001
				continue
			if ink: draw_line(a.lerp(b, travelled / length), a.lerp(b, (travelled + step) / length), style.line_color, style.line_width, true)
			travelled += step
		distance += length

func _center_text(font: Font, text: String, point: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, point - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: queue_redraw()
