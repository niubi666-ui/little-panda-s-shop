extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(.3).timeout
	var attack := InputEventAction.new()
	attack.action = "combat_attack"
	attack.pressed = true
	Input.parse_input_event(attack.duplicate())
	await physics_frame
	await physics_frame
	check(arena.player.runner.cast_id > 0, "attack input reaches runner")
	attack.pressed = false
	Input.parse_input_event(attack.duplicate())
	var dodge := InputEventAction.new()
	dodge.action = "combat_dodge"
	dodge.pressed = true
	Input.parse_input_event(dodge.duplicate())
	await physics_frame
	await physics_frame
	check(arena.player.charges < arena.player.dodge.charges, "dodge input consumes charge")
	dodge.pressed = false
	Input.parse_input_event(dodge.duplicate())
	arena.paused = true
	check(arena.actors.size() == 3, "first wave spawned")
	check(InputMap.action_get_events("combat_training")[0].physical_keycode == KEY_F6, "F6 binding")
	check(InputMap.action_get_events("combat_dodge")[0].physical_keycode == KEY_SHIFT, "Shift binding")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		arena.hud.refresh_text()
		arena.hud.update_state(arena.player, arena.encounter, arena.catalog.waves().size(), arena.state, arena.paused)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/combat_" + locale + ".png")
		for button in arena.hud.find_children("*", "Button", true, false):
			check(root.get_visible_rect().encloses(button.get_global_rect()), "HUD button in viewport: " + locale)
	# Capture an actual telegraph from the same ability used by the resolver.
	arena.actors[1].position = arena.player.position + Vector3(1, 0, -2)
	arena.actors[1].facing = (arena.player.position - arena.actors[1].position).normalized()
	arena.actors[1].runner.start(arena.actors[1].attacks[0], arena.actors[1].facing)
	arena.actors[1].runner.tick(.1)
	arena.views[1].refresh()
	TranslationServer.set_locale("zh_CN")
	arena.hud.refresh_text()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/combat_telegraph.png")
	var position: Vector3 = arena.actors[1].position
	await create_timer(.2).timeout
	check(arena.actors[1].position == position, "pause freezes enemies")
	# Drive real actor timelines/resolver through the complete authored encounter.
	arena.set_physics_process(false)
	arena.player.step(arena.catalog.dodge().duration)
	for wave in arena.catalog.waves().size():
		var enemies: Array = arena.actors.duplicate()
		for enemy in enemies:
			if enemy.team == 0 or not enemy.health.alive(): continue
			arena.player.position = enemy.position + Vector3(0, 0, 1)
			arena.player.facing = Vector3.FORWARD
			var attempts := 0
			while enemy.health.alive() and attempts < 20:
				arena.player.runner.cooldown = 0
				arena.player.runner.cancel()
				arena.player.request_attack()
				arena.player.step(.01)
				arena.player.runner.tick(arena.player.runner.ability.windup)
				arena.resolver.resolve(arena.player, [enemy])
				attempts += 1
			check(not enemy.health.alive(), "real attacks kill enemy")
		if wave + 1 < arena.catalog.waves().size():
			check(arena.state != "victory", "no early room clear")
			arena.encounter.tick(arena.catalog.wave_delay())
	check(arena.state == "victory", "full encounter reaches victory")
	arena.free()
	arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.player.receive_hit(arena.player.health.maximum)
	check(arena.state == "defeat", "death enters defeat")
	for actor in arena.actors: check(not actor.runner.busy(), "end cancels all casts")
	arena.free()
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(.3).timeout
	main._enter_training()
	await main._transition.completed
	check(current_scene.scene_file_path == "res://app/combat_training.tscn", "shop enters combat")
	current_scene._retry()
	await current_scene._transition.completed
	check(current_scene.player.health.current == current_scene.player.health.maximum, "retry resets health")
	current_scene._return()
	await current_scene._transition.completed
	check(current_scene.scene_file_path == "res://app/main.tscn", "return restores shop")
	print("COMBAT_TRAINING ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)


