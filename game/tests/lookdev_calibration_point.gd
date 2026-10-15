extends SceneTree
## 点光、聚光灯的单位校准（见 lookdev_calibration.gd）：灯在灰卡正上方 4 米，能量 1，平方反比衰减。
const OUT := "E:/ShopGame/builds/lookdev/calib/"
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + "_godot.png")
	print("SHOT ", name)
func run() -> void:
	root.size = Vector2i(8, 8)
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
	camera.size = 0.05
	camera.position = Vector3(0, 1, 0)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.current = true
	var omni := OmniLight3D.new()
	omni.light_energy = 1.0
	omni.omni_attenuation = 2.0
	omni.omni_range = 100.0
	omni.position = Vector3(0, 4, 0)
	world.add_child(omni)
	await shot("point")
	omni.queue_free()
	var spot := SpotLight3D.new()
	spot.light_energy = 1.0
	spot.spot_attenuation = 2.0
	spot.spot_range = 100.0
	spot.spot_angle = 30.0
	spot.spot_angle_attenuation = 0.01
	world.add_child(spot)
	spot.look_at_from_position(Vector3(0, 4, 0), Vector3.ZERO, Vector3.FORWARD)
	await shot("spot")
	quit(0)
