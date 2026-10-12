extends SceneTree
## 视觉检查用截图工具（图形模式运行，不是规则测试）。
## 用法：godot --path game --script res://tests/visual_pass_capture.gd -- <模式> [房间presentation路径]
##   overview  进入训练场后隐藏界面截一张；再把镜头拉到最远截一张
##   combat    把一个敌人摆到玩家面前，打一套三连 + 重击，逐帧输出序列
##   lineup    把每种敌人各放一个排在玩家面前，截近景
const OUT := "E:/ShopGame/builds/visual_pass/"

func _initialize() -> void: call_deferred("run")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "overview"
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	if args.size() > 1: arena.room_presentation = load(args[1])
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.2).timeout
	arena.training_tools.panel.hide()
	var ui: CanvasLayer = arena.get_node("UIRoot")
	match mode:
		"overview":
			await _shot("overview_ui")
			ui.hide()
			await create_timer(3.4).timeout
			await _shot("overview")
			arena.get_node("Camera").size = arena.room_presentation.camera_max_size
			await create_timer(0.2).timeout
			await _shot("overview_far")
			arena.get_node("Camera").size = arena.room_presentation.camera_min_size
			await create_timer(0.2).timeout
			await _shot("overview_near")
		"combat":
			ui.hide()
			await create_timer(3.4).timeout
			var player = arena.player
			var enemy = null
			for actor in arena.actors:
				if actor != player and actor.health.alive():
					enemy = actor
					break
			if enemy == null:
				print("CAPTURE no enemy")
				quit(1)
				return
			enemy.global_position = player.global_position + Vector3(1.3, 0, -1.3)
			var frame := 0
			for step in ["primary", "primary", "primary", "special"]:
				player.request_action(step)
				for tick in 46:
					await physics_frame
					if enemy.health.alive(): player.facing = (enemy.global_position - player.global_position).normalized()
					if tick % 3 == 0:
						await _shot("combat_%02d" % frame)
						frame += 1
					if tick > 6 and not player.runner.busy(): break
		"lineup":
			ui.hide()
			await create_timer(3.4).timeout
			var player = arena.player
			player.set_damage_immunity(true)
			# 清掉随机遭遇里的敌人，换成每种各一个，排在玩家面前
			for actor in arena.actors:
				if actor != player: actor.global_position = Vector3(40, 0.12, 40)
			var ids := ["scout", "crossbow", "brute", "charger", "banner", "elite_ranger"]
			for slot in ids.size():
				var actor = arena._spawn(arena.catalog.actor(ids[slot]), player.global_position + Vector3(-5.5 + slot * 2.2, 0, -4.2), 1)
				arena._register_enemy_brain(actor)
			arena.get_node("Camera").size = arena.room_presentation.camera_min_size
			for index in 4:
				await create_timer(0.45).timeout
				await _shot("lineup_%d" % index)
	quit(0)
