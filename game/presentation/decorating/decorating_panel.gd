extends Control
## Presentation-only catalog. All selection and layout authority is injected by the app.
signal furniture_chosen(id: String)
signal rotate_requested
signal remove_requested
signal cancel_requested
signal done_requested
const Catalog = preload("res://content/decorating/decorating_catalog.gd")
const SkinFactory = preload("res://presentation/decorating/decorating_theme_factory.gd")
var _catalog: Catalog
var _skin: Resource
var _text_nodes: Dictionary = {}
var _cards: Dictionary = {}
var _tabs: Dictionary = {}
var _selected_id := ""
var _category := "furniture"
var _status: Label
var _count: Label
var _rotate: Button
var _remove: Button
var _cancel: Button
var _done: Button
var _sidebar: PanelContainer
var _banner: PanelContainer
var _note: Label
var _language: Button
var _actions: HBoxContainer
var _feedback: PanelContainer
var _help: Label
var _grid: GridContainer
var _empty: Label
var _detail_name: Label
var _detail_footprint: Label
var _detail_description: Label
var _detail_image: TextureRect
var _leaf: TextureRect
var _last_status := "idle"
var _last_count := 0
var _moving := false
var _configured := false

func configure(catalog: Catalog, settings, shared_theme: Theme) -> void:
	_catalog = catalog
	_skin = SkinFactory.prepare(settings.ui_skin)
	theme = shared_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_catalog()
	_build_scene_controls()
	_configured = true
	resized.connect(_layout)
	_layout()
	refresh(false, false, "idle", 0)
	set_selection("")

func metric(key: String) -> float:
	return float(_skin.metrics[key])

func _panel(parent: Node, style: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skin.style_boxes[style])
	parent.add_child(panel)
	return panel

func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(metric("gap")))
	parent.add_child(column)
	return column

func _label(parent: Node, key: String, variation: String = "") -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _skin.muted_color if variation == "Muted" else _skin.text_color)
	parent.add_child(label)
	if not key.is_empty(): _text_nodes[label] = key
	return label

func _texture(parent: Node, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(image)
	return image

func _button(parent: Node, key: String, style: String, icon: String = "") -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _skin.style_boxes[style])
	button.add_theme_stylebox_override("hover", _skin.style_boxes["button_hover"])
	button.add_theme_stylebox_override("pressed", _skin.style_boxes["button_pressed"])
	button.add_theme_stylebox_override("disabled", _skin.style_boxes["button_disabled"])
	button.add_theme_stylebox_override("focus", _skin.style_boxes["slot_focus"])
	button.add_theme_color_override("font_color", _skin.text_color)
	button.add_theme_color_override("font_hover_color", _skin.text_color)
	button.add_theme_color_override("font_pressed_color", _skin.text_color)
	if not icon.is_empty():
		button.icon = _skin.icons[icon]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(metric("icon_size")))
	parent.add_child(button)
	if not key.is_empty(): _text_nodes[button] = key
	return button

