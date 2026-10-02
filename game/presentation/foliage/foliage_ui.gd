extends Control
## A presentation-only sample catalog. It cannot mutate inventory, orders or layouts.
signal modal_changed(open: bool)
signal settings_requested
const CommissionBoard = preload("res://presentation/foliage/commission_board.gd")
var _commission
const InventoryPanel = preload("res://presentation/inventory/inventory_panel.gd")
const InventoryAppearance = preload("res://presentation/inventory/inventory_ui_skin.tres")
const InventoryThemeFactory = preload("res://presentation/inventory/inventory_theme_factory.gd")
var _inventory_panel: InventoryPanel
var _inventory_skin: Resource
const Catalog = preload("res://content/shop_preview/foliage_preview_definition.gd")
var _catalog: Catalog
var _mode := ""
var _category := "all"
var _selected := ""
var _window: Control
var _body: VBoxContainer
var _detail: VBoxContainer
var _grid: GridContainer
var _cards: Array[Button] = []
var _notice: Label
var _ready_for_text := false
var _rebuild_pending := false
var _world_dialog_open: Callable
var _decoration_open: Callable
var _decorating := false

func configure(catalog: Catalog, world_dialog_open: Callable, presentation_theme: Theme) -> void:
	_catalog = catalog
	_world_dialog_open = world_dialog_open
	theme = presentation_theme
	_inventory_skin = InventoryThemeFactory.prepare(InventoryAppearance)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ready_for_text = true
	_rebuild()
	resized.connect(_schedule_rebuild)

func metric(key: String) -> int:
	assert(theme.has_constant(key, &"Foliage"))
	return theme.get_constant(key, &"Foliage")

func message(key: String) -> String:
	var text := str(TranslationServer.translate(key))
	var bindings := {"ui.key_inventory":"ui_inventory", "ui.key_orders":"ui_orders", "ui.key_decoration":"ui_decoration", "ui.key_settings":"ui_cancel"}
	if bindings.has(key):
		return text.format({"key": key_label(bindings[key])})
	return text

func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	push_error("Foliage UI missing input binding: " + action)
	return action

func controls_text() -> String:
	var keys: PackedStringArray = []
	for action: String in ["move_forward", "move_left", "move_back", "move_right"]:
		keys.append(key_label(action))
	return message("shop.preview.controls").format({"move_keys":"/".join(keys), "interact_key":key_label("interact")})

func label(parent: Node, key: String, variation: String = "") -> Label:
	var node := Label.new()
	node.text = message(key)
	node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func icon(parent: Node, path: String, extent: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2.ONE * extent
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, key: String, callback: Callable, art: String = "") -> Button:
	var node := Button.new()
	node.text = message(key)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not art.is_empty():
		node.icon = load("res://assets/ui/foliage/" + art + ".svg")
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", metric("icon") / 2)
		node.custom_minimum_size.x = node.get_minimum_size().x + metric("icon") / 2
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func panel(parent: Node, paper: bool = false) -> PanelContainer:
	var node := PanelContainer.new()
	if paper:
		node.theme_type_variation = &"Paper"
	parent.add_child(node)
	return node

func column(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	parent.add_child(node)
	return node

func row(parent: Node) -> HBoxContainer:
	var node := HBoxContainer.new()
	parent.add_child(node)
	return node

func ornament(parent: Control, flip: bool = false) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	var leaf := icon(overlay, "res://assets/ui/foliage/corner.svg", metric("corner_size"))
	leaf.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if flip else Control.PRESET_TOP_LEFT)
	leaf.flip_h = flip
	leaf.modulate.a = 0.78

