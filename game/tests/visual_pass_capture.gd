extends SceneTree
## 视觉检查用截图工具（图形模式运行，不是规则测试）。
## 用法：godot --path game --script res://tests/visual_pass_capture.gd -- <模式> [房间presentation路径]
##   overview  进入训练场后隐藏界面截一张；再把镜头拉到最远截一张
##   combat    把一个敌人摆到玩家面前，打一套三连 + 重击，逐帧输出序列
##   lineup    把每种敌人各放一个排在玩家面前，截近景
const OUT := "E:/ShopGame/builds/visual_pass/"

func _initialize() -> void:
	call_deferred("run")
	# 脚本中途出错时 run 不会走到 quit，别让进程挂着
	create_timer(150.0).timeout.connect(func() -> void: quit(2))

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
	if args.size() > 1 and args[1].begins_with("res://"): arena.room_presentation = load(args[1])
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
			arena._set_zoom(arena.room_presentation.camera_max_size)
			await create_timer(0.2).timeout
			await _shot("overview_far")
			arena._set_zoom(arena.room_presentation.camera_min_size)
			await create_timer(0.2).timeout
			await _shot("overview_near")
			arena._set_zoom(arena.room_presentation.camera_size)
			var spots := {"south": Vector3(0.5, 0.12, 7.0), "north": Vector3(-5.5, 0.12, -6.0), "east": Vector3(8.0, 0.12, 0.0)}
			for spot in spots:
				arena.player.global_position = spots[spot]
				await create_timer(1.6).timeout
				await _shot("overview_" + spot)
		"perf":
			# 1080p、关垂直同步，报告帧率和绘制量
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			root.size = Vector2i(1920, 1080)
			# 试验开关：perf 之后可跟 env.属性=值 / sun.属性=值 / vp.属性=值 / ps.设置路径=值
			var env_node: WorldEnvironment = arena.find_children("*", "WorldEnvironment", true, false)[0]
			var sun_node: DirectionalLight3D = arena.find_children("*", "DirectionalLight3D", true, false)[0]
			for index in range(1, args.size()):
				var pair: PackedStringArray = args[index].split("=")
				var target: String = pair[0].get_slice(".", 0)
				var property: String = pair[0].substr(target.length() + 1)
				var value = str_to_var(pair[1])
				match target:
					"env": env_node.environment.set(property, value)
					"sun": sun_node.set(property, value)
					"vp": root.set(property, value)
					"ps": RenderingServer.call(property, value)
					"win": DisplayServer.window_set_mode(int(value))
					"hide":
						for node in arena.find_children(property, "", true, false): node.visible = false
			await create_timer(4.0).timeout
			for sample in 3:
				await create_timer(1.5).timeout
				print("CAPTURE fps=%d primitives=%d draw_calls=%d video_mem_mb=%d" % [Engine.get_frames_per_second(),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576])
			await _shot("perf_1080p")
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
			arena._set_zoom(arena.room_presentation.camera_min_size)
			for index in 4:
				await create_timer(0.45).timeout
				await _shot("lineup_%d" % index)
	quit(0)
