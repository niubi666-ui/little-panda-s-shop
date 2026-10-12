extends SceneTree
## 动作检查用“姿势条”截图（图形模式运行，不是规则测试）。
## 用法：godot --path game --resolution 1600x1000 --script res://tests/visual_pass_poses.gd -- <glb路径> <片段,片段,...> [列数] [朝向角度] [输出名]
## 每个片段一行，从头到尾均匀取若干帧，用战斗镜头的角度渲染。
const OUT := "E:/ShopGame/builds/visual_pass/"
const SHADER := preload("res://presentation/shared/toon/character_toon.gdshader")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var packed: PackedScene = load(args[0])
	var clips: PackedStringArray = args[1].split(",")
	var columns := int(args[2]) if args.size() > 2 else 8
	var yaw := deg_to_rad(float(args[3])) if args.size() > 3 else 0.0
	var out_name: String = args[4] if args.size() > 4 else "poses"
	var spacing := Vector2(float(args[5]) if args.size() > 5 else 2.0, 2.6)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.5, 0.53)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.71, 0.93)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.9
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, 0.86, 0.7)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.basis = Basis.looking_at(-Vector3(-0.55, 0.62, -0.56).normalized(), Vector3.UP)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.58, 0.56, 0.56)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for row in clips.size():
		for column in columns:
			var model: Node3D = packed.instantiate()
			world.add_child(model)
			model.position = Vector3((column - (columns - 1) / 2.0) * spacing.x, 0, (row - (clips.size() - 1) / 2.0) * spacing.y)
			model.rotation.y = yaw
			for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.material_override = material
			var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
			# 片段名可带时间范围：attack_1@0.15:0.45
			var clip_name: String = clips[row].get_slice("@", 0)
			if not player.has_animation(clip_name):
				print("POSES missing clip ", clip_name)
				continue
			var from := 0.0
			var to := player.get_animation(clip_name).length
			if clips[row].contains("@"):
				from = float(clips[row].get_slice("@", 1).get_slice(":", 0))
				to = float(clips[row].get_slice("@", 1).get_slice(":", 1))
			player.play(clip_name)
			player.seek(lerpf(from, to, column / float(columns - 1)), true)
			player.pause()
		var label := Label3D.new()
		label.text = clips[row]
		label.font_size = 96
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(-(columns / 2.0) * spacing.x - 0.2, 0.1, (row - (clips.size() - 1) / 2.0) * spacing.y)
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var view_height := maxf(clips.size() * spacing.y * 0.7071 + 1.6, (columns + 0.8) * spacing.x / 1.6)
	camera.size = view_height
	camera.far = 200.0
	world.add_child(camera)
	camera.position = Vector3(0, 30, 30) + Vector3(0, 0.6, 0)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + out_name + ".png")
	print("SHOT ", out_name)
	quit(0)
