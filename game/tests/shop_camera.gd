extends SceneTree
## Wheel events, bounded smooth zoom and framing are exercised against the real scene.
const Settings = preload("res://presentation/shop_preview/shop_camera_settings.tres")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func settle() -> void:
	await create_timer(1.2).timeout

func wheel(button: MouseButton, count: int) -> void:
	for index in range(count):
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = true
		event.position = root.size * 0.5
		Input.parse_input_event(event)
		await process_frame
		event = InputEventMouseButton.new()
		event.button_index = button
		event.position = root.size * 0.5
		Input.parse_input_event(event)
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/shop_camera_" + label + ".png")

func run() -> void:
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	var camera: Camera3D = main.get_node("World/ShopInterior/ShopCamera")
	var player: CharacterBody3D = main.get_node("World/Player")
	check(is_equal_approx(camera.size, Settings.initial_size), "authored initial zoom")
	await capture("entrance")
	await wheel(MOUSE_BUTTON_WHEEL_UP, 1)
	await settle()
	check(absf(camera.size - (Settings.initial_size - Settings.zoom_step)) < 0.01, "wheel up zooms closer")
	await wheel(MOUSE_BUTTON_WHEEL_UP, 30)
	await settle()
	check(absf(camera.size - Settings.minimum_size) < 0.01, "zoom in clamp")
	await capture("close")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN, 40)
	await settle()
	check(absf(camera.size - Settings.maximum_size) < 0.01, "zoom out clamp")
	await capture("wide")
	await wheel(MOUSE_BUTTON_WHEEL_UP, 6)
	player.global_position = Vector3(0.15,0.1,-3.95)
	await settle()
	check(root.get_visible_rect().has_point(camera.unproject_position(player.global_position + Vector3.UP)), "rear counter remains in view")
	await capture("rear")
	var rotation := camera.global_rotation
	for corner in [Vector3(-3.55,0.1,2.45), Vector3(3.35,0.1,-3.95), Vector3(-3.05,0.1,-3.95), Vector3(3.1,0.1,2.45)]:
		player.global_position = corner
		await settle()
		check(root.get_visible_rect().has_point(camera.unproject_position(player.global_position + Vector3.UP)), "player visible at " + str(corner))
	check(camera.global_rotation.is_equal_approx(rotation), "follow keeps movement reference orientation")
	print("SHOP_CAMERA ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
