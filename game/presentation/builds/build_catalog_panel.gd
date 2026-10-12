extends PopupPanel
signal operation_requested(operation: Dictionary)
const Style = preload("res://presentation/builds/build_ui_style.tres")
var _rows: VBoxContainer
var _filter: OptionButton
var _groups: Dictionary
var _catalog
var _inspect: Callable
var _describe: Callable
func configure(catalog, groups: Dictionary, inspect: Callable, describe: Callable, shared_theme: Theme) -> void:
	_catalog = catalog; _groups = groups; _inspect = inspect; _describe = describe; theme = shared_theme
	var stack := VBoxContainer.new(); add_child(stack)
	_filter = OptionButton.new(); stack.add_child(_filter)
	_filter.item_selected.connect(func(_i): refresh_text())
	var scroll := ScrollContainer.new(); stack.add_child(scroll)
	scroll.custom_minimum_size = Vector2(Style.content_width * 0.7, Style.card_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new(); _rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(_rows)
	about_to_popup.connect(refresh_text)
func refresh_text() -> void:
	var selected := maxi(_filter.selected, 0)
	_filter.clear()
	for rarity in _groups.rarities: _filter.add_item(tr(rarity.name_key))
	_filter.select(selected)
	for child in _rows.get_children(): _rows.remove_child(child); child.queue_free()
	var rarity_id: String = _groups.rarities[selected].id
	for id in _groups.upgrade_groups:
		if _groups.upgrade_groups[id] != rarity_id: continue
		var entry: Dictionary = _catalog.upgrade(id)
		var label := Label.new(); _rows.add_child(label)
		label.text = tr(entry.name_key)
		label.add_theme_color_override("font_color", Style.gold_color)
		for option in _inspect.call(id):
			var operation: Dictionary = option.operation
			var description := Label.new(); _rows.add_child(description)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.text = _describe.call(id, mini(operation.rank, entry.max_rank), operation.action_id)
			var button := Button.new(); _rows.add_child(button)
			button.text = tr("build.action." + operation.action_id) + " · " + tr("build.operation." + operation.operation)
			if not option.ok: button.text += " — " + tr(option.error_key)
			button.disabled = not option.ok
			button.pressed.connect(func(): operation_requested.emit(operation))
