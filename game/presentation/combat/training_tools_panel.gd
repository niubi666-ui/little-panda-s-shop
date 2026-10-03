extends Control
## Training UI emits requests; the application owns state and applies commands.
signal player_invincibility_changed(enabled: bool)
signal enemy_invincibility_changed(enabled: bool)
signal add_wave_requested
signal heal_requested
signal ranger_requested
signal visibility_requested(id: String, shown: bool)

const Appearance = preload("res://presentation/combat/training_tools_style.tres")
const PANEL_IDS = ["build", "depth", "fx", "room", "hud"]
# Reserved popup action IDs, separate from the panel index IDs.
const SHOW_ALL_ID = 100
const HIDE_ALL_ID = 101

var _toolbar: PanelContainer
var _tools_button: Button
var _menu: MenuButton
var _panel: PanelContainer
var _player_toggle: CheckButton
var _enemy_toggle: CheckButton
var _notice: Label
var _texts: Dictionary = {}
var _commands: Array[BaseButton] = []
var _panels: Dictionary = {}
var _expanded := false
var _available := true
var _blocked := false
var _notice_key := ""
var _notice_params: Dictionary = {}


func configure(shared_theme: Theme) -> void:
	assert(shared_theme != null)
	theme = shared_theme
	name = "TrainingTools"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_toolbar()
	_build_panel()
	resized.connect(_layout)
	refresh_text()
	_sync_available()


func register_panel(id: String, shown: bool = true) -> void:
	assert(PANEL_IDS.has(id), "Unknown training panel: " + id)
	_panels[id] = shown
	_rebuild_menu()

func has_open_popup() -> bool:
	return _menu != null and _menu.get_popup().visible


func set_menu_visibility(id: String, shown: bool) -> void:
	assert(_panels.has(id), "Register training panel before setting its visibility: " + id)
	_panels[id] = shown
	var popup := _menu.get_popup()
	var index := popup.get_item_index(PANEL_IDS.find(id))
	if index >= 0: popup.set_item_checked(index, shown)


func set_invincibility(player_enabled: bool, enemies_enabled: bool) -> void:
	_player_toggle.set_pressed_no_signal(player_enabled)
	_enemy_toggle.set_pressed_no_signal(enemies_enabled)


func set_available(available: bool) -> void:
	_available = available
	_sync_available()


func set_blocked(blocked: bool) -> void:
	# Modal isolation is independent from gameplay commands becoming unavailable.
	_blocked = blocked
	_sync_available()


func set_notice(key: String, params: Dictionary = {}) -> void:
	_notice_key = key
	_notice_params = params.duplicate(true)
	_refresh_notice()


func refresh_text() -> void:
	for node in _texts:
		node.text = tr(_texts[node])
		if node is BaseButton: node.tooltip_text = node.text
	_refresh_notice()
	_rebuild_menu()
	_layout.call_deferred()


func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.name = "TrainingToolbar"
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_toolbar.mouse_force_pass_scroll_events = false
	_toolbar.add_theme_stylebox_override("panel", Appearance.panel_style)
	add_child(_toolbar)
	var margin := _margin(_toolbar, Appearance.toolbar_padding)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Appearance.toolbar_gap)
	margin.add_child(row)
	_tools_button = Button.new()
	_tools_button.name = "TrainingToolsToggle"
	_tools_button.toggle_mode = true
	_prepare_button(_tools_button, "training.tools.title", Appearance.toolbar_height, Appearance.toolbar_font_size)
	_tools_button.toggled.connect(_toggle_tools)
	row.add_child(_tools_button)
	_menu = MenuButton.new()
	_menu.name = "TrainingVisibilityMenu"
	_prepare_button(_menu, "training.menu.title", Appearance.toolbar_height, Appearance.toolbar_font_size)
	row.add_child(_menu)
	var popup := _menu.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.add_theme_font_size_override("font_size", Appearance.body_font_size)
	popup.id_pressed.connect(_menu_selected)
	_menu.about_to_popup.connect(func():
		# Close the editor surface while its menu is in front, without losing its state.
		_panel.hide())
	popup.popup_hide.connect(func():
		_panel.visible = not _blocked and _expanded)
	_toolbar.minimum_size_changed.connect(_layout.call_deferred)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TrainingModifiersPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_force_pass_scroll_events = false
	_panel.add_theme_stylebox_override("panel", Appearance.panel_style)
	add_child(_panel)
	var margin := _margin(_panel, Appearance.panel_padding)
	var scroll := ScrollContainer.new()
	scroll.name = "TrainingToolsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.mouse_force_pass_scroll_events = false
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Appearance.row_gap)
	scroll.add_child(column)
	var title := _label(column, "training.tools.title", Appearance.title_font_size)
	title.add_theme_color_override("font_color", Appearance.heading_color)
	var hint := _label(column, "training.tools.hint", Appearance.hint_font_size)
	hint.add_theme_color_override("font_color", Appearance.hint_color)
	_player_toggle = CheckButton.new()
	_player_toggle.name = "TrainingPlayerInvincible"
	_prepare_button(_player_toggle, "training.tools.player_invincible", Appearance.button_height, Appearance.body_font_size)
	_player_toggle.toggled.connect(func(enabled: bool):
		if _available and not _blocked: player_invincibility_changed.emit(enabled))
	column.add_child(_player_toggle)
	_commands.append(_player_toggle)
	_enemy_toggle = CheckButton.new()
	_enemy_toggle.name = "TrainingEnemiesInvincible"
	_prepare_button(_enemy_toggle, "training.tools.enemies_invincible", Appearance.button_height, Appearance.body_font_size)
	_enemy_toggle.toggled.connect(func(enabled: bool):
		if _available and not _blocked: enemy_invincibility_changed.emit(enabled))
	column.add_child(_enemy_toggle)
	_commands.append(_enemy_toggle)
	var add_wave := Button.new()
	add_wave.name = "TrainingAddWave"
	_prepare_button(add_wave, "training.tools.add_wave", Appearance.button_height, Appearance.body_font_size)
	add_wave.pressed.connect(func():
		if _available and not _blocked: add_wave_requested.emit())
	column.add_child(add_wave)
	_commands.append(add_wave)
	var ranger := Button.new()
	ranger.name = "TrainingRefreshRanger"
	_prepare_button(ranger, "training.tools.ranger", Appearance.button_height, Appearance.body_font_size)
	ranger.pressed.connect(func():
		if _available and not _blocked: ranger_requested.emit())
	column.add_child(ranger)
	_commands.append(ranger)
	var heal := Button.new()
	heal.name = "TrainingHealPlayer"
	_prepare_button(heal, "training.tools.heal", Appearance.button_height, Appearance.body_font_size)
	heal.pressed.connect(func():
		if _available and not _blocked: heal_requested.emit())
	column.add_child(heal)
	_commands.append(heal)
	_notice = _label(column, "", Appearance.hint_font_size)
	_notice.name = "TrainingToolsNotice"
	_notice.add_theme_color_override("font_color", Appearance.notice_color)


