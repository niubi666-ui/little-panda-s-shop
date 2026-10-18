extends Control
## Fixed art preview, using the production panel and cards; never touches reward pools.
const Settings = preload("res://ui_lab/card_art_motion/lab_settings.tres")
const Loader = preload("res://content/builds/build_loader.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var panel
var catalog
var motion_enabled: bool = Settings.starting_motion_enabled
var motion_paused := false
var intensity: float
var group_index := 0
var selection_count := 0
var offer_sequence := 0
var _selected_name := ""
var _selected_title_key := ""
var _dynamic: CheckButton
var _paused: CheckButton
var _intensity_label: Label
var _intensity_value: Label
var _slider: HSlider
var _groups: OptionButton
var _language: Button
var _reopen: Button
var _quit: Button
var _status: Label
var _mode: Label
var _demo := false
var _catalog_demo := false
var _all_groups: Array[Dictionary] = []
var _demo_time := 0.0
var _demo_event := 0
var _motion_card_ids: Array[int] = []

func _ready() -> void:
	for locale in Settings.locales:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
		var messages := Translation.new()
		messages.locale = locale
		for key in Settings.translations[locale]:
			messages.add_message("card_motion_lab." + key, Settings.translations[locale][key])
		TranslationServer.add_translation(messages)
	TranslationServer.set_locale(Settings.default_locale)
	theme = ThemeFactory.create()
	intensity = Settings.starting_intensity
	catalog = Loader.new().load_catalog()
	assert(catalog != null, "Card motion lab requires a valid build catalog")
	_all_groups.assign(Settings.groups)
	_all_groups.append_array(Settings.catalog_groups)
	var covered: Dictionary = {}
	for group in Settings.catalog_groups:
		assert(not group.ids.is_empty() and group.ids.size() <= Settings.actions.size())
		for id in group.ids:
			assert(Art.cards.has(id) and not covered.has(id), "Gallery IDs must exist and occur once: " + id)
			covered[id] = true
	assert(covered.size() == Art.cards.size(), "Gallery must cover every card illustration")
	assert(Settings.catalog_demo_page_sec > 0.0)
	_catalog_demo = "--catalog-demo" in OS.get_cmdline_user_args()
	_demo = "--demo" in OS.get_cmdline_user_args() and not _catalog_demo
	if _catalog_demo: group_index = Settings.groups.size()
	var background := TextureRect.new()
	background.name = "ForestToneBackdrop"
	background.texture = Settings.background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = ChoicePanel.new()
	add_child(panel)
	panel.configure(catalog, theme)
	# The preview's temporary toggle overrides game preferences without saving.
	panel.set_art_motion_enabled(motion_enabled)
	panel.choice_requested.connect(_choose)
	_controls()
	refresh_text()
	show_cards()
	if _demo: print("CARD_ART_MOTION_DEMO duration=", Settings.demo_duration)
	if _catalog_demo: print("CARD_ART_CATALOG_DEMO pages=", Settings.catalog_groups.size(), " duration=", Settings.catalog_groups.size() * Settings.catalog_demo_page_sec)

func _controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LabControls"
	layer.layer = 101
	add_child(layer)
	var margin := MarginContainer.new()
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", int(Settings.toolbar_margin.x))
	margin.add_theme_constant_override("margin_right", int(Settings.toolbar_margin.x))
	margin.add_theme_constant_override("margin_top", int(Settings.toolbar_margin.y))
	var wrap := HFlowContainer.new()
	wrap.theme = theme
	wrap.add_theme_constant_override("h_separation", Settings.toolbar_gap)
	wrap.add_theme_constant_override("v_separation", Settings.toolbar_gap)
	margin.add_child(wrap)
	_dynamic = CheckButton.new()
	_dynamic.button_pressed = motion_enabled
	_dynamic.toggled.connect(set_motion_enabled)
	_control(wrap, _dynamic)
	_paused = CheckButton.new()
	_paused.toggled.connect(set_motion_paused)
	_control(wrap, _paused)
	var strength := HBoxContainer.new()
	strength.add_theme_constant_override("separation", Settings.toolbar_gap)
	wrap.add_child(strength)
	_intensity_label = Label.new()
	_control(strength, _intensity_label)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = Settings.max_intensity
	_slider.step = Settings.intensity_step
	_slider.value = intensity
	_slider.custom_minimum_size.x = Settings.slider_width
	_slider.value_changed.connect(set_intensity)
	_control(strength, _slider)
	_intensity_value = Label.new()
	_control(strength, _intensity_value)
	_groups = OptionButton.new()
	for group in _all_groups: _groups.add_item(group.label)
	_groups.select(group_index)
	_groups.item_selected.connect(set_group)
	_control(wrap, _groups)
	_language = Button.new()
	_language.pressed.connect(toggle_language)
	_control(wrap, _language)
	_reopen = Button.new()
	_reopen.pressed.connect(show_cards)
	_control(wrap, _reopen)
	_quit = Button.new()
	_quit.pressed.connect(func(): get_tree().quit())
	_control(wrap, _quit)
	var footer := VBoxContainer.new()
	footer.theme = theme
	layer.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = Settings.toolbar_margin.x
	footer.offset_right = -Settings.toolbar_margin.x
	footer.offset_top = -Settings.status_height - Settings.toolbar_margin.y
	footer.offset_bottom = -Settings.toolbar_margin.y
	_mode = Label.new()
	_status = Label.new()
	for label in [_mode, _status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Settings.status_color)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_control(footer, label)

func _control(parent: Control, control: Control) -> void:
	control.add_theme_font_size_override("font_size", Settings.font_size)
	control.custom_minimum_size.y = Settings.control_height
	if control is BaseButton: control.focus_mode = Control.FOCUS_NONE
	parent.add_child(control)

func show_cards() -> void:
	offer_sequence += 1
	_selected_title_key = ""
	_selected_name = ""
	var candidates: Array = []
	var ids: Array = _all_groups[group_index].ids
	for index in ids.size():
		var id: String = ids[index]
		candidates.append({"choice_id": "sample_%s_%s" % [offer_sequence, index],
			"upgrade_id": id, "action_id": _sample_action(id, index), "rank": 1,
			"operation": "add", "replaced": {}, "rarity_id": Art.card(id).default_rarity})
	panel.set_art_motion_enabled(motion_enabled)
	panel.show_offer({"id": "card_art_motion_%s" % offer_sequence, "candidates": candidates,
		"resolved": false}, [], ["card_motion_lab.heading", "card_motion_lab.subtitle"])
	_apply_motion()
	refresh_text()

func _sample_action(id: String, index: int) -> String:
	var entry: Dictionary = catalog.upgrade(id)
	if entry.scope == "global": return "global"
	var preferred: String = Settings.actions[index]
	return preferred if preferred in entry.action_ids else String(entry.action_ids[0])

func _choose(_offer_id: String, choice_id: String) -> void:
	if not panel.accepting() or not _selected_title_key.is_empty(): return
	selection_count += 1
	_selected_title_key = Art.card(panel.buttons[choice_id].art_id).title_key
	_selected_name = tr(_selected_title_key)
	panel.dismiss()
	refresh_text()

func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	_dynamic.set_pressed_no_signal(value)
	_apply_motion()
	refresh_text()

func set_motion_paused(value: bool) -> void:
	motion_paused = value
	_paused.set_pressed_no_signal(value)
	_apply_motion()
	refresh_text()

func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, Settings.max_intensity)
	_slider.set_value_no_signal(intensity)
	_apply_motion()
	refresh_text()

