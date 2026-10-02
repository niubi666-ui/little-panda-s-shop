extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func run() -> void:
	for locale in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	TranslationServer.set_locale("zh_CN")
	var menu = load("res://app/pause_menu.gd").new()
	root.add_child(menu)
	menu.configure(load("res://presentation/foliage/foliage_theme_factory.gd").create())
	menu.open()
	check(paused and menu.panel.visible, "Opening must pause the tree")
	var volume: float = menu.panel.actions.master_volume()
	menu.panel.actions.set_master_volume(0.37)
	check(is_equal_approx(menu.panel.actions.master_volume(), 0.37), "Master bus not updated")
	menu.panel.actions.set_master_volume(volume)
	var fps := Engine.max_fps
	menu.panel.actions.set_fps_limit(60)
	check(Engine.max_fps == 60, "FPS cap not applied")
	menu.panel.actions.set_fps_limit(fps)
	for locale in ["zh_CN", "en"]:
		menu.panel.actions.set_language(locale)
		await process_frame
		for page in ["general", "graphics", "controls", "saves"]:
			menu.panel.show_page(page)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("E:/ShopGame/builds/settings_%s_%s.png" % [locale,page])
	menu.panel._confirm_exit()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._input(escape)
	check(paused and not menu.panel.confirming_exit, "Escape must cancel exit confirmation first")
	menu._input(escape)
	check(not paused and not menu.panel.visible, "Escape must resume")
	paused = true
	menu.open()
	menu.close()
	check(paused, "Pre-existing pause must survive menu close")
	paused = false
	menu.queue_free()
	await process_frame
	print("SETTINGS_MENU_TEST ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