func _prepare_button(button: BaseButton, key: String, height: float, font_size: int) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_force_pass_scroll_events = false
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	_texts[button] = key


func _label(parent: Control, key: String, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	if not key.is_empty(): _texts[label] = key
	return label


func _margin(parent: Control, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.mouse_force_pass_scroll_events = false
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, padding)
	parent.add_child(margin)
	return margin


func _toggle_tools(expanded: bool) -> void:
	if _blocked: return
	_expanded = expanded
	_menu.get_popup().hide()
	_panel.visible = _expanded
	_layout()


func _sync_available() -> void:
	if _tools_button == null: return
	_tools_button.disabled = _blocked
	_menu.disabled = _blocked
	for command in _commands: command.disabled = not _available or _blocked
	if _blocked: _menu.get_popup().hide()
	_panel.visible = not _blocked and _expanded and not _menu.get_popup().visible


func _refresh_notice() -> void:
	if _notice == null: return
	_notice.text = tr(_notice_key).format(_notice_params) if not _notice_key.is_empty() else ""
	_notice.visible = not _notice_key.is_empty()


func _rebuild_menu() -> void:
	if _menu == null: return
	var popup := _menu.get_popup()
	popup.clear()
	for index in PANEL_IDS.size():
		var id: String = PANEL_IDS[index]
		if not _panels.has(id): continue
		popup.add_check_item(tr("training.menu." + id), index)
		popup.set_item_checked(popup.item_count - 1, bool(_panels[id]))
	if not _panels.is_empty():
		popup.add_separator()
		popup.add_item(tr("training.menu.hide_all"), HIDE_ALL_ID)
		popup.add_item(tr("training.menu.show_all"), SHOW_ALL_ID)


func _menu_selected(index: int) -> void:
	if _blocked: return
	if index == SHOW_ALL_ID or index == HIDE_ALL_ID:
		for id in PANEL_IDS:
			if _panels.has(id): visibility_requested.emit(id, index == SHOW_ALL_ID)
	elif index >= 0 and index < PANEL_IDS.size():
		var id: String = PANEL_IDS[index]
		if _panels.has(id): visibility_requested.emit(id, not bool(_panels[id]))


func _layout() -> void:
	if _toolbar == null or _panel == null: return
	_toolbar.size = _toolbar.get_combined_minimum_size()
	_toolbar.position = Vector2(maxf(Appearance.margin, (size.x - _toolbar.size.x) / 2.0), Appearance.margin)
	var panel_y: float = _toolbar.position.y + _toolbar.size.y + Appearance.panel_gap
	var available := Vector2(maxf(0.0, size.x - Appearance.margin * 2.0), maxf(0.0, size.y - panel_y - Appearance.margin))
	_panel.size = Vector2(minf(Appearance.panel_width, available.x), minf(Appearance.panel_height, available.y))
	_panel.position = Vector2(maxf(Appearance.margin, (size.x - _panel.size.x) / 2.0), panel_y)
