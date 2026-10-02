extends SceneTree

func _initialize() -> void:
	call_deferred("capture_study")

func capture_study() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var lighting: Node3D = main.get_node("World/ShopInterior/Lighting")
	var env: Environment = lighting.get_node("WorldEnvironment").environment
	env.background_color = Color(0.32,0.40,0.46)
	env.ambient_light_energy = 0.42
	env.tonemap_exposure = 1.35
	for light in lighting.get_children():
		if light is DirectionalLight3D:
			light.light_energy = 3.4
			light.light_angular_distance = 1.1
		if light is OmniLight3D and str(light.name).begins_with("Lantern"):
			light.light_energy *= 0.75
	for i in range(60):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/shop_lighting_a.png")
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.1
	env.sdfgi_energy = 1.2
	for i in range(90):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/shop_lighting_b.png")
	print("LIGHT_STUDY_DONE")
	quit()
