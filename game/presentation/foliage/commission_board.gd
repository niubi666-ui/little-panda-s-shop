extends Control
## Order view within the existing FoliageUI shell. No transactions or new menu framework.
signal selection_changed(id: String)
signal close_requested
const Style = preload("res://presentation/foliage/commission_board_style.tres")
var _canvas: Control
var _cards: Dictionary = {}
var _selected_layers: Dictionary = {}
var _accept: Button
var _notice: Label

func configure(entries: Array, selected_id: String, presentation_theme: Theme) -> void:
	theme = presentation_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.size = Style.design_size
	picture(_canvas, Style.board, Rect2(Vector2.ZERO, Style.design_size))
	text(_canvas, "ui.orders", Style.regions.title, "Title", HORIZONTAL_ALIGNMENT_CENTER)
	text(_canvas, "ui.order_hint", Style.regions.subtitle, "", HORIZONTAL_ALIGNMENT_CENTER)
	var close := Button.new()
	_canvas.add_child(close)
	place(close, Style.regions.close)
	close.text = tr("shop.preview.close")
	close.pressed.connect(func(): close_requested.emit())
	var scroll := ScrollContainer.new()
	_canvas.add_child(scroll)
	place(scroll, Style.regions.cards)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Style.card_gap)
	scroll.add_child(row)
	for entry: Dictionary in entries:
		var holder := Control.new()
		holder.custom_minimum_size = Style.card_size
		row.add_child(holder)
		picture(holder, Style.card, Style.regions.paper)
		var portrait: Texture2D = Style.portraits[entry.id] if Style.portraits.has(entry.id) else load(entry.icon)
		var portrait_view := picture(holder, portrait, Style.regions.portrait)
		var heading := text(holder, entry.name_key, Style.regions.card_title, "PaperHeading", HORIZONTAL_ALIGNMENT_CENTER)
		call_deferred("_fit_portrait_below_heading", heading, portrait_view)
		text(holder, entry.description_key, Style.regions.description, "PaperLabel")
		text(holder, "ui.commission.requirements", Style.regions.requirements, "PaperLabel")
		text(holder, "ui.commission.reward", Style.regions.reward, "PaperLabel")
		var selected := selection_frame(holder, Style.regions.selection)
		_selected_layers[entry.id] = selected
		var card_button := Button.new()
		holder.add_child(card_button)
		place(card_button, Style.regions.paper)
		card_button.name = "Order_" + entry.id
		card_button.tooltip_text = tr(entry.name_key) + " · " + tr("ui.choose_order")
		card_button.toggle_mode = true
		apply_states(card_button)
		card_button.pressed.connect(func(): selection_changed.emit(entry.id))
		card_button.focus_entered.connect(func(): scroll.ensure_control_visible(holder))
		_cards[entry.id] = card_button
	var limit := text(_canvas, "ui.order_limit", Style.regions.limit, "PaperLabel", HORIZONTAL_ALIGNMENT_CENTER)
	limit.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "Muted"))
	_accept = action("AcceptOrder", Style.primary_button, "ui.accept", Style.regions.accept, "ui.commission.accept_pending")
	var depart := action("DepartWithoutOrder", Style.secondary_button, "ui.depart", Style.regions.depart, "ui.commission.depart_pending")
	depart.add_theme_color_override("font_color", theme.get_color("font_color", "PaperLabel"))
	depart.add_theme_color_override("font_hover_color", theme.get_color("font_color", "PaperLabel"))
	depart.add_theme_color_override("font_pressed_color", theme.get_color("font_color", "PaperLabel"))
	_notice = text(_canvas, "ui.commission.preview", Style.regions.notice, "PaperLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_notice.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "Muted"))
	set_selected(selected_id)
	resized.connect(_fit)
	_fit()
	if not _cards.is_empty():
		var focus_id: String = selected_id if _cards.has(selected_id) else _cards.keys()[0]
		_cards[focus_id].grab_focus()

func _fit_portrait_below_heading(heading: Label, portrait: TextureRect) -> void:
	if not is_instance_valid(heading) or not is_instance_valid(portrait):
		return
	var rectangle: Rect2 = Style.regions.portrait
	portrait.position.y = maxf(rectangle.position.y, heading.position.y + heading.size.y + Style.heading_gap)
	portrait.size.y = maxf(0.0, rectangle.end.y - portrait.position.y)

func _fit() -> void:
	var available := size - Style.screen_margin * 2
	var ratio := minf(available.x / Style.design_size.x, available.y / Style.design_size.y)
	_canvas.scale = Vector2.ONE * ratio
	_canvas.position = (size - Style.design_size * ratio) / 2

func place(control: Control, rectangle: Rect2) -> void:
	control.position = rectangle.position
	control.size = rectangle.size

func picture(parent: Node, texture: Texture2D, rectangle: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	place(view, rectangle)
	return view

func text(parent: Node, key: String, rectangle: Rect2, variation: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	place(label, rectangle)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr(key)
	return label

func selection_frame(parent: Node, rectangle: Rect2) -> NinePatchRect:
	# Stretch only transparent middle/straight edges; preserve corners and circular seal.
	var frame := NinePatchRect.new()
	frame.texture = Style.selected
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.patch_margin_left = int(Style.selection_margins.x)
	frame.patch_margin_top = int(Style.selection_margins.y)
	frame.patch_margin_right = int(Style.selection_margins.z)
	frame.patch_margin_bottom = int(Style.selection_margins.w)
	parent.add_child(frame)
	var ratio: float = rectangle.size.x / Style.selected.get_width()
	frame.position = rectangle.position
	frame.scale = Vector2.ONE * ratio
	frame.size = rectangle.size / ratio
	return frame

func apply_states(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", Style.hover_style)
	button.add_theme_stylebox_override("pressed", Style.pressed_style)
	button.add_theme_stylebox_override("hover_pressed", Style.hover_style)
	button.add_theme_stylebox_override("disabled", Style.disabled_style)
	# Keyboard focus uses the same theme focus ring as the other menus.

func action(label: String, texture: Texture2D, key: String, rectangle: Rect2, feedback: String) -> Button:
	picture(_canvas, texture, rectangle)
	var button := Button.new()
	_canvas.add_child(button)
	button.name = label
	place(button, rectangle)
	button.text = tr(key)
	apply_states(button)
	button.pressed.connect(func(): _notice.text = tr(feedback))
	return button

func set_selected(id: String) -> void:
	for card_id: String in _cards:
		_cards[card_id].set_pressed_no_signal(card_id == id)
		_selected_layers[card_id].visible = card_id == id
	_accept.disabled = id.is_empty()
