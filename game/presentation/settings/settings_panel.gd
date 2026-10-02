extends Control
## Art and input only; engine settings are delegated to the injected adapter.
signal close_requested
signal quit_requested
const Appearance = preload("res://presentation/settings/settings_skin.tres")
var actions
var page := "general"
var confirming_exit := false
var canvas: Control
var _pending := false

func configure(shared_theme: Theme, settings_actions) -> void:
	theme = shared_theme.duplicate()
	actions = settings_actions
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	resized.connect(_layout)
	_build()

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var factor := minf(size.x / (Appearance.design_size.x + 120.0), size.y / (Appearance.design_size.y + 100.0))
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Appearance.design_size * factor) / 2.0

func show_page(id: String) -> void:
	page = id
	confirming_exit = false
	_build()

func _art(parent: Control, id: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	parent.add_child(node)
	node.texture = Appearance.textures[id]
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = MOUSE_FILTER_IGNORE
	return node

func _label(parent: Control, key: String, rect: Rect2, paper: bool = false) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = tr(key)
	node.position = rect.position
	node.size = rect.size
	node.add_theme_color_override("font_color", Appearance.ink if paper else Appearance.gold)
	node.mouse_filter = MOUSE_FILTER_IGNORE
	return node

func _style(art: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = Appearance.textures[art]
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box

func _button(parent: Control, key: String, rect: Rect2, callback: Callable, art: String = "tab_regular") -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = tr(key)
	button.position = rect.position
	button.size = rect.size
	button.add_theme_stylebox_override("normal", _style(art))
	var hover := _style(art)
	hover.modulate_color = Color(1.2, 1.2, 1.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _style("tab_selected"))
	button.add_theme_stylebox_override("disabled", _style(art))
	button.add_theme_color_override("font_color", Appearance.gold)
	button.add_theme_color_override("font_disabled_color", Color(0.68, 0.65, 0.53))
	button.pressed.connect(callback)
	return button

func _placeholder(key: String, rect: Rect2) -> void:
	var button := _button(canvas, key, rect, func(): pass)
	button.disabled = true
	button.tooltip_text = tr("settings.pending")

func _build() -> void:
	_pending = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var dim := ColorRect.new()
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Appearance.dim
	canvas = Control.new()
	add_child(canvas)
	canvas.size = Appearance.design_size
	_art(canvas, "window_panel", Appearance.frame)
	_art(canvas, "controls_parchment", Appearance.paper)
	_label(canvas, "settings.title", Rect2(64, 34, 500, 50)).theme_type_variation = &"Title"
	_button(canvas, "shop.preview.close", Rect2(915, 35, 138, 48), func(): close_requested.emit())
	var index := 0
	for id in ["general", "graphics", "controls", "saves"]:
		var rect: Rect2 = Appearance.navigation
		rect.position.y += index * 83.0
		var tab := _button(canvas, "settings." + id, rect, show_page.bind(id), "tab_selected" if page == id else "tab_regular")
		var icons := {"general":"speaker", "graphics":"monitor", "controls":"gamepad", "saves":"save"}
		tab.icon = load("res://assets/ui/settings/v002/icons/%s.svg" % icons[id])
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 25)
		index += 1
	_art(canvas, "header_leaf_sprig", Rect2(110, 475, 90, 85))
	_label(canvas, "settings." + page, Rect2(445, 133, 560, 40), true).theme_type_variation = &"Title"
	if confirming_exit:
		var warning := _label(canvas, "settings.exit_warning", Rect2(355, 215, 635, 135), true)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(canvas, "settings.cancel", Rect2(360, 400, 260, 66), show_page.bind(page), "button_primary")
		_button(canvas, "settings.quit_confirm", Rect2(690, 400, 310, 66), func(): quit_requested.emit(), "button_exit")
	else:
		match page:
			"general": _general()
			"graphics": _graphics()
			"controls": _controls()
			"saves":
				var note := _label(canvas, "settings.save_note", Rect2(355, 218, 635, 150), true)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_placeholder("settings.save_pending", Rect2(370, 410, 270, 66))
				_placeholder("settings.load_pending", Rect2(695, 410, 300, 66))
	var note := _label(canvas, "settings.session_note", Rect2(335, 538, 690, 30), true)
	note.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "Muted"))
	_button(canvas, "settings.resume", Rect2(48, 603, 245, 70), func(): close_requested.emit(), "button_primary")
	_button(canvas, "settings.save", Rect2(307, 603, 245, 70), show_page.bind("saves"), "button_secondary")
	_button(canvas, "settings.load", Rect2(566, 603, 245, 70), show_page.bind("saves"), "button_secondary")
	_button(canvas, "settings.quit", Rect2(825, 603, 230, 70), _confirm_exit, "button_exit")
	_layout()

