extends SceneTree
## Actual training UI and application integration, separate from the shared editor.
const ARENA = preload("res://rogue/scenes/training_arena.tscn")
var failures: Array[String] = []
var arena
var finished := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func run() -> void:
	create_timer(90.0).timeout.connect(func():
		if not finished:
			check(false, "build integration watchdog")
			finish())
	arena = ARENA.instantiate()
	root.add_child(arena)
	current_scene = arena
	await create_timer(.3).timeout
	check(arena.builds.is_choosing(), "initial three-choice opens")
	check(arena.builds.choice_panel.buttons.size() == 3, "three unique candidates")
	check(not arena.builds.choice_panel.buttons.has("split"), "split waits for projectile prerequisite")
	var snapshot: Dictionary = arena.builds.session.snapshot()
	var player_position: Vector3 = arena.player.position
	var enemy_position: Vector3 = arena.actors[1].position
	var cast: int = arena.player.runner.cast_id
	var size: float = arena.get_node("Camera").size
	for action in ["move_right", "combat_attack", "combat_dodge", "camera_zoom_in", "ui_cancel"]:
		_input_action(action, true)
	await create_timer(.15).timeout
	for action in ["move_right", "combat_attack", "combat_dodge", "camera_zoom_in", "ui_cancel"]:
		_input_action(action, false)
	check(arena.player.position == player_position and arena.actors[1].position == enemy_position, "modal freezes player and AI")
	check(arena.player.runner.cast_id == cast and arena.player.charges == arena.player.dodge.charges, "no attack or dodge leaks through modal")
	check(arena.get_node("Camera").size == size and arena.builds.is_choosing(), "modal blocks zoom and Escape")
	for action in ["ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down"]:
		for cycle in 5:
			_input_action(action, true)
			await process_frame
			_input_action(action, false)
			await process_frame
			check(root.gui_get_focus_owner() in arena.builds.choice_panel.buttons.values(), "keyboard focus confined to cards: " + action)
	TranslationServer.set_locale("zh_CN")
	_input_action("toggle_language", true)
	await process_frame
	_input_action("toggle_language", false)
	check(TranslationServer.get_locale().begins_with("en"), "language hotkey works during modal")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		arena.builds.refresh_text()
		arena.hud.refresh_text()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/build_choices_" + locale + "_" + str(root.size.x) + ".png")
		for button in arena.builds.choice_panel.buttons.values():
			check(root.get_visible_rect().encloses(button.get_global_rect()), "choice fits viewport " + locale)
		for label in arena.builds.choice_panel.find_children("*", "Label", true, false):
			check(not label.text.contains("{") and not label.text.begins_with("build."), "translated next-rank parameters " + locale)
	check(arena.builds.session.snapshot() == snapshot, "locale refresh preserves offer and RNG")
	# Freeze automatic simulation, while real GUI events still process.
	arena.set_physics_process(false)
	var first_id: String = arena.builds.choice_panel.buttons.keys()[0]
	await _click(arena.builds.choice_panel.buttons[first_id])
	check(not arena.builds.is_choosing(), "real card click closes committed choice")
	check(int(arena.builds.session.snapshot()["ranks"][first_id]) == 1, "click commits one rank")
	check(arena.player.runner.cast_id == cast, "card click does not queue attack")
	check(not arena.player._attack_queued, "card release cannot attack")
	# All ranks are reached through real offers; no arbitrary state writes or rerolls.
	var rank_total := 0
	for entry in arena.builds.catalog.entries(): rank_total += int(entry["max_rank"])
	for index in range(1, rank_total):
		await _click(arena.builds.status_panel.find_child("BuildTestOffer", true, false))
		check(arena.builds.is_choosing(), "test button opens actual offer")
		if not arena.builds.is_choosing(): break
		var selected: String = arena.builds.choice_panel.buttons.keys()[0]
		for priority in ["wave", "split", "chain", "power", "agility"]:
			if arena.builds.choice_panel.buttons.has(priority):
				selected = priority
				break
		await _click(arena.builds.choice_panel.buttons[selected])
	var ranks: Dictionary = arena.builds.session.snapshot()["ranks"]
	for entry in arena.builds.catalog.entries():
		check(ranks.has(entry["id"]) and int(ranks[entry["id"]]) == int(entry["max_rank"]), "all levels usable: " + entry["id"])
	await _click(arena.builds.status_panel.find_child("BuildTestOffer", true, false))
	check(not arena.builds.is_choosing(), "empty pool does not trap player")
	check(arena.builds.status_panel.find_child("BuildNotice", true, false).visible, "empty pool explains result")
	check(arena.player._build_move_scale > 1.0, "move build applied to motor")
	# Actual equipped runner -> cue -> projectile -> confirmed damage and chain.
	arena.brains.clear()
	arena.player.position = Vector3.ZERO
	arena.player.facing = Vector3.FORWARD
	arena.player.clear_intents()
	arena.player.cancel()
	arena.actors[1].position = Vector3(0, 0, -3)
	arena.actors[2].position = Vector3(1, 0, -4)
	var before: float = arena.actors[1].health.current + arena.actors[2].health.current
	var damage_events: Array = []
	arena.builds.damage_applied.connect(func(_source, _target, amount, origin): damage_events.append({"amount": amount, "origin": origin}))
	arena.player.request_attack()
	arena.player.step(.01)
	arena.player.runner.tick(arena.player.runner.ability.windup)
	arena.builds.step(.01)
	check(not arena.builds.runtime.projectiles().is_empty(), "attack cue launches equipped projectile")
	arena.builds.refresh(.01)
	var diagnostics: Dictionary = arena.builds.runtime.diagnostics()
	arena.builds.step(0.0)
	check(arena.builds.runtime.diagnostics() == diagnostics, "paused runtime stays unchanged")
	for frame in 18:
		arena.builds.step(.02)
		arena.builds.refresh(.02)
	var after: float = arena.actors[1].health.current + arena.actors[2].health.current
	check(after < before, "equipped derived effects cause real HP loss")
	var origins: Array = damage_events.map(func(event): return event["origin"])
	check("secondary_projectile" in origins and "chain" in origins, "projectile and chain connected to gameplay")
	TranslationServer.set_locale("zh_CN")
	arena.builds.refresh_text()
	arena.hud.refresh_text()
	arena._follow_camera()
	arena.hud.update_state(arena.player, arena.encounter, arena.catalog.waves().size(), arena.state, false)
	for view in arena.views: view.refresh(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/build_equipped.png")
	# Fresh run receives one reward per nonfinal wave, preserves ranks, retries reset.
	arena.free()
	arena = ARENA.instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await process_frame
	await _click(arena.builds.choice_panel.buttons.values()[0])
	var previous: Dictionary = arena.builds.session.snapshot()
	for enemy in arena.actors.duplicate():
		if enemy.team != 0: enemy.receive_hit(enemy.health.maximum)
	arena.builds.flush_offers()
	check(arena.builds.is_choosing(), "cleared wave awards a choice")
	check(int(arena.builds.session.snapshot()["offer_sequence"]) == int(previous["offer_sequence"]) + 1, "wave reward exactly once")
	await _click(arena.builds.choice_panel.buttons.values()[0])
	arena.encounter.tick(arena.catalog.wave_delay())
	check(arena.encounter.wave_index == 1, "next wave proceeds after selection")
	check(arena.builds.session.snapshot()["history"].size() == 2, "room cleanup retains chosen ranks")
	arena._retry()
	await arena._transition.completed
	arena = current_scene
	check(arena.builds.is_choosing() and arena.builds.session.snapshot()["ranks"].is_empty(), "retry resets ephemeral build and offers anew")
	check(arena.builds.runtime.diagnostics()["projectiles"] == 0, "retry clears projectiles")
	finish()
func _input_action(action: String, pressed: bool) -> void:
	var event: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	event.pressed = pressed
	Input.parse_input_event(event)
func _click(button: Button) -> void:
	await process_frame
	await process_frame
	var center := button.get_global_rect().get_center()
	root.warp_mouse(center)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.device = InputMap.action_get_events("combat_attack")[0].device
	event.position = root.get_final_transform() * center
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func finish() -> void:
	finished = true
	print("BUILD_TRAINING ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