func _build_catalog() -> void:
	_sidebar = _panel(self, "panel")
	_sidebar.name = "CatalogPanel"
	var inset := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, int(metric("padding")))
	_sidebar.add_child(inset)
	var column := _column(inset)
	_label(column, "decor.title", "Title")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(metric("gap")))
	column.add_child(tabs)
	for category: String in ["furniture", "ornaments", "lights"]:
		var tab := _button(tabs, "decor.category." + category, "tab")
		tab.name = "Category_" + category
		tab.theme_type_variation = "CatalogButton"
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = metric("tab_height")
		tab.add_theme_stylebox_override("hover", _skin.style_boxes["tab_hover"])
		tab.add_theme_stylebox_override("pressed", _skin.style_boxes["tab_selected"])
		tab.pressed.connect(func(): _choose_category(category))
		_tabs[category] = tab
	var scroll := ScrollContainer.new()
	scroll.name = "CatalogScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := _column(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.name = "CatalogGrid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(metric("gap")))
	_grid.add_theme_constant_override("v_separation", int(metric("gap")))
	content.add_child(_grid)
	for furniture in _catalog.entries(): _create_card(furniture)
	_empty = _label(content, "decor.empty", "Muted")
	_empty.name = "EmptyState"
	_empty.hide()
	_count = _label(column, "", "Muted")
	var detail := _panel(column, "slot")
	detail.name = "SelectionDetail"
	detail.custom_minimum_size.y = metric("detail_height")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(metric("gap")))
	detail.add_child(row)
	_detail_image = _texture(row, _skin.textures["barrel"])
	_detail_image.custom_minimum_size = Vector2.ONE * metric("detail_icon_size")
	var info := _column(row)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_name = _label(info, "")
	_detail_name.name = "DetailName"
	_detail_footprint = _label(info, "", "Muted")
	_detail_footprint.name = "DetailFootprint"
	_detail_description = _label(info, "", "Muted")
	_detail_description.name = "DetailDescription"
	_detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choose_category("furniture")

func _create_card(furniture: Catalog.Furniture) -> void:
	var id := furniture.id
	var card := _button(_grid, "", "slot")
	card.name = "CatalogCard_" + id
	card.toggle_mode = true
	card.custom_minimum_size.y = metric("card_height")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("hover", _skin.style_boxes["slot_hover"])
	card.add_theme_stylebox_override("pressed", _skin.style_boxes["slot_hover"])
	var column := _column(card)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = metric("thumbnail_padding")
	column.offset_right = -metric("thumbnail_padding")
	column.offset_top = metric("thumbnail_padding")
	column.offset_bottom = -metric("thumbnail_padding")
	column.add_theme_constant_override("separation", 0)
	var thumbnail := _texture(column, _skin.textures[id])
	thumbnail.custom_minimum_size.y = metric("card_icon_height")
	thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := _label(column, furniture.name_key, "Muted")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", _skin.text_color)
	var selected := _texture(card, _skin.textures["selected"])
	selected.name = "SelectionRing"
	selected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selected.stretch_mode = TextureRect.STRETCH_SCALE
	selected.hide()
	card.pressed.connect(func():
		# App confirms which item is being previewed, including selection from the world.
		furniture_chosen.emit(id)
		_sync_card_states()
	)
	_cards[id] = card