func _rebuild() -> void:
	_rebuild_pending = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cards.clear()
	_commission = null
	_inventory_panel = null
	var header := MarginContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		header.add_theme_constant_override("margin_" + side, metric("margin"))
	var top := row(header)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var identity := panel(top)
	var identity_row := row(identity)
	icon(identity_row, "res://assets/ui/foliage/leaf.svg", metric("icon"))
	var identity_text := column(identity_row)
	label(identity_text, "shop.preview.title", "Title")
	label(identity_text, "ui.location", "Muted")
	ornament(identity)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(space)
	var currency := panel(top)
	var currency_row := row(currency)
	icon(currency_row, "res://assets/ui/foliage/coin.svg", metric("icon") / 2)
	label(currency_row, "ui.no_balance")
	button(top, "ui.language_toggle", _toggle_language)
	var footer := MarginContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -metric("footer_height")
	for side in ["left", "right", "bottom"]:
		footer.add_theme_constant_override("margin_" + side, metric("margin"))
	var bottom := row(footer)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_box := column(bottom)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(hint_box, "ui.status", "Muted")
	var controls := label(hint_box, "shop.preview.controls", "Muted")
	controls.text = controls_text()
	for entry in [["inventory", "bag"], ["orders", "scroll"], ["decoration", "cabinet"], ["settings", "settings"]]:
		var entry_mode: String = entry[0]
		var shortcut := button(bottom, "ui.key_" + entry_mode, open_page.bind(entry_mode))
		shortcut.text = "\n" + shortcut.text
		shortcut.custom_minimum_size.y = metric("footer_height") - metric("margin")
		var shortcut_icon := icon(shortcut, "res://assets/ui/foliage/"+entry[1]+".svg", metric("icon") / 2)
		shortcut_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		shortcut_icon.offset_left = -metric("icon") / 4
		shortcut_icon.offset_right = metric("icon") / 4
		shortcut_icon.position.y = metric("margin") / 2
	if _mode.is_empty():
		return
	_window = Control.new()
	_window.name = "FoliageModal"
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.mouse_force_pass_scroll_events = false
	add_child(_window)
	_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.012,0.023,0.017,0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _mode == "inventory":
		dim.color = _inventory_skin.dim_color
		_inventory_panel = InventoryPanel.new()
		_window.add_child(_inventory_panel)
		_inventory_panel.category_requested.connect(filter_category)
		_inventory_panel.selection_changed.connect(select_entry)
		_inventory_panel.sort_requested.connect(_sort_catalog)
		_inventory_panel.close_requested.connect(close_page)
		_inventory_panel.configure(_catalog.entries("inventory"), _category, _selected, theme, _inventory_skin)
		return
	if _mode == "orders":
		_commission = CommissionBoard.new()
		_window.add_child(_commission)
		_commission.selection_changed.connect(select_order)
		_commission.close_requested.connect(close_page)
		_commission.configure(_catalog.entries("orders"), _selected, theme)
		return
	var frame: PanelContainer
	if _mode == "decoration":
		dim.color.a = 0.15
		var side := MarginContainer.new()
		_window.add_child(side)
		side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		side.offset_left = metric("margin")
		side.offset_top = metric("margin")
		side.offset_right = metric("sidebar_width") + metric("margin")
		side.offset_bottom = -metric("margin")
		frame = panel(side)
	else:
		var center := CenterContainer.new()
		_window.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame = panel(center)
		frame.custom_minimum_size = Vector2(minf(metric("window_width"), size.x - metric("margin") * 2), minf(metric("window_height"), size.y - metric("margin") * 2))
	_body = column(frame)
	var heading := row(_body)
	icon(heading, "res://assets/ui/foliage/leaf.svg", metric("icon") / 2)
	var title := label(heading, "ui." + _mode, "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(heading, "shop.preview.close", close_page).text = message("shop.preview.close") + "  ×"
	if _mode != "settings":
		label(_body, "ui.preview", "Muted")
	_body.add_child(HSeparator.new())
	match _mode:
		"decoration": _decoration()
	_notice = label(_body, "ui.place_note" if _mode == "decoration" else "ui.settings_note", "Muted")
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ornament(frame, true)

func _fill_grid(section: String) -> void:
	for entry: Dictionary in _catalog.entries(section):
		if _category != "all" and entry.category != _category:
			continue
		var item := button(_grid, entry.name_key, select_entry.bind(entry.id))
		item.name = "Item_" + entry.id
		item.custom_minimum_size = Vector2.ONE * metric("slot")
		item.text = ""
		item.icon = load(entry.icon)
		item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.expand_icon = true
		item.add_theme_constant_override("icon_max_width", metric("icon"))
		item.tooltip_text = message(entry.name_key)
		item.toggle_mode = true
		item.button_pressed = entry.id == _selected
		item.set_meta("entry_id", entry.id)
		if section == "decoration":
			item.text = message(entry.name_key)
			item.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			item.add_theme_constant_override("icon_max_width", metric("catalog_icon"))
			item.theme_type_variation = &"CatalogButton"
		_cards.append(item)

func _update_detail(section: String) -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	for entry: Dictionary in _catalog.entries(section):
		if entry.id != _selected:
			continue
		var title := label(_detail, entry.name_key, "PaperHeading")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := label(_detail, entry.description_key, "PaperLabel")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var unavailable := button(_detail, "ui.place", func(): pass)
		unavailable.disabled = true
		unavailable.tooltip_text = message("ui.unavailable")
		return
	label(_detail, "ui.select_item", "PaperLabel")

func _decoration() -> void:
	var categories := OptionButton.new()
	_body.add_child(categories)
	var category_ids: Array[String] = ["all", "furniture", "ornaments", "lights"]
	for category: String in ["all", "furniture", "ornaments", "lights"]:
		categories.add_item(message("ui." + category))
	categories.select(category_ids.find(_category))
	categories.item_selected.connect(func(index: int): filter_category(category_ids[index]))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = metric("decoration_columns")
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	_fill_grid("decoration")
	for card in _cards:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := panel(_body, true)
	_detail = column(details)
	_update_detail("decoration")
	button(_body, "ui.done", close_page, "leaf")

func attach_decoration(open_request: Callable) -> void:
	_decoration_open = open_request

func set_decoration_active(active: bool) -> void:
	_decorating = active
	visible = not active
	set_process_unhandled_input(not active)

func open_page(mode: String) -> void:
	if mode == "settings":
		if _world_dialog_open.call(): return
		if not _mode.is_empty(): close_page()
		settings_requested.emit()
		return
	if mode == "decoration" and _decoration_open.is_valid():
		if _world_dialog_open.call(): return
		if not _mode.is_empty(): close_page()
		_decoration_open.call()
		return
	if mode not in ["inventory", "orders", "decoration", "settings"]:
		return
	_mode = mode
	_category = "all"
	_selected = "" if mode in ["settings", "orders"] else str(_catalog.entries(mode)[0].id)
	modal_changed.emit(true)
	_rebuild()

func close_page() -> void:
	_mode = ""
	modal_changed.emit(false)
	_rebuild()

func filter_category(category: String) -> void:
	_category = category
	_selected = ""
	for entry: Dictionary in _catalog.entries(_mode):
		if category == "all" or entry.category == category:
			_selected = entry.id
			break
	_rebuild()

func select_entry(id: String) -> void:
	_selected = id
	if _mode == "inventory" and is_instance_valid(_inventory_panel):
		_inventory_panel.set_selected(id)
		return
	for card in _cards:
		card.button_pressed = card.get_meta("entry_id") == id
	_update_detail(_mode)

func select_order(id: String) -> void:
	_selected = "" if _selected == id else id
	if is_instance_valid(_commission):
		_commission.set_selected(_selected)

func _sort_catalog() -> void:
	if is_instance_valid(_inventory_panel):
		_inventory_panel.sort_visible()

func _toggle_language() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")

func current_page() -> String:
	return _mode

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for mode: String in ["inventory", "orders", "decoration"]:
		if event.is_action_pressed("ui_" + mode):
			if _mode == mode:
				close_page()
			else:
				open_page(mode)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if _mode.is_empty() and _world_dialog_open.call():
			return
		if _mode.is_empty():
			open_page("settings")
		else:
			close_page()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _ready_for_text:
		_schedule_rebuild()

func _schedule_rebuild() -> void:
	if _ready_for_text and not _rebuild_pending:
		_rebuild_pending = true
		call_deferred("_rebuild")

func is_modal_open() -> bool:
	return _decorating or not _mode.is_empty()
