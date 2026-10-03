extends SceneTree
var app
var failures: Array[String] = []
var done := false
var checks := 0
class InputProbe extends RefCounted:
	var camera: Camera3D
	var wrapped
	var offset := Vector2.INF
	func update() -> void:
		offset = Vector2(camera.h_offset, camera.v_offset)
		wrapped.update()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/run_" + name + ".png")
func run() -> void:
	create_timer(90.0).timeout.connect(func():
		if not done:
			check(false, "run integration timeout")
			finish())
	app = load("res://app/run_preview.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await frames()
	check(app.session != null, "entry loads content, templates and authority")
	if app.session == null: finish(); return
	var build: Dictionary = app.session.snapshot().build_program
	check(not app.session.snapshot().build_state.selections.is_empty(), "explicit starter build enables meaningful persistence test")
	await check_languages("initial")
	# Rejected node and failed room preparation must not advance route or counters.
	var state: Dictionary = app.session.snapshot()
	app._enter_node("missing")
	check(app.session.snapshot() == state and not app.busy, "invalid node cannot enter")
	var first_id: String = app.session.map_snapshot().available_node_ids[0]
	var original: Resource = app.templates
	app.templates = original.duplicate(true)
	var presentation: Resource = app.templates.rooms.graybox.duplicate(true)
	# A valid Node3D scene with no spawn protocol gives an ordinary load failure.
	var blank := Node3D.new()
	var broken := PackedScene.new()
	broken.pack(blank)
	blank.free()
	presentation.scene = broken
	app.templates.rooms.graybox = presentation
	await app._enter_node(first_id)
	check(app.session.snapshot() == state and not app.busy and app._slot.get_child_count() == 0, "failed template keeps authority, room count and map retryable")
	app.templates = original
	for branch in [0, 1]:
		if branch > 0: app.restart(); await frames()
		var old_seed := ""
		for index in 5:
			var available: Array = app.session.map_snapshot().available_node_ids
			check(not available.is_empty(), "route exposes successor")
			if available.is_empty(): break
			var node_id: String = available[mini(branch, available.size() - 1)]
			# Pointer starts first room; subsequent app requests exercise duplicate guard.
			if index == 0:
				var button = app.map_view.buttons[node_id]
				await click(button)
			else: app._enter_node(node_id)
			app._enter_node(node_id)
			while app.busy: await process_frame
			await frames()
			check(app.room != null, "selected node instantiates room")
			if app.room == null: finish(); return
			app.room.set_physics_process(false)
			var entered: Dictionary = app.session.snapshot()
			check(entered.room_count == index + 1 and entered.current_node_id == node_id, "one successful entry increments ordinal once")
			check(entered.build_program == build and app.room.build_runtime._program == build, "authority and disposable room preserve action build")
			check(app.room.player.health.current == entered.hp, "entry restores checkpoint HP")
			var node_seed: String = entered.active_room_plan.encounter_plan.seed
			check(node_seed != old_seed, "every node owns a distinct locked encounter seed")
			old_seed = node_seed
			var before: Dictionary = app.session.snapshot()
			app.return_to_map()
			check(app.session.snapshot() == before and app.room != null, "cannot leave an uncleared room")
			# Actual world special action still executes in the new room composition.
			app.room.player.facing = Vector3.FORWARD
			app.room.player.request_special()
			app.room.player.step(0.001)
			app.room.player.runner.tick(app.room.player.runner.ability.windup)
			app.room.build_runtime.tick(0.001)
			check(app.room.build_runtime.projectiles().size() == 1, "persistent right-wave program executes in each fresh room")
			if index == 0 and branch == 0:
				var probe := InputProbe.new()
				probe.camera = app.room.camera
				probe.wrapped = app.room.input_adapter
				app.room.input_adapter = probe
				app.room.camera.h_offset = 2.0
				app.room.camera.v_offset = -2.0
				app.room._physics_process(0.001)
				app.room.input_adapter = probe.wrapped
				check(probe.offset == Vector2.ZERO, "presentation camera shake never enters gameplay aiming")
				var shots: Array = app.room.build_runtime.projectiles().duplicate(true)
				app.room.set_physics_process(true)
				app._pause.open_requested.emit()
				await create_timer(0.1).timeout
				check(paused and shots == app.room.build_runtime.projectiles(), "settings pause freezes active room projectile clock")
				app.room.set_physics_process(false)
				app._pause.close()
			app.room.player.receive_hit(1.0)
			var hp: float = app.room.player.health.current
			var old_runtime = app.room.build_runtime
			var room_ref: WeakRef = weakref(app.room)
			if index == 0 and branch == 0: await check_languages("room")
			clear_encounter()
			app.room._melee.confirmed_hit.emit(app.room.player, app.room.actors.back(), 1, "slash.1", 1.0)
			app.room.build_runtime.damage_applied.emit(app.room.player, app.room.actors.back(), 1.0, "direct_projectile")
			app.room.refresh(0.0)
			check(app.room.camera.h_offset == 0.0 and app.room.camera.v_offset == 0.0, "late last-kill feedback cannot leave cleared camera shaking")
			check(app.session.snapshot().hp == hp, "clear captures remaining HP")
			check(app.session.snapshot().phase == ("completed" if index == 4 else "cleared"), "whole encounter drives clear or terminal result")
			var cleared: Dictionary = app.session.snapshot()
			app._room_cleared(entered.active_entry_id, hp)
			check(app.session.snapshot() == cleared, "duplicate clear does not publish twice")
			check(old_runtime.diagnostics().roots == 0 and old_runtime.projectiles().is_empty(), "completion clears outstanding projectiles")
			if index < 4:
				app.return_to_map()
				await frames()
				check(room_ref.get_ref() == null and app._slot.get_child_count() == 0, "map disposes prior actors and room instance")
				check(app.session.snapshot().build_program == build, "returning to map retains Build")
				if index == 0 and branch == 0: await check_languages("fork")
			else:
				check(app.session.map_snapshot().available_node_ids.is_empty(), "terminal ends route with no extra encounter")
				await check_languages("complete")
	# Death/restart clears old room authority and starts ordinal at zero.
	app.restart()
	await app._enter_node(app.session.map_snapshot().available_node_ids[0])
	app.room.set_physics_process(false)
	var dead_room: WeakRef = weakref(app.room)
	app.room.player.receive_hit(app.room.player.health.maximum)
	check(app.session.snapshot().phase == "defeated" and app.session.snapshot().hp == 0.0, "actual player death prevents further progress")
	app.return_to_map()
	check(app.session.snapshot().phase == "defeated", "death cannot return and advance")
	app.restart()
	await frames()
	check(dead_room.get_ref() == null and app.session.snapshot().room_count == 0 and app.session.snapshot().phase == "map", "restart creates fresh run and disposes defeated room")
	finish()
func clear_encounter() -> void:
	var count: int = app.room._plan.encounter_plan.waves.size()
	for wave in count:
		for enemy in app.room.actors.duplicate():
			if enemy != app.room.player and enemy.health.alive(): enemy.receive_hit(enemy.health.maximum)
		if not app.room.stopped:
			app.room.player.cancel()
			app.room.player.runner.tick(10.0)
			app.room.player.stagger_left = 0.0
			app.room.player.request_special()
			app.room.player.step(0.001)
			check(app.room.player.runner.busy(), "fixture starts a windup at wave boundary")
			app.room.encounter.tick(app.combat.wave_delay())
			check(not app.room.player.runner.busy() and app.room.build_runtime.diagnostics().roots == 0, "wave change cancels action before clearing its root")
func check_languages(label: String) -> void:
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		app.refresh_text()
		await frames()
		if app.map_view.visible:
			for button in app.map_view.buttons.values():
				check(root.get_visible_rect().encloses(button.get_global_rect()), "five-layer map nodes inside viewport in " + locale)
		for control in [app.map_view, app.room_hud]:
			for text in control.find_children("*", "Label", true, false):
				check(not text.text.begins_with("run.") and not text.text.contains("{"), "localized route labels resolve")
		await capture(label + "_" + locale)
func finish() -> void:
	if done: return
	done = true
	if is_instance_valid(app): app.queue_free()
	await frames()
	print("RUN_INTEGRATION ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
