extends SceneTree
## Real scene, pointer input and UI/session wiring. Mechanical edge cases have focused suites.
var arena
var failures: Array[String] = []
var finished := false
var target_point := Vector3.ZERO
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func click_at(point: Vector2, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button_index
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
func click(control: Control) -> void:
	# Footer remains reachable even when the description scroll consumes its own clicks.
	await click_at(control.get_global_rect().get_center() + Vector2(0, control.size.y * 0.4))
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/action_" + name + ".png")
func labels_resolve(control: Node) -> void:
	for label in control.find_children("*", "Label", true, false):
		check(not label.text.begins_with("build.") and not label.text.contains("{"), "bilingual keys/parameters resolve")
func language(locale: String) -> void:
	TranslationServer.set_locale(locale)
	arena.hud.refresh_text()
	arena.hud.update_state(arena.player, arena.encounter, arena._waves.size(), "choosing" if arena.builds.is_choosing() else arena.state, arena.paused)
	arena.hud.update_encounter(arena.encounter_plan, arena.encounter.wave_index)
	arena.builds.refresh_text()
	arena.training_tools.refresh_text()
	arena.room_props.refresh(not arena.builds.is_choosing())
	if arena.has_node("UIRoot/ArrowHint"): arena.get_node("UIRoot/ArrowHint").text = tr(arena.test_hint_key)
func run() -> void:
	create_timer(120.0).timeout.connect(func():
		if not finished:
			check(false, "action integration timeout")
			finish())
	arena = load("res://app/action_build_slice.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await frames()
	check(arena.builds.is_choosing(), "real entry opens ordinary reward")
	var initial: Dictionary = arena.builds.session.snapshot()
	key(KEY_T)
	key(KEY_Q)
	await click_at(root.get_visible_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check(arena.builds.runtime.diagnostics().queued == 0 and arena.player.runner.cast_id == 0, "choice modal blocks arrows and special")
	for locale in ["zh_CN", "en"]:
		language(locale)
		await frames()
		check(arena.builds.session.snapshot() == initial, "translation preserves locked offer and RNG")
		for button in arena.builds.choice_panel.buttons.values():
			check(root.get_visible_rect().encloses(button.get_global_rect()), "bilingual cards inside viewport")
		labels_resolve(arena.builds.choice_panel)
		await capture("cards_" + locale)
	await click(arena.builds.choice_panel.buttons.values()[0])
	check(not arena.builds.is_choosing() and arena.builds.session.snapshot().selections.size() == 1, "real card pointer commits bound choice")
	var menu: MenuButton = arena.builds.status_panel._preset_menu
	check(menu != null and menu.get_popup().item_count == 3, "three authored presets exposed")
	await check_popup_focus(menu)
	# Place stationary test enemies on an actual clear corridor in the imported room.
	for actor in arena.actors:
		if actor != arena.player: actor.position += Vector3(50, 0, 50)
	target_point = arena.player.position
	var found := false
	for x in range(-4, 5):
		for z in range(-4, 5):
			var p: Vector3 = target_point + Vector3(x, 0, z)
			if not arena._training_spawn_clear(p, "player", []): continue
			if arena._build_wall_hit(p + Vector3.UP * 0.8, p + Vector3(0, 0.8, -6)) == null and arena._build_wall_hit(p + Vector3(0, 0.8, -1.4), p + Vector3(1.2, 0.8, -1.4)) == null:
				target_point = p
				found = true
				break
		if found: break
	check(found, "room contains clear test corridor")
	arena.player.position = target_point
	var first = arena._spawn(arena.catalog.actor("brute"), target_point + Vector3(0, 0, -1.4), 1)
	var later = arena._spawn(arena.catalog.actor("brute"), target_point + Vector3(0, 0, -4.6), 1)
	var side = arena._spawn(arena.catalog.actor("brute"), target_point + Vector3(1.2, 0, -1.4), 1)
	for index in 3:
		var rng: String = arena.builds.session.snapshot().rng_state
		menu.get_popup().id_pressed.emit(index)
		await frames()
		check(arena.builds.session.snapshot().rng_state == rng, "preset command preserves RNG")
		var preset: Dictionary = arena.builds.catalog.test_presets()[index]
		check(arena.builds.session.snapshot().selections.size() == preset.selections.size(), "preset applies complete sequence through session")
		for target in [first, later, side]: target.health.current = target.health.maximum
		arena.player.runner.tick(10.0)
		arena.player.facing = Vector3.FORWARD
		root.gui_release_focus()
		if index == 0: await click_at(Vector2(700, 400), MOUSE_BUTTON_RIGHT)
		else: key(KEY_Q)
		arena.player.step(0.001)
		check(arena.player.runner.action_id == ("special" if index == 0 else "skill") and arena.player.runner.busy(), "viewport right/Q input selects independent action")
		var ability = arena.player.runner.ability
		arena.player.runner.tick(ability.windup)
		var prop_hp: Array = arena.room_props.props.map(func(prop): return prop.health.current if prop.health != null else -1.0)
		arena.room_props.resolve_attack()
		arena.resolver.resolve(arena.player, arena.actors)
		if index > 0:
			check(first.health.current == first.health.maximum, "wave form has no hidden melee damage")
			check(prop_hp == arena.room_props.props.map(func(prop): return prop.health.current if prop.health != null else -1.0), "projectile cast skips room prop melee path")
		arena.builds.step(0.001)
		arena.builds.step(0.5)
		check(first.health.current < first.health.maximum, "actual special damages first target")
		check((later.health.current < later.health.maximum) == (index > 0), "Q wave penetrates later target")
		check(first.control_locked == (index > 0), "Q core or frost area freezes first target")
		check(later.control_locked == (index == 1), "later freeze belongs only to direct freeze preset")
		check(side.control_locked == (index == 2), "side freeze belongs only to explicit frost payload")
		arena.builds.refresh(0.0)
		for view in arena.views: view.refresh(0.0)
		for locale in ["zh_CN", "en"]:
			language(locale)
			await frames()
			check(root.get_visible_rect().encloses(arena.builds.status_panel.get_global_rect()), "bilingual preset status in viewport")
			check(root.get_visible_rect().encloses(arena.hud.encounter_panel.get_global_rect()), "bilingual depth panel in viewport")
			labels_resolve(arena.builds.status_panel)
			await capture(preset.id + "_" + locale)
		if index > 0:
			var snapshot: Dictionary = arena.builds.runtime.statuses.snapshot(first)
			arena.builds.request_test_offer()
			await frames()
			arena.set_physics_process(true)
			await create_timer(0.1).timeout
			arena.set_physics_process(false)
			check(arena.builds.runtime.statuses.snapshot(first) == snapshot, "actual choice modal freezes status clock")
			await click(arena.builds.choice_panel.buttons.values()[0])
		# Dedicated test arrow remains independent of all preset payloads.
		arena.builds.clear_room()
		for target in [first, later, side]: target.health.current = target.health.maximum
		root.gui_release_focus()
		arena.player.facing = Vector3.FORWARD
		key(KEY_T)
		arena.builds.step(0.001)
		arena.builds.step(0.5)
		check(first.health.current < first.health.maximum and later.health.current == later.health.maximum and not first.control_locked, "T input fires isolated non-piercing plain debug arrow")
	await check_replacement_ui(menu)
	var old_runtime = arena.builds.runtime
	var previous = arena
	arena.hud.retry_requested.emit()
	while current_scene == previous: await process_frame
	arena = current_scene
	arena.set_physics_process(false)
	await frames()
	check(arena.scene_file_path == "res://app/action_build_slice.tscn" and arena.enable_mechanism_presets, "retry preserves dedicated action entry")
	check(arena.builds.session.snapshot().selections.is_empty(), "retry resets bound selections")
	check(arena.builds.session.program().actions.skill.form_id == "sword_wave" and arena.builds.session.program().actions.special.form_id == "sword_heavy", "retry retains all base attacks without unlock")
	check(old_runtime.diagnostics().roots == 0 and old_runtime.statuses.diagnostics().tracked_actors == 0, "retry clears old roots and statuses")
	finish()
func check_popup_focus(menu: MenuButton) -> void:
	for button in [menu, arena.training_tools.panel._menu]:
		root.gui_release_focus()
		button.show_popup()
		await frames()
		Input.action_press("move_forward")
		arena.input_adapter.update()
		Input.action_release("move_forward")
		check(arena.player.movement == Vector3.ZERO, "open popup blocks polled movement without Control focus")
		key(KEY_Q)
		check(arena.player.buffered_action_id.is_empty(), "popup blocks Q input")
		button.get_popup().hide()
	await frames()
func check_replacement_ui(menu: MenuButton) -> void:
	menu.get_popup().id_pressed.emit(0)
	var result: Dictionary = arena.builds.session.submit_operation(arena.builds.session.legal_operations("contact_freeze").filter(func(op): return op.action_id == "primary")[0])
	check(result.ok, "fixture core uses authoritative evaluator")
	arena.builds._apply_program()
	# Sample actual offers, then consume a replacement through the same visible card token.
	var seen := false
	for attempt in 100:
		arena.builds.request_test_offer()
		await frames()
		var selected := ""
		for id in arena.builds.choice_panel._bindings:
			var binding: Dictionary = arena.builds.choice_panel._bindings[id]
			if binding.operation == "replace": selected = id; break
		if not selected.is_empty():
			seen = true
			for locale in ["zh_CN", "en"]:
				language(locale)
				await frames()
				var text: Dictionary = arena.builds.choice_panel._card_text[selected]
				check(text.description.text.contains("\n\n") and not text.next.text.is_empty(), "replacement displays removed and new effects")
				labels_resolve(arena.builds.choice_panel)
				await capture("replacement_" + locale)
			await click(arena.builds.choice_panel.buttons[selected])
			check(not arena.builds.is_choosing(), "real replacement card commits")
			break
		if arena.builds.choice_panel.buttons.is_empty(): break
		await click(arena.builds.choice_panel.buttons.values()[0])
	check(seen, "ordinary offer flow presents a legal replacement")
func finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(arena): arena.queue_free()
	await frames()
	print("ACTION_BUILD_INTEGRATION ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
