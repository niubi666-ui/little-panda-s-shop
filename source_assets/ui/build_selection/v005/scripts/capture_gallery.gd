extends SceneTree
## Local visual proof: all artwork sheets, then the actual adventure screen.
const OUT := "E:/ShopGame/source_assets/ui/build_selection/v005/previews/"
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
const Art = preload("res://presentation/builds/build_card_art_library.tres")

func _initialize() -> void: call_deferred("run")

func capture(file: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + file + ".png") == OK)
	print("CAPTURE ", file)

func run() -> void:
	TranslationServer.add_translation(load("res://generated/locales/zh_CN.po"))
	TranslationServer.set_locale("zh_CN")
	root.size = Vector2i(1280, 800)
	var categories := {"martial": "武技与通用强化", "fire": "火元素", "ice": "冰元素与冰协同", "thunder": "雷元素", "earth": "土元素", "reactions": "双元素反应", "training_legacy": "训练与旧版卡"}
	for category in categories:
		var canvas := Control.new()
		canvas.theme = ThemeFactory.create()
		root.add_child(canvas)
		var bg := ColorRect.new()
		bg.color = Color("0b1a14")
		bg.size = Vector2(1280, 800)
		canvas.add_child(bg)
		var title := Label.new()
		title.text = categories[category]
		title.position = Vector2(12, 4)
		title.add_theme_font_size_override("font_size", 24)
		canvas.add_child(title)
		var index := 0
		for id in Art.cards:
			var entry: Dictionary = Art.card(id)
			if entry.category != category: continue
			var offset := Vector2(12 + (index % 4) * 316, 43 + (index / 4) * 250)
			var picture := TextureRect.new()
			picture.texture = load(entry.art)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.position = offset
			picture.size = Vector2(300, 225)
			canvas.add_child(picture)
			var label := Label.new()
			label.text = tr(entry.title_key) + "  ·  " + id
			label.position = offset + Vector2(0, 224)
			label.size = Vector2(300, 25)
			label.add_theme_font_size_override("font_size", 12)
			canvas.add_child(label)
			index += 1
		await capture("sheet_" + category + "_all")
		root.remove_child(canvas)
		canvas.queue_free()
		await process_frame
	root.size = Vector2i(1280, 800)
	var scene = load("res://app/forest_run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 60: await physics_frame
	await capture("in_game_awakening_final")
	var offer: Dictionary = scene.builds.session.snapshot().offer
	assert(not offer.candidates.is_empty())
	var choice_id: String = offer.candidates[0].choice_id
	scene.builds.choice_panel.buttons[choice_id].pressed.emit()
	for i in 6: await process_frame
	assert(not scene.builds.choice_panel.visible, "Real game choice did not dismiss")
	scene.forest_run.panel.hide()
	scene.builds.request_profile_offer("training_all")
	assert(scene.builds.choice_panel.visible, "Real game reward did not open")
	await capture("in_game_reward_final")
	root.remove_child(scene)
	scene.queue_free()
	for i in 5: await process_frame
	quit(0)
