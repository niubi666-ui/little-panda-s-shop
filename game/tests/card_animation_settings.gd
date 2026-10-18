extends SceneTree
## UI-only persistence and the actual settings -> card panel signal route.
## Uses a private temporary preference file, never the player's saved preferences.
const Preference = preload("res://presentation/settings/card_animation_preference.gd")
const Defaults = preload("res://presentation/settings/player_preferences.tres")
const Loader = preload("res://content/builds/build_loader.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const PauseMenu = preload("res://app/pause_menu.gd")
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _offer() -> Dictionary:
	var candidates: Array = []
	for id in ["fire_core", "ice_core", "thunder_core"]:
		candidates.append({"choice_id": id, "upgrade_id": id, "action_id": "skill",
			"rank": 1, "operation": "add", "replaced": {}, "rarity_id": Art.card(id).default_rarity})
	return {"id": "animation_settings_fixture", "candidates": candidates, "resolved": false}

func _card_state(panel, enabled: bool) -> void:
	for card in panel.buttons.values():
		check((card.art_motion != null) == enabled, "animation allocation follows setting: " + card.art_id)
		var illustration: TextureRect = card.get_node("Illustration")
		check(illustration.visible and illustration.texture != null, "static art remains visible: " + card.art_id)
		check(illustration.texture.resource_path == card.art_path, "same source art retained: " + card.art_id)

func run() -> void:
	root.size = Vector2i(1280, 800)
	var test_path := "user://card_animation_preference_test_%s.cfg" % OS.get_process_id()
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var preference := Preference.new(test_path)
	check(preference.is_enabled() == Defaults.card_animation_enabled, "new profile uses authored default")
	check(not FileAccess.file_exists(test_path), "reading a default does not create a preferences file")
	var existing := ConfigFile.new()
	existing.set_value("future_ui_option", "keep", "untouched")
	check(existing.save(test_path) == OK, "write isolated fixture")
	preference = Preference.new(test_path)
	check(preference.set_enabled(false) == OK, "save disabled preference")
	var reopened := Preference.new(test_path)
	check(not reopened.is_enabled(), "disabled preference survives a new instance / scene")
	check(existing.load(test_path) == OK and existing.get_value("future_ui_option", "keep") == "untouched", "unrelated preference fields survive saving")
	for locale in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	var catalog = Loader.new().load_catalog()
	check(catalog != null, "catalog loads")
	if catalog == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
		quit(1)
		return
	var shared_theme: Theme = ThemeFactory.create()
	var panel := ChoicePanel.new()
	root.add_child(panel)
	panel.configure(catalog, shared_theme, reopened)
	var offer := _offer()
	panel.show_offer(offer, [])
	_card_state(panel, false)
	var menu := PauseMenu.new()
	root.add_child(menu)
	menu.configure(shared_theme, reopened)
	menu.card_animation_changed.connect(panel.set_art_motion_enabled)
	var changes: Array[bool] = []
	menu.card_animation_changed.connect(func(enabled): changes.append(enabled))
	menu.open()
	check(paused and menu.panel.visible, "settings pause gameplay")
	menu.panel.show_page("graphics")
	var toggle: OptionButton = menu.panel.canvas.get_node("CardAnimationToggle")
	check(toggle.selected == 0, "settings displays persisted disabled state")
	toggle.select(1)
	toggle.item_selected.emit(1)
	_card_state(panel, true)
	check(Preference.new(test_path).is_enabled(), "UI toggle persists enabled state")
	var clocks: Array[float] = []
	for card in panel.buttons.values(): clocks.append(card.art_motion.clock)
	for frame in 3: await process_frame
	for index in clocks.size():
		check(is_equal_approx(panel.buttons.values()[index].art_motion.clock, clocks[index]), "SceneTree pause freezes enabled card motion")
	menu.close()
	menu.open()
	menu.panel.show_page("graphics")
	toggle = menu.panel.canvas.get_node("CardAnimationToggle")
	check(toggle.selected == 1 and changes == [true], "reopening reads current setting without emitting or duplicating change signals")
	toggle.select(0)
	toggle.item_selected.emit(0)
	await process_frame
	check(changes == [true, false], "one UI toggle produces exactly one application signal after reopening")
	_card_state(panel, false)
	check(panel._offer == offer and panel.buttons.size() == 3, "preference does not change or resolve reward candidates")
	panel.show_offer(offer, [])
	_card_state(panel, false)
	check(not Preference.new(test_path).is_enabled(), "new cards keep the disabled preference")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		await process_frame
		menu.panel.show_page("graphics")
		var control: OptionButton = menu.panel.canvas.get_node("CardAnimationToggle")
		check(control.get_item_text(0) == TranslationServer.translate("settings.off"), locale + " off label translated")
		check(control.get_item_text(1) == TranslationServer.translate("settings.on"), locale + " on label translated")
		check(control.tooltip_text != "settings.card_animation_hint", locale + " hint translated")
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := ProjectSettings.globalize_path("res://../builds/card_animation_settings_%s.png" % locale)
			check(root.get_texture().get_image().save_png(screenshot) == OK, "save " + locale + " settings preview")
	menu.close()
	check(not paused and panel.is_open(), "closing settings restores unresolved choice")
	menu.queue_free()
	panel.queue_free()
	await process_frame
	await process_frame
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path)) == OK, "remove only isolated preference fixture")
	print("CARD_ANIMATION_SETTINGS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