func set_group(index: int) -> void:
	assert(index >= 0 and index < _all_groups.size())
	group_index = index
	_groups.select(index)
	show_cards()

func toggle_language() -> void:
	var current := Settings.locales.find(TranslationServer.get_locale())
	TranslationServer.set_locale(Settings.locales[(current + 1) % Settings.locales.size()])
	if not _selected_title_key.is_empty(): _selected_name = tr(_selected_title_key)
	panel.refresh_text()
	refresh_text()

func refresh_text() -> void:
	if _dynamic == null: return
	_dynamic.text = tr("card_motion_lab.dynamic")
	_paused.text = tr("card_motion_lab.pause")
	_intensity_label.text = tr("card_motion_lab.intensity")
	_intensity_value.text = "%.2f" % intensity
	_language.text = tr("card_motion_lab.language")
	_reopen.text = tr("card_motion_lab.reopen")
	_quit.text = tr("card_motion_lab.quit")
	for index in _all_groups.size():
		_groups.set_item_text(index, _group_label(index))
	var mode := "paused" if motion_paused else "active"
	if not motion_enabled or intensity <= 0.0: mode = "static"
	_mode.text = tr("card_motion_lab." + mode)
	_status.text = (_group_label(group_index) + " · " + tr("card_motion_lab.help")) if _selected_title_key.is_empty() else tr("card_motion_lab.selected").format({"name": _selected_name})

