extends Control
## Read-only sample inventory view. Requests stay local; the shell owns UI selection.
signal category_requested(category: String)
signal selection_changed(id: String)
signal sort_requested
signal close_requested

var _entries: Array
var _category: String
var _selected: String
var _skin: Resource
var _grid: GridContainer
var _cards: Array[Button] = []
var _rings: Dictionary = {}
var _detail_image: TextureRect
var _detail_name: Label
var _description: Label

func configure(entries: Array, category: String, selected_id: String, shared_theme: Theme, appearance: Resource) -> void:
	_entries = entries
	_category = category
	_selected = selected_id
	_skin = appearance
	theme = shared_theme
	name = "InventoryPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	set_selected(selected_id)

func metric(key: String) -> float:
	return float(_skin.metrics[key])

func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(metric("gap")))
	parent.add_child(column)
	return column

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(metric("gap")))
	parent.add_child(row)
	return row

func _inset(parent: Node, padding: float) -> MarginContainer:
	var inset := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, int(padding))
	parent.add_child(inset)
	return inset

func _label(parent: Node, key: String, variation: String = "") -> Label:
	var label := Label.new()
	label.text = tr(key) if not key.is_empty() else ""
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", _skin.muted_color if variation == "Muted" else _skin.text_color)
	parent.add_child(label)
	return label

func _texture(parent: Node, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _panel(parent: Node, style: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skin.styles[style])
	parent.add_child(panel)
	return panel

func _button(parent: Node, key: String, style: String, icon_key: String = "") -> Button:
	var button := Button.new()
	button.text = tr(key) if not key.is_empty() else ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_force_pass_scroll_events = false
	button.add_theme_stylebox_override("normal", _skin.styles[style])
	for state in ["hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _skin.styles[style + "_" + state])
	button.add_theme_stylebox_override("hover_pressed", _skin.styles[style + "_pressed"])
	button.add_theme_stylebox_override("focus", _skin.styles["focus"])
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, _skin.text_color)
	button.add_theme_color_override("font_disabled_color", _skin.disabled_color)
	if not icon_key.is_empty():
		button.icon = _skin.icons[icon_key]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(metric("icon_size")))
	parent.add_child(button)
	return button

