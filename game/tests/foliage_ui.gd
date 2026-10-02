extends SceneTree
var failures: Array[String] = []
var main: Node
var ui: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func settle() -> void:
	await create_timer(0.3).timeout

func key(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await settle()

func click(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await process_frame
			await process_frame
		ancestor = ancestor.get_parent()
	# Input.parse_input_event uses window pixels; Control rects use stretched canvas coordinates.
	var point := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		await process_frame
	await settle()

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/foliage_"+name+".png")
	for node in ui.find_children("*", "Control", true, false):
		if node is BaseButton and node.is_visible_in_tree():
			check(root.get_visible_rect().encloses(node.get_global_rect()), "button fits viewport: " + node.name)

func run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	ui = main.get_node("UIRoot/FoliageUI")
	await screenshot("hud")
	await key("ui_inventory")
	check(ui.current_page() == "inventory", "B opens inventory")
	var player: CharacterBody3D = main.get_node("World/Player")
	var before := player.position
	Input.action_press("move_right")
	await settle()
	Input.action_release("move_right")
	check(player.position.distance_to(before) < 0.03, "catalog blocks character movement")
	var camera: Camera3D = main.get_node("World/ShopInterior/ShopCamera")
	var initial_size := camera.size
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = root.get_final_transform() * (root.get_visible_rect().size / 2)
	Input.parse_input_event(wheel)
	await process_frame
	wheel = wheel.duplicate()
	wheel.pressed = false
	Input.parse_input_event(wheel)
	await settle()
	check(is_equal_approx(initial_size, camera.size), "catalog consumes wheel instead of zooming shop")
	await click(ui.find_child("Item_crystal",true,false))
	check(ui._selected == "crystal", "mouse selects inventory item")
	await screenshot("inventory")
	await key("toggle_language")
	check(TranslationServer.get_locale().begins_with("en"), "L switches locale with window open")
	await screenshot("inventory_en")
	await key("toggle_language")
	await key("ui_orders")
	check(ui.find_child("AcceptOrder",true,false).disabled, "accept requires a selected order")
	await click(ui.find_child("Order_guard",true,false))
	check(ui._selected == "guard", "mouse selects single order card")
	await key("ui_accept")
	check(ui._selected.is_empty(), "keyboard can deselect order without losing focus")
	await key("ui_accept")
	check(ui._selected == "guard", "keyboard can reselect order")
	await click(ui.find_child("AcceptOrder",true,false))
	check(ui._commission._notice.text == str(TranslationServer.translate("ui.commission.accept_pending")), "accept shows preview feedback")
	await click(ui.find_child("DepartWithoutOrder",true,false))
	check(ui._commission._notice.text == str(TranslationServer.translate("ui.commission.depart_pending")), "independent departure shows preview feedback")
	await screenshot("orders")
	await key("toggle_language")
	await screenshot("orders_en")
	await key("toggle_language")
	await key("ui_decoration")
	var decorating = main.get_node("ShopDecoration")
	check(decorating._active and ui.is_modal_open(), "R opens real decorating module")
	check(is_instance_valid(decorating._grid), "room geometry enables placement")
	await screenshot("decoration")
	await key("toggle_language")
	await screenshot("decoration_en")
	await key("toggle_language")
	await key("ui_cancel")
	check(ui.current_page().is_empty(), "Escape closes catalog")
	await key("ui_cancel")
	check(ui.current_page() == "settings", "Escape opens settings from shop")
	await screenshot("settings")
	await key("ui_cancel")
	player.position = Vector3(0.15,0.1,-1.64)
	await settle()
	await key("interact")
	check(main.controller.is_interaction_open(), "furniture interaction retained")
	await screenshot("interaction")
	await key("ui_cancel")
	check(not main.controller.is_interaction_open() and ui.current_page().is_empty(), "Escape closes furniture without opening settings")
	print("FOLIAGE_UI ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
