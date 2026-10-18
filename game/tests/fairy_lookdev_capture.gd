extends SceneTree
## 画面对照截图：与 Blender 的 source_assets/environments/forest/tools/render_game_views.py 使用同样的机位
## （视图名一致），隐藏界面、冻结战斗，只拍场景本身，用来和 Cycles 渲染图逐张对比。
## 图形模式运行（不能加 --headless）：
##   godot --path game --script res://tests/fairy_lookdev_capture.gd -- [视图,视图] [actors] [fps] [tag=名字] [env.属性=值 ...]
## 写 fps 则最后在 1080p 下测帧率（打印 FPS 一行）。写 pan 则镜头平移约 1.7 秒，每帧存到
## builds/lookdev/<名字>/NNN.png 后退出（看运动中草地是否闪烁）；配合 --fixed-fps 60 保证每帧时间步一样。room=res://…/presentation.tres 换用别的房间（例如第一版，做前后对比）。
## 视图缺省为全部；写 actors 则保留角色（拍战斗画面用）。输出到 builds/lookdev/<视图>_<名字>.png（名字缺省 godot）。
const OUT := "E:/ShopGame/builds/lookdev/"
# 镜头位置与注视点（Godot 坐标），与 render_game_views.py 的 VIEWS 相同
const VIEWS := {
	"game": [Vector3(0.0, 12.1, 20.9), Vector3(0.0, 0.7, 3.3)],
	"ruin": [Vector3(0.0, 12.1, 11.1), Vector3(0.0, 0.7, -6.5)],
	"far": [Vector3(0.0, 16.66, 23.14), Vector3(0.0, 0.7, -1.5)],
	"bridge": [Vector3(0.5, 12.1, 22.6), Vector3(0.5, 0.7, 5.0)],
	"hero": [Vector3(3.5, 5.2, 21.5), Vector3(0.0, 0.8, 4.0)],
	"top": [Vector3(0.0, 46.0, 0.5), Vector3(0.0, 0.0, 0.0)],
	# 樱花溪谷：玩家在出生点（z=2.5）、走到北边瀑布附近（x=-3, z=-6）时的镜头
	"play": [Vector3(0.0, 12.1, 18.6), Vector3(0.0, 0.7, 1.0)],
	"north": [Vector3(-3.0, 12.1, 10.1), Vector3(-3.0, 0.7, -7.5)],
	# 神木圣坛：拉远看全景（Boss 场）
	"overview": [Vector3(0.0, 17.5, 21.0), Vector3(0.0, 0.7, -3.0)],
}
const SIZE := Vector2i(1280, 800)
const PAN_SPEED_MPS := 5.0      # 平移速度：接近角色奔跑速度

