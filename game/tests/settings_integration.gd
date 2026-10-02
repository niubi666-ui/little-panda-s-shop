extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func capture(path: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var shop = load("res://app/main.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	await create_timer(0.5).timeout
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(paused and shop.pause_menu.panel.visible, "Shop ESC did not open settings")
	await capture("E:/ShopGame/builds/settings_shop.png")
	shop.pause_menu.panel.actions.set_language("en")
	shop.pause_menu.close()
	check(not paused, "Shop remains paused")
	shop.queue_free()
	await process_frame
	var battle = load("res://app/combat_training.tscn").instantiate()
	battle.build_choices_enabled = false
	root.add_child(battle)
	current_scene = battle
	await create_timer(0.3).timeout
	Input.parse_input_event(escape)
	await process_frame
	check(paused and battle.pause_menu.panel.visible, "Combat ESC did not open settings")
	var player_position: Vector3 = battle.player.position
	var health: float = battle.player.health.current
	Input.action_press("move_forward")
	await capture("E:/ShopGame/builds/settings_battle.png")
	Input.action_release("move_forward")
	check(battle.player.position == player_position and battle.player.health.current == health, "Gameplay advanced while paused")
	battle.pause_menu.close()
	check(not paused, "Combat remains paused")
	var position_before: Vector3 = battle.player.position
	Input.action_press("move_forward")
	await create_timer(0.15).timeout
	Input.action_release("move_forward")
	check(battle.player.position != position_before, "Gameplay did not resume")
	battle.builds.request_test_offer()
	check(battle.builds.is_choosing(), "Test offer did not open")
	Input.parse_input_event(escape)
	await process_frame
	check(paused and battle.pause_menu.panel.visible, "ESC blocked by build choice modal")
	battle.pause_menu.close()
	check(not paused and battle.builds.is_choosing(), "Closing settings discarded build choice")
	battle.queue_free()
	await process_frame
	await process_frame
	print("SETTINGS_INTEGRATION ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
