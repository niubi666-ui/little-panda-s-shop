extends SceneTree
## 色彩校准（见 lookdev_calibration.gd）：几块彩色卡片只受太阳照亮，AgX 色调映射，与 Cycles 对比。
const OUT := "E:/ShopGame/builds/lookdev/calib/"
const COLOURS := {"red": Color(0.5, 0.05, 0.03), "green": Color(0.08, 0.2, 0.03), "olive": Color(0.18, 0.17, 0.04), "violet": Color(0.15, 0.08, 0.5), "pink": Color(0.6, 0.2, 0.3), "dkgreen": Color(0.03, 0.06, 0.02)}
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var contrast := float(args[0]) if args.size() > 0 else 1.5
	var tag: String = args[1] if args.size() > 1 else "godot"
	root.size = Vector2i(8, 8)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = pow(2.0, 0.25)
	environment.tonemap_agx_contrast = contrast
	for i in range(2, args.size()):
		var pair := args[i].split("=")
		environment.set(pair[0], str_to_var(pair[1]))
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20, 20)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.metallic_specular = 0.0
	plane.material_override = material
	world.add_child(plane)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.05
	camera.position = Vector3(0, 1, 0)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.light_energy = 4.2 / PI
	world.add_child(sun)
	sun.look_at_from_position(Vector3(0, 10, 0), Vector3.ZERO, Vector3.FORWARD)
	for name in COLOURS:
		material.albedo_color = COLOURS[name].linear_to_srgb()
		await shot("col_%s_%s" % [name, tag])
	quit(0)
