extends SceneTree
var failures: Array[String] = []
var arena
var finished := false
var captured: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	create_timer(60.0).timeout.connect(func():
		if not finished:
			check(false,"mechanism integration timeout")
			finish())
	arena = load("res://app/mechanism_slice.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	arena.set_physics_process(false)
	check(arena.builds.is_choosing(), "real entry starts legal offer")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	root.push_input(key,true)
	check(arena.builds.runtime.diagnostics().queued == 0, "choice modal blocks arrow")
	var desired := ["impact_blast","split","contact_slow","contact_freeze","freeze_duration"]
	var total := 0
	for entry in arena.builds.catalog.entries(): total += int(entry.max_rank)
	for i in total:
		if not arena.builds.is_choosing(): arena.builds.request_test_offer()
		await process_frame
		await process_frame
		var buttons: Dictionary = arena.builds.choice_panel.buttons
		if buttons.is_empty(): break
		if not arena.builds.session.snapshot().ranks.has("contact_freeze") and not arena.builds.session.snapshot().ranks.has("frost_blast"):
			check(not buttons.has("freeze_duration"), "UI cannot offer useless freeze modifier")
		for locale in ["en","zh_CN"]:
			TranslationServer.set_locale(locale)
			arena.builds.refresh_text()
			await process_frame
			for button in buttons.values(): check(root.get_visible_rect().encloses(button.get_global_rect()), "bilingual cards remain inside viewport")
			if DisplayServer.get_name() != "headless" and buttons.has("contact_freeze") and not captured.has(locale):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("E:/ShopGame/builds/mechanism_cards_" + locale + ".png")
				captured[locale] = true
			for label in arena.builds.choice_panel.find_children("*","Label",true,false):
				check(not label.text.begins_with("build.") and not label.text.contains("{"), "new bilingual cards resolve keys and parameters")
		# This remains the legacy split regression; pierce is a separate legal branch.
		var selectable: Array = buttons.keys().filter(func(id):return id != "pierce")
		if selectable.is_empty(): break
		var selected: String = selectable[0]
		for id in desired:
			if buttons.has(id):
				selected = id
				break
		buttons[selected].pressed.emit()
		await process_frame
		var ranks: Dictionary = arena.builds.session.snapshot().ranks
		if desired.all(func(id):return ranks.has(id)): break
	var ranks: Dictionary = arena.builds.session.snapshot().ranks
	check(desired.all(func(id):return ranks.has(id)), "all mechanism samples selected via real UI commands")
	arena.builds.clear_room()
	arena.player.cancel()
	arena.player.facing = Vector3.FORWARD
	for actor in arena.actors:
		if actor != arena.player: actor.position += Vector3(50,0,50)
	var point: Vector3 = arena.player.position
	var first = arena._spawn(arena.catalog.actor("brute"),point + Vector3(0,0,-1.4),1)
	var second = arena._spawn(arena.catalog.actor("brute"),point + Vector3(1.2,0,-1.4),1)
	var old_hp: float = second.health.current
	root.gui_release_focus()
	root.push_input(key,true)
	await process_frame
	arena.builds.step(0.001)
	arena.builds.step(0.09)
	check(first.control_locked, "actual arrow applies freeze through status queue")
	check(second.health.current < old_hp, "actual world query allows nearby blast damage")
	check(arena.builds.runtime.projectiles().size() == 2, "real integration supports split plus blast")
	arena.builds.refresh(0.0)
	for view in arena.views: view.refresh(0.0)
	check(arena.builds.mechanisms.get_child_count() >= 2, "committed area and status visuals exist")
	var snapshot: Dictionary = arena.builds.runtime.statuses.snapshot(first)
	arena.builds.request_test_offer()
	await process_frame
	await process_frame
	if arena.builds.is_choosing():
		arena.set_physics_process(true)
		await create_timer(0.2).timeout
		arena.set_physics_process(false)
		check(arena.builds.runtime.statuses.snapshot(first) == snapshot, "actual modal gate pauses status clock")
		arena.builds.choice_panel.buttons.values()[0].pressed.emit()
		await process_frame
	# Keep camera/visual snapshots fixed for inspection; no synthetic damage from presentation.
	arena.builds.refresh(0.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/builds/mechanism_slice.png")
	arena.builds.clear_room()
	check(not first.control_locked and arena.builds.runtime.statuses.visuals().is_empty(), "room transition clears status authority")
	await process_frame
	finish()
func finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(arena): arena.queue_free()
	await process_frame
	print("MECHANISM_SLICE_INTEGRATION ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
