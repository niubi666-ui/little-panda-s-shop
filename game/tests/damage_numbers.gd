extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await process_frame
	var player = arena.player
	var enemy = arena.actors[1]
	var player_numbers = arena.views[0].damage_numbers
	var numbers = arena.views[1].damage_numbers
	player.position = Vector3.ZERO
	enemy.position = Vector3(2, 0, -2)
	var before: float = enemy.health.current
	enemy.health.apply(12.5, true)
	check(not numbers.has_tail() and enemy.health.current == before, "immune damage produces no number")
	enemy.health.apply(12.5, false)
	player.health.apply(7, false)
	check(numbers._entries.size() == 1 and numbers._entries[0].label.text == "12.5", "enemy shows committed fractional damage")
	check(player_numbers._entries.size() == 1 and player_numbers._entries[0].label.text == "7", "player shows committed damage")
	check(numbers._entries[0].label.modulate != player_numbers._entries[0].label.modulate, "player and enemy colors differ")
	var origin: Vector3 = numbers._entries[0].label.global_position
	enemy.position += Vector3.RIGHT
	numbers.tick(0.0)
	check(numbers._entries[0].age == 0.0 and numbers._entries[0].label.global_position == origin, "pause freezes text and actor movement does not drag old numbers")
	for view in arena.views: view.refresh(0.12)
	check(numbers._entries[0].label.global_position.y > origin.y, "number rises")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../builds/damage_numbers_preview.png")
	numbers.tick(numbers.settings.lifetime_sec)
	check(not numbers.has_tail(), "expired labels are freed")
	var remaining: float = enemy.health.current
	enemy.health.apply(remaining + 100, false)
	check(is_equal_approx(numbers._entries[0].label.text.to_float(), remaining), "lethal overkill shows actual HP lost")
	arena.views[1].refresh(0.0)
	check(arena.views[1].visible and numbers.has_tail(), "death retains the final number")
	var count: int = numbers._entries.size()
	enemy.health.apply(1, false)
	check(numbers._entries.size() == count, "already dead produces no extra number")
	for i in player_numbers.settings.max_visible_per_actor + 3:
		player.health.apply(0.1, false)
	check(player_numbers._entries.size() == player_numbers.settings.max_visible_per_actor, "rapid hit labels have a bounded count")
	var weak: WeakRef = weakref(numbers)
	current_scene = null
	arena.queue_free()
	await process_frame
	check(weak.get_ref() == null, "leaving room frees number adapter and labels")
	print("DAMAGE_NUMBERS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