func _initialize() -> void:
	call_deferred("run")
	create_timer(240.0).timeout.connect(func() -> void: quit(2))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var names: Array = VIEWS.keys()
	var keep_actors := false
	var measure := false
	var pan := false
	var overrides: Array[String] = []
	var tag := "godot"
	var room_path := ""
	for arg in args:
		if arg == "actors": keep_actors = true
		elif arg == "fps": measure = true
		elif arg == "pan": pan = true
		elif arg.begins_with("tag="): tag = arg.substr(4)
		elif arg.begins_with("room="): room_path = arg.substr(5)
		elif arg.contains("="): overrides.append(arg)
		elif not arg.is_empty(): names = Array(arg.split(","))
	root.size = SIZE
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	if not room_path.is_empty(): arena.room_presentation = load(room_path)
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	var room: Node = arena.room
	# 只拍场景：关掉战斗逻辑和所有界面层（房间自己的画面压暗层除外）
	arena.set_physics_process(false)
	for layer in arena.find_children("*", "CanvasLayer", true, false):
		if not room.is_ancestor_of(layer): layer.visible = false
	if not keep_actors:
		# 角色、预警、投射物、技能特效都挂在训练场根节点下：除房间和镜头外一律藏起
		for child in arena.get_children():
			if child is Node3D and child != room and child.name != "Camera": child.visible = false
	var camera: Camera3D = arena.get_node("Camera")
	var environment: Environment = room.find_children("*", "WorldEnvironment", true, false)[0].environment
	var sun: DirectionalLight3D = room.find_children("*", "DirectionalLight3D", true, false)[0]
	# 试验开关（不改文件）：env.属性=值、sun.属性=值、cam.属性=值、vp.属性=值、
	# node:房间内节点路径:属性=值、fol:植被材质名或*:着色器参数=值、mat:材质名或*:着色器参数=值（地面、水）
	for item in overrides:
		var pair := item.split("=")
		var value = str_to_var(pair[1])
		if pair[0].contains(":"):
			var parts := pair[0].split(":")
			match parts[0]:
				"node": room.get_node(parts[1]).set(parts[2], value)
				"nodes":
					# nodes:名字通配符:属性=值，作用于房间内所有同名节点
					var matched := room.find_children(parts[1], "", true, false)
					print("OVERRIDE ", parts[1], " matched ", matched.size())
					for node in matched: node.set(parts[2], value)
				"fol":
					for material in room._converted.values():
						if parts[1] == "*" or material.resource_name == parts[1]: material.set_shader_parameter(parts[2], value)
				"mat":
					for material in [room.ground_material, room.water_material]:
						if parts[1] == "*" or material.resource_path.get_file().begins_with(parts[1]): material.set_shader_parameter(parts[2], value)
			continue
		var target: String = pair[0].get_slice(".", 0)
		var property: String = pair[0].substr(target.length() + 1)
		match target:
			"env": environment.set(property, value)
			"sun": sun.set(property, value)
			"cam": camera.set(property, value)
			"vp": root.set(property, value)
	if pan:
		# 镜头沿游戏镜头的方向平移（相当于角色奔跑时镜头跟随），配合 --write-movie 录下每一帧，
		# 用来看草地在运动中闪不闪。先停 1 秒让体积雾和时域抗锯齿稳定。
		var start: Array = VIEWS["game"]
		var offset: Vector3 = start[0] - start[1]
		var from := Vector3(-4.0, 0.7, 2.0)
		var to := Vector3(4.0, 0.7, -1.0)
		camera.position = from + offset
		camera.look_at(from)
		await create_timer(1.0).timeout
		var folder := OUT + tag + "/"
		DirAccess.make_dir_recursive_absolute(folder)
		var travel := 0.0
		var duration := from.distance_to(to) / PAN_SPEED_MPS
		var index := 0
		while travel < duration:
			travel += 1.0 / 60.0
			var at := from.lerp(to, travel / duration)
			camera.position = at + offset
			camera.look_at(at)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + "%03d.png" % index)
			index += 1
		print("PAN done")
		quit(0)
		return
	for name in names:
		var view: Array = VIEWS[name]
		camera.position = view[0]
		camera.look_at(view[1])
		# 体积雾、屏幕空间光照需要几帧收敛
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + name + "_" + tag + ".png")
		print("SHOT ", name)
	if measure:
		# 测速：1920×1080、关垂直同步，在最后一个视图下数 4 秒的帧
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.size = Vector2i(1920, 1080)
		await process_frame
		# 改窗口大小会让房间重设渲染缩放：vp. 开关在这之后再设一次
		for item in overrides:
			if item.begins_with("vp."):
				var pair := item.split("=")
				root.set(pair[0].substr(3), str_to_var(pair[1]))
		await create_timer(2.0).timeout
		var frames := Engine.get_frames_drawn()
		var started := Time.get_ticks_usec()
		await create_timer(4.0).timeout
		var seconds := (Time.get_ticks_usec() - started) / 1000000.0
		print("CAPTURE FPS %.1f primitives=%d draw_calls=%d" % [(Engine.get_frames_drawn() - frames) / seconds,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("CAPTURE fps=%d primitives=%d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit(0)
