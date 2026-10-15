extends Control
## 一局冒险的界面：屏幕上方的房间信息条；清场后“选择下一个房间”的出口卡片；通关/倒下的结算。
## 只显示和发请求，不改任何状态。
const Style = preload("res://presentation/run/run_exit_style.gd")

signal exit_chosen(index: int)
signal new_run_requested
signal shop_requested

var style: Style
var _theme: Theme
var _info: Label
var _overlay: Control
var _font: Font

func configure(settings: Style, theme: Theme) -> void:
	assert(settings != null and settings.element_style != null, "run exit style incomplete")
	style = settings
	_theme = theme
	_font = theme.default_font if theme != null else null
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = Label.new()
	_info.theme = theme
	_info.add_theme_font_size_override("font_size", style.info_font_size)
	_info.add_theme_color_override("font_color", style.info_color)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_info.position.y = style.info_top_margin
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)

func set_info(text: String) -> void:
	_info.text = text
	_info.reset_size()
	_info.position.x = (size.x - _info.size.x) / 2.0

func is_open() -> bool:
	return is_instance_valid(_overlay)

## options：[{kind, element, title, detail}]
func show_exits(title: String, options: Array) -> void:
	_open_overlay()
	var column := _column(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(style.card_gap))
	column.add_child(row)
	for index in options.size():
		row.add_child(_card(options[index], index))

func show_result(title: String, body: String) -> void:
	_open_overlay()
	var column := _column(title)
	var text := Label.new()
	text.theme = _theme
	text.text = body
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", style.card_title_font_size)
	text.add_theme_color_override("font_color", style.text_color)
	column.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(style.card_gap))
	column.add_child(row)
	for pair in [["run.button.new_run", new_run_requested], ["run.button.shop", shop_requested]]:
		var button := Button.new()
		button.name = "RunResult_" + String(pair[0]).get_slice(".", 2)
		button.theme = _theme
		button.text = tr(pair[0])
		button.custom_minimum_size = Vector2(style.card_size.x * 0.8, 56)
		var signal_ref: Signal = pair[1]
		button.pressed.connect(func(): signal_ref.emit())
		row.add_child(button)

func close() -> void:
	if is_instance_valid(_overlay): _overlay.queue_free()
	_overlay = null

func _open_overlay() -> void:
	close()
	_overlay = ColorRect.new()
	_overlay.name = "RunOverlay"
	_overlay.color = style.dim_color
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

func _column(title: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(style.card_gap))
	center.add_child(column)
	var heading := Label.new()
	heading.theme = _theme
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", style.title_font_size)
	heading.add_theme_color_override("font_color", style.text_color)
	column.add_child(heading)
	return column

func _card(option: Dictionary, index: int) -> Button:
	var color := _color(option)
	var button := Button.new()
	button.name = "RunExit_%d" % index
	button.custom_minimum_size = style.card_size
	button.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = style.card_back.lerp(color, 0.25 if state == "normal" else 0.45)
		box.set_corner_radius_all(style.card_radius)
		box.set_border_width_all(style.card_border + (2 if state != "normal" else 0))
		box.border_color = color
		button.add_theme_stylebox_override(state, box)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(layout)
	for part in [[option.title, style.card_title_font_size, color.lerp(Color.WHITE, 0.35)], [option.detail, style.card_detail_font_size, style.detail_color]]:
		var label := Label.new()
		label.theme = _theme
		label.text = part[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = style.card_size.x - 24
		label.add_theme_font_size_override("font_size", part[1])
		label.add_theme_color_override("font_color", part[2])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(label)
	button.pressed.connect(func(): exit_chosen.emit(index))
	return button

func _color(option: Dictionary) -> Color:
	if option.kind == "boon":
		return style.element_style.element_colors.get(option.element, Color.WHITE)
	return style.reward_colors.get(option.kind, Color.WHITE)
