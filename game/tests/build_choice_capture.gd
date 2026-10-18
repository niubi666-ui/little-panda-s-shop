extends SceneTree
## 三选一界面在真实训练场里的截图（图形模式）：刚弹出、悬停中间那张、选中后。
## godot --path game --script res://tests/build_choice_capture.gd -- [tag=名字] [size=1920x1080] [frames] [still=图片路径]
## still= 时不进训练场，用一张游戏截图当背景，弹出一组真实抽到的卡（战斗代码改到一半时也能看界面）。
## 写 frames 则把弹出和选中的动画逐帧存下来（每 2 帧一张），用来检查动画节奏。
## 输出到 builds/visual_pass/choice_<名字>_*.png。
const OUT := "E:/ShopGame/builds/visual_pass/"
const Loader = preload("res://content/builds/build_loader.gd")
const Rewards = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var tag := "now"
var frames := false

func _initialize() -> void:
	call_deferred("run")
	create_timer(120.0).timeout.connect(func() -> void: quit(2))

func _shot(name: String, settle: int = 8) -> void:
	for i in settle: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "choice_" + tag + "_" + name + ".png")
	print("SHOT ", name)

func _film(name: String, count: int) -> void:
	for i in count:
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "choice_%s_%s_%02d.png" % [tag, name, i])

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var size := Vector2i(1920, 1080)
	var still := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tag="): tag = arg.substr(4)
		elif arg.begins_with("size="):
			var parts := arg.substr(5).split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "frames": frames = true
		elif arg.begins_with("still="): still = arg.substr(6)
	root.size = size
	var panel
	if still.is_empty():
		var arena = load("res://app/combat_training.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		panel = arena.builds.choice_panel
	else:
		panel = _still_panel(still)
	for i in 600:
		await process_frame
		if panel.visible: break
	if frames: await _film("open", 14)
	await _shot("open", 40)
	var cards: Array = panel.buttons.values()
	var middle: Control = cards[1]
	var motion := InputEventMouseMotion.new()
	motion.position = middle.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	middle.grab_focus()
	await _shot("hover", 30)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = motion.position
	click.global_position = motion.position
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	if frames: await _film("pick", 16)
	else: await _shot("picked", 6)
	await _shot("after", 60)
	quit(0)

func _still_panel(path: String):
	TranslationServer.add_translation(load("res://generated/locales/zh_CN.po"))
	TranslationServer.set_locale("zh_CN")
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var catalog = Loader.new().load_catalog()
	var panel = ChoicePanel.new()
	root.add_child(panel)
	panel.configure(catalog, ThemeFactory.create())
	var session = Session.new()
	session.configure(catalog, 7, func(_candidate): return OK, Rewards.new().load_groups(catalog))
	session.open_offer("normal_room", {})
	var offer: Dictionary = session.snapshot().offer
	panel.choice_requested.connect(func(offer_id, choice_id):
		if session.choose(offer_id, choice_id).ok: panel.dismiss())
	panel.show_offer(offer, [])
	return panel
