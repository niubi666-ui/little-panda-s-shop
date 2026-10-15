extends SceneTree
## 光照单位校准：一块灰卡分别只受太阳光、只受天光照亮，和 Blender Cycles 的同名渲染对比
## （source_assets/lookdev_forest_v1 的对照流程用）。图形模式运行，输出 builds/lookdev/calib/*_godot.png。
const OUT := "E:/ShopGame/builds/lookdev/calib/"

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + "_godot.png")
	print("SHOT ", name)

func run() -> void:
	root.size = Vector2i(64, 64)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20, 20)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.18, 0.18).linear_to_srgb()
	material.roughness = 1.0
	material.metallic_specular = 0.0
	plane.material_override = material
	world.add_child(plane)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0, 5, 0)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.light_energy = 4.2 / PI
	world.add_child(sun)
	sun.look_at_from_position(Vector3(0, 10, 0), Vector3.ZERO, Vector3.FORWARD)
	await shot("sun")
	sun.visible = false
	environment.ambient_light_color = Color(0.5, 0.5, 0.5).linear_to_srgb()
	await shot("sky")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.5, 0.5, 0.5).linear_to_srgb()
	sky_material.sky_horizon_color = sky_material.sky_top_color
	sky_material.ground_bottom_color = sky_material.sky_top_color
	sky_material.ground_horizon_color = sky_material.sky_top_color
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	await shot("skymat")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	environment.background_mode = Environment.BG_COLOR
	sun.visible = true
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = pow(2.0, 0.25)
	for contrast in [1.0, 1.25, 1.5]:
		environment.tonemap_agx_contrast = contrast
		for value in [0.05, 0.18, 0.5, 0.9]:
			material.albedo_color = Color(value, value, value).linear_to_srgb()
			await shot("agx%d_%03d" % [int(contrast * 100), int(value * 100)])
	quit(0)
