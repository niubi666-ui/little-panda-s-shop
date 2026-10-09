extends SceneTree
const Encounter = preload("res://rogue/training_encounter.gd")
var arena
var failures: Array[String] = []
var loot_count := 0
var wave_rewards := 0
var finished := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func button(id: String): return arena.training_tools.panel.find_child(id, true, false)
func tick_ui() -> void:
	arena.training_tools.refresh()
	await process_frame
	await process_frame
func live_enemies() -> Array:
	return arena.actors.filter(func(a): return a.team != arena.player.team and a.health.alive())
func kill_enemies() -> void:
	for actor in live_enemies(): actor.receive_hit(actor.health.maximum)
func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
func run() -> void:
	create_timer(120.0).timeout.connect(func():
		if not finished:
			check(false, "training tools timeout")
			finish())
	var path := "res://app/combat_training.tscn" if OS.get_cmdline_user_args().has("--ordinary") else "res://app/mechanism_slice.tscn"
	arena = load(path).instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await tick_ui()
	check(arena.builds.is_choosing() and button("TrainingToolsToggle").disabled, "choice modal blocks training toolbar")
	check(not arena.training_tools.add_wave() and arena.training_tools.extra_wave_count == 0, "direct command blocked during choice")
	arena.builds.choice_panel.buttons.values()[0].pressed.emit()
	await tick_ui()
	check(not button("TrainingToolsToggle").disabled, "toolbar restores after real card choice")
	check(not button("TrainingModifiersPanel").visible, "tools start collapsed")
	await click(button("TrainingToolsToggle"))
	check(button("TrainingModifiersPanel").visible, "viewport click opens modifier panel")
	var cast_before: int = arena.player.runner.cast_id
	await click(button("TrainingPlayerInvincible"))
	check(arena.training_tools.player_invincible and arena.player.receive_hit(arena.player.health.maximum) == 0.0, "UI player immunity rejects lethal damage")
	await click(button("TrainingEnemiesInvincible"))
	check(arena.training_tools.enemies_invincible, "UI enemy immunity enabled")
	for actor in live_enemies(): check(actor.receive_hit(actor.health.maximum) == 0.0, "all existing enemies immune")
	check(arena.player.runner.cast_id == cast_before, "clicking modifier controls does not attack")
	var query: Callable = arena.training_tools._spawn_clear
	var empty_before: int = arena.encounter.remaining()
	arena.training_tools._spawn_clear = func(_point, _id, _reserved): return false
	check(not arena.training_tools.add_wave() and arena.encounter.remaining() == empty_before and arena.training_tools.extra_wave_count == 0, "no-space rejection spawns nothing and preserves sequence")
	arena.training_tools._spawn_clear = query
	var original_plan: Dictionary = arena.encounter_plan.duplicate(true)
	var build_before: Dictionary = arena.builds.session.snapshot()
	var old_count := live_enemies().size()
	var old_handles: Array = live_enemies().map(func(a): return a.handle)
	arena.enemy_loot_ready.connect(func(_spawn, _id, _drops): loot_count += 1)
	arena.encounter.wave_completed.connect(func(_index): wave_rewards += 1)
	await click(button("TrainingAddWave"))
	check(live_enemies().size() > old_count, "UI adds a legal wave alongside existing enemies")
	check(arena.training_tools.extra_wave_count == 1, "successful addition advances only training sequence")
	check(arena.encounter_plan == original_plan and arena.builds.session.snapshot() == build_before, "extra wave preserves encounter plan and reward RNG/build")
	check(old_handles.all(func(handle): return live_enemies().any(func(a): return a.handle == handle)), "existing wave not replaced")
	for actor in live_enemies(): check(actor.invulnerable(), "new wave inherits enemy immunity")
	check(arena.encounter.remaining() == live_enemies().size(), "encounter tracks supplemental enemies")
	check(arena.enemy_runtime.brains.size() == live_enemies().size(), "supplemental enemies have active AI")
	for i in live_enemies().size():
		var actor = live_enemies()[i]
		check(arena.room_props.allows_training_spawn(actor.global_position, arena.Style.actor_presentations[actor.definition.id].body_shape.radius), "new position on authored navigable floor")
		for j in range(i + 1, live_enemies().size()):
			var other = live_enemies()[j]
			var sum_radius: float = arena.Style.actor_presentations[actor.definition.id].body_shape.radius + arena.Style.actor_presentations[other.definition.id].body_shape.radius
			check(actor.position.distance_to(other.position) > sum_radius, "enemies do not spawn overlapping")
	# Bounded repeated additions; no partial mutation on rejection.
	for attempt in 12:
		var previous: int = arena.training_tools.extra_wave_count
		var count := live_enemies().size()
		var added: bool = arena.training_tools.add_wave()
		if not added:
			check(arena.training_tools.extra_wave_count == previous and live_enemies().size() == count, "failed addition is atomic")
			break
	check(live_enemies().size() <= int(arena.enemy_catalog.encounters.training_tools.max_alive_enemies), "configured population cap enforced")
	# Hiding UI preserves actual rule state and a permanent route to restore menus.
	var popup: PopupMenu = button("TrainingVisibilityMenu").get_popup()
	popup.id_pressed.emit(arena.training_tools.ToolsPanel.HIDE_ALL_ID)
	await tick_ui()
	for panel in [arena.builds.status_panel, arena.hud.effect_picker, arena.hud.encounter_panel, arena.room_props.hud]: check(not panel.visible, "all menu panels hidden")
	check(button("TrainingToolbar").is_visible_in_tree() and arena.player.invulnerable(), "toolbar and immunity survive hide-all")
	popup.id_pressed.emit(arena.training_tools.ToolsPanel.SHOW_ALL_ID)
	await tick_ui()
	for panel in [arena.builds.status_panel, arena.hud.effect_picker, arena.hud.encounter_panel, arena.room_props.hud]: check(panel.visible, "show-all restores menu panels")
	popup.id_pressed.emit(2)
	check(not arena.hud.effect_picker.visible and arena.builds.status_panel.visible, "individual FX toggle isolated")
	popup.id_pressed.emit(2)
	# Bilingual fit and display capture.
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		arena.hud.refresh_text()
		arena.builds.refresh_text()
		arena.training_tools.refresh_text()
		await tick_ui()
		check(root.get_visible_rect().encloses(button("TrainingToolbar").get_global_rect()), "toolbar fits " + locale)
		check(root.get_visible_rect().encloses(button("TrainingModifiersPanel").get_global_rect()), "tools panel fits " + locale)
		for item in arena.training_tools.panel.find_children("*", "BaseButton", true, false):
			check(not item.text.begins_with("training."), "buttons translated " + locale)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("E:/ShopGame/builds/training_tools_" + locale + ".png")
	arena._open_pause_menu()
	check(button("TrainingToolsToggle").disabled and not arena.training_tools.add_wave(), "settings pause gates tools and commands")
	arena.pause_menu.close()
	await tick_ui()
	check(button("TrainingModifiersPanel").visible and not button("TrainingToolsToggle").disabled, "closing settings restores tool expansion")
	arena.training_tools.set_player_invincible(false)
	arena.player.receive_hit(5.0)
	await click(button("TrainingHealPlayer"))
	check(arena.player.health.current == arena.player.health.maximum, "UI restores live player HP")
	arena.training_tools.set_enemies_invincible(false)
	kill_enemies()
	check(loot_count == old_count and wave_rewards == 1, "supplemental enemies grant no loot or duplicate wave reward")
	# Spawn during an already-rewarded inter-wave wait, then remove it.
	check(arena.training_tools.add_wave(), "can add practice enemies during inter-wave wait")
	kill_enemies()
	check(wave_rewards == 1, "inter-wave reinforcements cannot duplicate earned reward")
	arena.training_tools.set_enemies_invincible(true)
	arena.encounter.tick(arena.catalog.wave_delay())
	check(live_enemies().all(func(a): return a.invulnerable()), "ordinary next wave also inherits enemy immunity")
	arena.training_tools.set_enemies_invincible(false)
	kill_enemies()
	check(arena.state == "victory", "normal encounter completes after all additions die")
	arena.builds.finish_rewards()
	var retained_build: Dictionary = arena.builds.session.snapshot()
	var reward_count := wave_rewards
	check(arena.training_tools.add_wave() and arena.state == "fighting", "add wave resumes training after victory")
	await tick_ui()
	check(arena.builds.status_panel.visible, "visible build preference restored after victory cleanup")
	check(arena.builds.session.snapshot() == retained_build and not arena.builds._stopped, "post-victory practice keeps bound selections, revision and reward RNG active")
	kill_enemies()
	check(arena.state == "victory" and wave_rewards == reward_count, "post-victory practice gives no extra progression reward")
	arena.training_tools.set_menu_visible("build", false)
	check(arena.training_tools.add_wave(), "second post-victory wave can spawn")
	await tick_ui()
	check(not arena.builds.status_panel.visible, "hidden build preference survives continued practice")
	arena.training_tools.set_menu_visible("hud", false)
	arena.player.receive_hit(arena.player.health.maximum)
	await tick_ui()
	check(arena.state == "defeat" and not button("TrainingVisibilityMenu").disabled and button("TrainingAddWave").disabled, "defeat keeps menu restoration available but disables cheat actions")
	arena.training_tools.set_menu_visible("hud", true)
	check(arena.hud._footer.visible, "hidden retry actions recover after defeat")
	# Actual transition resets transient tools; only room/encounter are preserved.
	var previous = arena
	arena._retry()
	while current_scene == previous: await process_frame
	arena = current_scene
	arena.set_physics_process(false)
	await tick_ui()
	check(not arena.training_tools.player_invincible and not arena.training_tools.enemies_invincible and arena.training_tools.extra_wave_count == 0, "real retry resets modifiers and additions")
	check(arena.encounter_plan == original_plan, "retry preserves original locked encounter")
	finish()
func finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(arena): arena.queue_free()
	await process_frame
	print("TRAINING_TOOLS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
