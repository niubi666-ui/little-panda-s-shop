extends SceneTree
## Real physics route from the entrance, through both counter approaches, without teleporting.
var failures: Array[String] = []
var player: CharacterBody3D
var camera: Camera3D
var controller: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func release_movement() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)

func walk_to(destination: Vector3) -> void:
	var right := camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	for tick in range(600):
		var direction := destination - player.global_position
		direction.y = 0
		if direction.length() < 0.09:
			release_movement()
			return
		direction = direction.normalized()
		release_movement()
		var horizontal := direction.dot(right)
		var vertical := direction.dot(forward)
		Input.action_press("move_right" if horizontal > 0 else "move_left", absf(horizontal))
		Input.action_press("move_forward" if vertical > 0 else "move_back", absf(vertical))
		await physics_frame
	release_movement()
	check(false, "blocked route to %s, reached %s" % [destination, player.global_position])

func key(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	for tick in range(60):
		await physics_frame
	player = main.get_node("World/Player")
	camera = main.get_node("World/ShopInterior/ShopCamera")
	controller = main.controller
	for waypoint in [Vector3(2.7,0,2.45), Vector3(2.7,0,-1.55), Vector3(3.4,0,-1.55), Vector3(3.4,0,-3.95), Vector3(0.15,0,-3.95)]:
		await walk_to(waypoint)
	await physics_frame
	check(str(controller.get_nearby_instance_id()).contains("main_sales_counter"), "counter selected from behind")
	await key("interact")
	check(controller.is_interaction_open(), "F opens counter from behind")
	await key("ui_cancel")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/shop_counter_rear.png")
	for waypoint in [Vector3(-3.05,0,-3.95), Vector3(-3.05,0,-1.55), Vector3(-1.8,0,-1.55)]:
		await walk_to(waypoint)
	await physics_frame
	check(str(controller.get_nearby_instance_id()).contains("main_sales_counter"), "counter selected from front left")
	var targets := get_nodes_in_group("shop_interaction_points")
	check(targets.size() == 9, "nine distinct furniture interactions")
	for target: Node3D in targets:
		# Separate fixture test: place the player just outside each authored surface.
		var approach := target.global_position
		var id := str(target.get_meta("instance_id"))
		if id.contains("right_") and not id.contains("relics"):
			approach.x -= 0.45
		elif id.contains("window"):
			approach.x += 0.45
		else:
			approach.z += 0.45
		approach.y = 0.1
		player.global_position = approach
		player.velocity = Vector3.ZERO
		for tick in range(8):
			await physics_frame
		check(str(controller.get_nearby_instance_id()) == id, "select " + id)
		await key("interact")
		check(controller.is_interaction_open(), "F opens " + id)
		await key("ui_cancel")
	print("SHOP_ACCESSIBILITY ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