func _build_scene_controls() -> void:
	_banner = _panel(self, "tab")
	_banner.name = "ModeBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var banner_art := _texture(_banner, _skin.textures["banner"])
	banner_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading := _label(_banner, "decor.mode", "Title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note = _label(self, "decor.note", "Muted")
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_language = _button(self, "ui.language_toggle", "tab")
	_language.name = "LanguageButton"
	_language.theme_type_variation = "CatalogButton"
	_language.pressed.connect(func(): TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN"))
	_feedback = _panel(self, "tab")
	_feedback.name = "PlacementFeedback"
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feedback := _column(_feedback)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = _label(feedback, "")
	_status.name = "StatusLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help = _label(feedback, "", "Muted")
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions = HBoxContainer.new()
	_actions.name = "ActionBar"
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_theme_constant_override("separation", int(metric("gap")))
	add_child(_actions)
	_rotate = _button(_actions, "decor.rotate", "secondary", "rotate")
	_rotate.name = "RotateButton"
	_rotate.pressed.connect(func(): rotate_requested.emit())
	_cancel = _button(_actions, "decor.cancel", "secondary", "cancel")
	_cancel.name = "CancelButton"
	_cancel.pressed.connect(func(): cancel_requested.emit())
	_remove = _button(_actions, "decor.remove", "secondary", "remove")
	_remove.name = "RemoveButton"
	_remove.pressed.connect(func(): remove_requested.emit())
	_done = _button(_actions, "decor.done", "primary", "done")
	_done.name = "DoneButton"
	_done.pressed.connect(func(): done_requested.emit())
	for button: Button in [_rotate, _cancel, _remove, _done]:
		button.theme_type_variation = "CatalogButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = metric("button_height")
	_leaf = _texture(self, _skin.textures["leaf"])
	_leaf.name = "LeafOrnament"
	_leaf.flip_h = true

func _layout() -> void:
	if not _configured: return
	var margin := metric("margin")
	var left := margin + metric("sidebar_width") + metric("gap")
	var width := size.x - left - margin
	_sidebar.position = Vector2.ONE * margin
	_sidebar.size = Vector2(metric("sidebar_width"), size.y - margin * 2.0)
	_banner.position = Vector2(left + (width - metric("banner_width")) / 2.0, margin)
	_banner.size = Vector2(metric("banner_width"), metric("header_height"))
	_note.position = Vector2(left, margin + metric("header_height") + metric("gap"))
	_note.size = Vector2(width, metric("status_height"))
	_language.position = Vector2(size.x - margin - metric("detail_icon_size"), margin)
	_language.size = Vector2(metric("detail_icon_size"), metric("tab_height"))
	_actions.position = Vector2(left, size.y - margin - metric("bar_height"))
	_actions.size = Vector2(width, metric("bar_height"))
	_feedback.position = Vector2(left, _actions.position.y - metric("gap") - metric("status_height"))
	_feedback.size = Vector2(width, metric("status_height"))
	_leaf.position = Vector2(size.x - metric("leaf_size"), size.y - metric("leaf_size"))
	_leaf.size = Vector2.ONE * metric("leaf_size")

func _choose_category(category: String) -> void:
	_category = category
	for id in _tabs: _tabs[id].set_pressed_no_signal(id == category)
	_grid.visible = category == "furniture"
	_empty.visible = category != "furniture"

func set_selection(id: String) -> void:
	assert(id.is_empty() or _catalog.has_id(id), "Decoration selection must be an existing definition")
	if id == _selected_id: return
	_selected_id = id
	if not id.is_empty(): _choose_category("furniture")
	_sync_card_states()
	if _configured: _refresh_text()

func _sync_card_states() -> void:
	for id in _cards:
		_cards[id].set_pressed_no_signal(id == _selected_id)
		_cards[id].get_node("SelectionRing").visible = id == _selected_id

func refresh(pending: bool, moving: bool, code: String, count: int) -> void:
	_rotate.disabled = not pending
	_remove.disabled = not moving
	_cancel.disabled = not pending
	_moving = moving
	_last_status = code
	_last_count = count
	_refresh_text()

func _key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	push_error("Decoration UI has no key binding: " + action)
	return ""

func _refresh_text() -> void:
	for node in _text_nodes: node.text = tr(_text_nodes[node])
	_status.text = tr("decor." + _last_status)
	_status.add_theme_color_override("font_color", _skin.valid_color if _last_status in ["ok", "applied", "removed"] else _skin.text_color if _last_status == "idle" else _skin.invalid_color)
	_help.text = tr("decor.help").format({"cancel_key":_key_label(&"ui_cancel"), "mode_key":_key_label(&"ui_decoration")})
	_count.text = tr("decor.count").format({"count":_last_count, "limit":_catalog.maximum_instances(), "grid":_catalog.grid_size()})
	_detail_image.visible = not _selected_id.is_empty()
	if _selected_id.is_empty():
		_detail_name.text = tr("decor.detail.empty_title")
		_detail_footprint.text = ""
		_detail_description.text = tr("decor.detail.empty")
	else:
		var furniture := _catalog.furniture(_selected_id)
		_detail_image.texture = _skin.textures[_selected_id]
		_detail_name.text = tr(furniture.name_key)
		_detail_footprint.text = tr("decor.footprint").format({"width":furniture.footprint.x, "depth":furniture.footprint.y})
		_detail_description.text = tr("decor.description." + _selected_id)
	for id in _cards: _cards[id].tooltip_text = tr(_catalog.furniture(id).name_key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _configured: _refresh_text()