func _group_label(index: int) -> String:
	var category := tr("card_motion_lab." + _all_groups[index].label)
	if index < Settings.groups.size(): return category
	return tr("card_motion_lab.gallery_page").format({"page": index - Settings.groups.size() + 1,
		"total": Settings.catalog_groups.size(), "category": category})

func _apply_motion() -> void:
	_motion_card_ids.clear()
	panel.set_art_motion_enabled(motion_enabled)
	for card in panel.buttons.values():
		_motion_card_ids.append(card.get_instance_id())
		card.set_art_motion_intensity(intensity)
		card.set_art_motion_paused(motion_paused)

func _process(delta: float) -> void:
	# Queued offers finish their old exit animation before creating new cards.
	# Apply current lab settings to those replacement instances too.
	if panel != null and panel.visible:
		var ids: Array[int] = []
		for card in panel.buttons.values(): ids.append(card.get_instance_id())
		if ids != _motion_card_ids: _apply_motion()
	if not _demo and not _catalog_demo: return
	_demo_time += delta
	if _catalog_demo:
		var page := int(_demo_time / Settings.catalog_demo_page_sec)
		if page >= Settings.catalog_groups.size():
			print("CARD_ART_CATALOG_DEMO completed pages=", Settings.catalog_groups.size(), " cards=", Art.cards.size())
			get_tree().quit()
		elif group_index != Settings.groups.size() + page:
			set_group(Settings.groups.size() + page)
		return
	while _demo_event < Settings.demo_events.size() and _demo_time >= float(Settings.demo_events[_demo_event].at):
		_run_demo_event(Settings.demo_events[_demo_event])
		_demo_event += 1
	if _demo_time >= Settings.demo_duration:
		print("CARD_ART_MOTION_DEMO completed selections=", selection_count)
		get_tree().quit()

func _run_demo_event(event: Dictionary) -> void:
	match String(event.action):
		"focus":
			if panel.buttons.size() > int(event.index): panel.buttons.values()[event.index].grab_focus()
		"static": set_motion_enabled(false)
		"dynamic": set_motion_enabled(true)
		"choose":
			if panel.buttons.size() > int(event.index): panel.buttons.values()[event.index].pressed.emit()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_D: set_motion_enabled(not motion_enabled)
		KEY_P: set_motion_paused(not motion_paused)
		KEY_L: toggle_language()
		KEY_F: show_cards()
		KEY_PAGEUP: set_group(posmod(group_index - 1, _all_groups.size()))
		KEY_PAGEDOWN: set_group((group_index + 1) % _all_groups.size())
		_: return
	get_viewport().set_input_as_handled()