func _build() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := _panel(center, "window")
	frame.name = "InventoryFrame"
	frame.custom_minimum_size = Vector2(metric("window_width"), metric("window_height"))
	var body := _column(_inset(frame, metric("padding")))
	var header_inset := _inset(body, 0.0)
	header_inset.add_theme_constant_override("margin_left", int(metric("header_inset")))
	var header := _row(header_inset)
	header.custom_minimum_size.y = metric("header_height")
	var bag := _texture(header, _skin.icons["title_bag"])
	bag.custom_minimum_size = Vector2.ONE * metric("title_icon")
	var title := _label(header, "ui.inventory", "Title")
	title.name = "InventoryTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sprig := _texture(header, _skin.textures["leaf"])
	sprig.custom_minimum_size = Vector2(metric("leaf_width"), metric("leaf_height"))
	var close := _button(header, "", "close", "close")
	close.name = "InventoryClose"
	close.custom_minimum_size = Vector2.ONE * metric("close_size")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.tooltip_text = tr("shop.preview.close")
	close.pressed.connect(func(): close_requested.emit())
	var content := _row(body)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := _column(content)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_catalog(left)
	_build_details(content)
	var notice_inset := _inset(body, 0.0)
	notice_inset.add_theme_constant_override("margin_left", int(metric("notice_inset")))
	var notice := _label(notice_inset, "ui.sample_note", "Muted")
	notice.name = "InventoryNotice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_catalog(parent: Node) -> void:
	var tabs := _row(parent)
	for category: String in ["all", "equipment", "potions", "materials"]:
		var tab := _button(tabs, "ui." + category, "tab")
		tab.name = "Category_" + category
		tab.toggle_mode = true
		tab.button_pressed = category == _category
		tab.add_theme_stylebox_override("pressed", _skin.styles["tab_selected"])
		tab.add_theme_stylebox_override("hover_pressed", _skin.styles["tab_selected"])
		tab.custom_minimum_size.y = metric("tab_height")
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func(): category_requested.emit(category))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "InventoryGrid"
	_grid.columns = int(metric("columns"))
	_grid.add_theme_constant_override("h_separation", int(metric("grid_gap")))
	_grid.add_theme_constant_override("v_separation", int(metric("grid_gap")))
	center.add_child(_grid)
	for entry: Dictionary in _entries:
		if _category != "all" and entry.category != _category:
			continue
		var card := _button(_grid, "", "slot")
		card.name = "Item_" + entry.id
		card.set_meta("entry_id", entry.id)
		card.tooltip_text = tr(entry.name_key)
		card.custom_minimum_size = Vector2.ONE * metric("slot_size")
		card.toggle_mode = true
		var icon := _texture(card, _skin.items[entry.id])
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.position = -Vector2.ONE * metric("slot_icon") / 2.0
		icon.size = Vector2.ONE * metric("slot_icon")
		var ring := _panel(card, "selection")
		ring.name = "SelectionRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rings[entry.id] = ring
		_cards.append(card)
		card.pressed.connect(func():
			selection_changed.emit(entry.id)
			_sync_cards()
		)
	# These empty cells illustrate the skin, never player capacity or owned quantity.
	if _category == "all":
		for index in range(int(metric("columns") * metric("rows")) - _cards.size()):
			var empty := _button(_grid, "", "slot", "empty_slot_mark")
			empty.name = "EmptySlot_" + str(index)
			empty.custom_minimum_size = Vector2.ONE * metric("slot_size")
			empty.tooltip_text = tr("ui.empty")
			empty.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.disabled = true
	var sort_button := _button(parent, "ui.sort", "secondary", "action_sort")
	sort_button.name = "InventorySort"
	sort_button.custom_minimum_size = Vector2(metric("sort_width"), metric("button_height"))
	sort_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	sort_button.pressed.connect(func(): sort_requested.emit())

func _build_details(parent: Node) -> void:
	var paper := _panel(parent, "paper")
	paper.name = "InventoryDetails"
	paper.custom_minimum_size.x = metric("detail_width")
	var column := _column(_inset(paper, metric("detail_padding")))
	var heading := _row(column)
	_detail_image = _texture(heading, null)
	_detail_image.custom_minimum_size = Vector2.ONE * metric("detail_icon")
	_detail_name = _label(heading, "", "PaperHeading")
	_detail_name.name = "InventoryName"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_name.add_theme_color_override("font_color", _skin.paper_color)
	_description = _label(column, "", "PaperLabel")
	_description.name = "InventoryDescription"
	_description.add_theme_color_override("font_color", _skin.paper_color)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var divider := _texture(column, _skin.icons["divider_ink"])
	divider.custom_minimum_size.y = metric("gap")
	for action: String in ["use", "store"]:
		var button := _button(column, "ui." + action, "primary" if action == "use" else "secondary", "action_" + action)
		button.name = "InventoryUse" if action == "use" else "InventoryStore"
		button.custom_minimum_size.y = metric("button_height")
		button.disabled = true
		button.tooltip_text = tr("ui.unavailable")
	var unavailable := _label(column, "ui.unavailable", "Muted")
	unavailable.add_theme_color_override("font_color", _skin.paper_color)
	unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_selected(id: String) -> void:
	_selected = id
	_sync_cards()
	for entry: Dictionary in _entries:
		if entry.id == id:
			_detail_image.texture = _skin.items[id]
			_detail_name.text = tr(entry.name_key)
			_description.text = tr(entry.description_key)
			return
	_detail_image.texture = null
	_detail_name.text = tr("ui.select_item")
	_description.text = ""

func _sync_cards() -> void:
	for card in _cards:
		var id: String = card.get_meta("entry_id")
		card.set_pressed_no_signal(id == _selected)
		_rings[id].visible = id == _selected

func sort_visible() -> void:
	_cards.sort_custom(func(a: Button, b: Button): return a.tooltip_text.naturalnocasecmp_to(b.tooltip_text) < 0)
	for index in range(_cards.size()):
		_grid.move_child(_cards[index], index)