func _confirm_exit() -> void:
	confirming_exit = true
	_build()

func _row(key: String, index: int) -> Rect2:
	var y: float = Appearance.content.position.y + Appearance.row_height * (index + 1)
	_label(canvas, key, Rect2(355, y, 290, 40), true)
	return Rect2(685, y, 312, 42)

func _option(rect: Rect2, texts: Array, selected: int, callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	canvas.add_child(option)
	option.position = rect.position
	option.size = rect.size
	option.add_theme_stylebox_override("normal", _style("tab_regular"))
	option.add_theme_stylebox_override("hover", _style("tab_selected"))
	option.add_theme_stylebox_override("pressed", _style("tab_selected"))
	for key in texts: option.add_item(tr(key))
	option.select(selected)
	option.item_selected.connect(callback)
	return option

func _general() -> void:
	_option(_row("settings.language", 0), ["settings.chinese", "settings.english"], 0 if TranslationServer.get_locale().begins_with("zh") else 1, func(index): actions.set_language("zh_CN" if index == 0 else "en"))
	var rect := _row("settings.master", 1)
	_art(canvas, "slider_track", Rect2(rect.position + Vector2(0, 13), Vector2(rect.size.x - 65, 16)))
	var fill := ColorRect.new()
	canvas.add_child(fill)
	fill.color = Color(0.29, 0.39, 0.12)
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	fill.position = rect.position + Vector2(8, 18)
	fill.size = Vector2((rect.size.x - 81) * actions.master_volume(), 6)
	var slider := HSlider.new()
	canvas.add_child(slider)
	slider.position = rect.position
	slider.size = Vector2(rect.size.x - 65, rect.size.y)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = actions.master_volume()
	var track := StyleBoxEmpty.new()
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	var pixels: Image = Appearance.textures["slider_thumb"].get_image()
	pixels.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	var thumb := ImageTexture.create_from_image(pixels)
	slider.add_theme_icon_override("grabber", thumb)
	slider.add_theme_icon_override("grabber_highlight", thumb)
	var percent := _label(canvas, "", Rect2(rect.end.x - 60, rect.position.y, 65, 40), true)
	percent.text = tr("settings.percent").format({"value": roundi(slider.value * 100)})
	slider.value_changed.connect(func(value):
		actions.set_master_volume(value)
		fill.size.x = (rect.size.x - 81) * value
		percent.text = tr("settings.percent").format({"value": roundi(value * 100)}))
	_placeholder("settings.audio_pending", _row("settings.music", 2))
	_placeholder("settings.audio_pending", _row("settings.sfx", 3))
	_placeholder("settings.display_pending", _row("settings.window", 4))
	_vsync(5)

func _vsync(index: int) -> void:
	_option(_row("settings.vsync", index), ["settings.off", "settings.on"], int(actions.vsync_enabled()), func(value): actions.set_vsync(value == 1))

func _graphics() -> void:
	_placeholder("settings.display_pending", _row("settings.window", 0))
	_placeholder("settings.display_pending", _row("settings.resolution", 1))
	_vsync(2)
	var limits: Array = Array(Appearance.fps_limits)
	var options: Array = []
	for limit in limits: options.append("settings.unlimited" if limit == 0 else str(limit))
	var selected := limits.find(Engine.max_fps)
	if selected == -1:
		limits.append(Engine.max_fps)
		options.append(str(Engine.max_fps))
		selected = limits.size() - 1
	_option(_row("settings.fps", 3), options, selected, func(index): actions.set_fps_limit(limits[index]))
	_placeholder("settings.pending", _row("settings.quality", 4))

func _controls() -> void:
	var bindings := {"settings.move":"move_forward", "settings.attack":"combat_attack", "settings.dodge":"combat_dodge", "settings.interact":"interact"}
	var index := 0
	for key in bindings:
		var events := InputMap.action_get_events(bindings[key])
		var text := events[0].as_text() if not events.is_empty() else tr("settings.unbound")
		if key == "settings.move":
			var keys := PackedStringArray()
			for action in ["move_forward", "move_left", "move_back", "move_right"]:
				var event: InputEventKey = InputMap.action_get_events(action)[0]
				keys.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
			text = " / ".join(keys)
		elif events[0] is InputEventKey:
			var event: InputEventKey = events[0]
			text = OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
		elif events[0] is InputEventMouseButton:
			text = tr("settings.mouse_button").format({"button": events[0].button_index})
		var label := _label(canvas, "", _row(key, index), true)
		label.text = text
		index += 1
	_placeholder("settings.rebind_pending", Rect2(370, 440, 610, 48))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and actions != null and not _pending:
		_pending = true
		_build.call_deferred()

