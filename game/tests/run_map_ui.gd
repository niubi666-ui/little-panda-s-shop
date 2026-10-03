extends SceneTree
## Presentation-only route snapshot, input and bilingual bounds checks.
const MapView = preload("res://presentation/run/run_map_view.gd")
const RoomHUD = preload("res://presentation/run/room_progress_hud.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var failures: Array[String] = []
var _chosen: Array[String] = []
var _restarts := 0
var _returns := 0
var _translations: Array[Translation] = []


func _initialize() -> void: run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func snapshot() -> Dictionary:
	return {"nodes": [
		{"id": "entry", "layer": 0, "column": 1, "kind": "battle", "state": "available"},
		{"id": "left", "layer": 1, "column": 0, "kind": "battle", "state": "locked"},
		{"id": "right", "layer": 1, "column": 2, "kind": "elite", "state": "locked"},
		{"id": "merge", "layer": 2, "column": 1, "kind": "battle", "state": "locked"},
		{"id": "upper_left", "layer": 3, "column": 0, "kind": "elite", "state": "locked"},
		{"id": "upper_right", "layer": 3, "column": 2, "kind": "battle", "state": "locked"},
		{"id": "terminal", "layer": 4, "column": 1, "kind": "terminal", "state": "locked"},
	], "edges": [
		{"from": "entry", "to": "left"}, {"from": "entry", "to": "right"},
		{"from": "left", "to": "merge"}, {"from": "right", "to": "merge"},
		{"from": "merge", "to": "upper_left"}, {"from": "merge", "to": "upper_right"},
		{"from": "upper_left", "to": "terminal"}, {"from": "upper_right", "to": "terminal"},
	], "current_node_id": "", "room_count": 0, "phase": "map", "available_node_ids": ["entry"]}


func _load_source_translations() -> void:
	for locale in ["zh_CN", "en"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/" + locale + ".json"))
		var translation := Translation.new()
		translation.locale = locale
		for key in source.messages: translation.add_message(key, source.messages[key])
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func run() -> void:
	root.size = Vector2i(1280, 800)
	_load_source_translations()
	var view := MapView.new()
	root.add_child(view)
	view.configure(ThemeFactory.create())
	view.node_requested.connect(func(id: String): _chosen.append(id))
	view.restart_requested.connect(func(): _restarts += 1)
	var state := snapshot()
	var original := JSON.stringify(state)
	view.show_route(state)
	await settle()
	check(view.buttons.size() == state.nodes.size(), "all route nodes rendered")
	check(view.buttons.entry.position.y > view.buttons.terminal.position.y, "route progresses bottom to top")
	check(view.buttons.left.position.y == view.buttons.right.position.y and view.buttons.left.position.x < view.buttons.right.position.x, "split branches share a layer and distinct columns")
	check(view._paths._paths.size() == state.edges.size(), "all split and merge edges rendered")
	check(not view.buttons.entry.disabled and view.buttons.terminal.disabled, "only available node enabled")
	check(view._scroll.get_v_scroll_bar().max_value <= view._scroll.get_v_scroll_bar().page + 1.0, "five layers fit together at 1280x800")
	await click(view.buttons.entry)
	check(_chosen == ["entry"], "viewport click emits stable available node identity")
	view.buttons.terminal.pressed.emit()
	check(_chosen.size() == 1, "locked node rejects manually emitted button signal")
	view.set_busy(true)
	view.buttons.entry.pressed.emit()
	view._restart.pressed.emit()
	check(_chosen.size() == 1 and _restarts == 0, "busy suppresses entry and restart requests")
	view.set_busy(false)
	view._restart.pressed.emit()
	check(_restarts == 1, "map restart request available again")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		view.refresh_text()
		await settle()
		check(not view._title.text.begins_with("run."), locale + " translated map title")
		for id in view.buttons:
			var button: Button = view.buttons[id]
			check(button.get_global_rect().position.x >= 0.0 and button.get_global_rect().end.x <= root.size.x, locale + " node inside horizontal viewport " + id)
			check(button.size.y <= 80.0, locale + " node text fits configured height " + id)
		check(view._restart.get_global_rect().end.y <= root.size.y, locale + " footer stays on screen")
		await capture("run_map_" + locale)
	view.set_notice("run.error.load_failed")
	await settle()
	check(view._notice.visible and view._notice.text == tr("run.error.load_failed"), "translated app notice appears")
	check(view._restart.get_global_rect().end.y <= root.size.y, "notice grows footer without clipping restart")
	view.set_notice("")
	check(JSON.stringify(state) == original, "view never mutates caller snapshot")
	state.nodes[0].state = "completed"
	state.nodes[1].state = "available"
	state.nodes[2].state = "available"
	state.current_node_id = "entry"
	state.room_count = 1
	state.available_node_ids = ["left", "right"]
	view.show_route(state)
	await settle()
	check(view.buttons.entry.disabled and not view.buttons.left.disabled and not view.buttons.right.disabled, "committed next snapshot updates split availability")
	view.hide()
	var hud := RoomHUD.new()
	root.add_child(hud)
	hud.configure(ThemeFactory.create())
	hud.map_requested.connect(func(): _returns += 1)
	hud.restart_requested.connect(func(): _restarts += 1)
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		hud.display(3, "elite", 67, 100, "combat")
		hud.refresh_text()
		await settle()
		check(hud._number.text.contains("3") and hud._health.text.contains("67"), locale + " prominent room ordinal and carried health")
		check(not hud._action.visible, locale + " map return unavailable during combat")
		hud._action.pressed.emit()
		check(_returns == 0, locale + " direct signal cannot return before clear")
		hud.display(3, "elite", 67, 100, "cleared")
		await settle()
		check(hud._action.visible and hud._action.text == tr("run.return_map"), locale + " clear reveals return action")
		check(hud._panel.get_global_rect().end.y < root.size.y, locale + " room HUD stays on screen")
		await capture("run_room_hud_" + locale)
	await click(hud._action)
	check(_returns == 1, "clear button emits return-map request")
	hud.display(5, "terminal", 50, 100, "completed")
	await settle()
	await click(hud._action)
	check(_restarts == 2 and _returns == 1, "terminal completion requests restart, not another room")
	hud.display(2, "battle", 0, 100, "defeated")
	hud.set_busy(true)
	hud._action.pressed.emit()
	check(_restarts == 2, "busy room HUD suppresses duplicate restart")
	hud.set_busy(false)
	await click(hud._action)
	check(_restarts == 3, "defeated room can request a new run")
	view.queue_free()
	hud.queue_free()
	await settle()
	for translation in _translations: TranslationServer.remove_translation(translation)
	print("RUN_MAP_UI ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func capture(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots") or DisplayServer.get_name() == "headless": return
	await process_frame
	var path := ProjectSettings.globalize_path("res://../builds/" + id + ".png")
	root.get_texture().get_image().save_png(path)
