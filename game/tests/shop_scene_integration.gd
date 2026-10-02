extends SceneTree
## Real scene acceptance: captures rendered frames and exercises input and interaction.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	check(error == OK, "capture " + path)

func key(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run_checks() -> void:
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await ticks(90)
	var player: CharacterBody3D = main.get_node("World/Player")
	var controller: Node = main.controller
	var shop: Node3D = main.get_node("World/ShopInterior")
	check(shop.find_children("*", "MeshInstance3D", true, false).size() >= 790, "original geometry plus rear stock and continuous ground present")
	var island: Node3D = shop.get_node("Furnishings/central_merchandise_island_hd")
	check(island.has_node("Body") and island.has_node("InteractionPoint") and island.has_node("Display lantern glow"), "island owns collision, interaction and light")
	var anchor: Node3D = island.get_node("InteractionPoint")
	var light: Node3D = island.get_node("Display lantern glow")
	var original_anchor := anchor.global_position
	var original_light := light.global_position
	island.position.x += 1.0
	check(anchor.global_position.is_equal_approx(original_anchor+Vector3.RIGHT) and light.global_position.is_equal_approx(original_light+Vector3.RIGHT), "moving furniture carries interaction and lighting")
	island.position.x -= 1.0
	check(shop.get_node("Furnishings/curio_bench_plank").has_node("curio_bench_leg"), "bench parts remain one movable assembly")
	check(player.is_on_floor(), "player settles onto floor")
	check(not controller.try_interact(), "no interaction from distant spawn")
	await capture("E:/ShopGame/builds/shop_overview.png")
	if "--capture-only" in OS.get_cmdline_user_args():
		quit(0 if failures.is_empty() else 1)
		return
	var start := player.global_position
	Input.action_press("move_right")
	await ticks(15)
	Input.action_release("move_right")
	check(player.global_position.distance_to(start) > 0.2, "WASD moves character")
	var anim: AnimationPlayer = player.get_node("Visual/AnimationPlayer")
	check(anim.current_animation == &"run", "movement plays run")
	await ticks(2)
	check(anim.current_animation == &"idle", "stopping plays idle")
	player.global_position = Vector3(-0.1,0.1,1.98)
	await ticks(10)
	check(str(controller.get_nearby_instance_id()).contains("central_merchandise"), "potion station selected")
	await capture("E:/ShopGame/builds/shop_interaction_prompt.png")
	await key("interact")
	check(controller.is_interaction_open(), "F opens interaction placeholder")
	start = player.global_position
	Input.action_press("move_right")
	await ticks(12)
	Input.action_release("move_right")
	check(player.global_position.distance_to(start) < 0.03, "modal blocks movement")
	await capture("E:/ShopGame/builds/shop_interaction_modal.png")
	await key("ui_cancel")
	check(not controller.is_interaction_open(), "Escape closes placeholder")
	Input.action_press("move_forward")
	await ticks(25)
	Input.action_release("move_forward")
	check(player.global_position.z > 1.65, "potion island blocks player")
	player.global_position = Vector3(0.45,0.1,-1.64)
	await ticks(10)
	check(str(controller.get_nearby_instance_id()).contains("main_sales_counter"), "counter station selected")
	await key("interact")
	check(controller.is_interaction_open(), "counter opens placeholder")
	await key("ui_cancel")
	await key("toggle_language")
	check(TranslationServer.get_locale().begins_with("en"), "language toggles to English")
	await capture("E:/ShopGame/builds/shop_english.png")
	var report := {"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"fps_end":Engine.get_frames_per_second(),"draw_calls_end":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects_end":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	var file := FileAccess.open("E:/ShopGame/builds/shop_acceptance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SHOP_INTEGRATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
