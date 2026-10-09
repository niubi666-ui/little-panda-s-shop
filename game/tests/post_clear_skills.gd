extends SceneTree
const Resolver = preload("res://combat/builds/build_resolver.gd")
var failures: Array[String] = []
var arena
var spawned := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func step(count: int) -> void:
	for index in count: arena._physics_process(1.0 / 60.0)
func shoot() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	arena._unhandled_input(event)
func run() -> void:
	# Check actual generated blade nodes, including echoes, in every planar heading.
	var style = load("res://presentation/builds/build_effects_style.tres")
	for kind in ["normal", "frost"]:
		var visual = load("res://presentation/combat/fx/sword_waves_v001/%s_wave.tscn" % kind).instantiate()
		root.add_child(visual)
		visual.configure_effect({})
		for degree in range(360):
			visual.basis = Basis(Vector3.UP, deg_to_rad(degree)) * Basis.from_scale(style.projectile_size_per_radius)
			for blade in visual._art.get_children():
				if not (str(blade.name).begins_with("Crescent") or str(blade.name).begins_with("WakeArc")): continue
				var normal: Vector3 = blade.global_basis.inverse().transposed() * Vector3.UP
				check(absf(normal.normalized().dot(Vector3.UP)) > 0.99999, kind + " blade is horizontal")
		visual.free()
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	await process_frame
	var resolver := Resolver.new()
	resolver.configure(arena.builds.catalog)
	var program := resolver.resolve({"selections":[],"revision":1})
	arena.builds.runtime.set_program(program)
	arena.player.set_action_program(program.actions, arena.catalog)
	arena.builds.runtime.projectile_presented.connect(func(fact):
		if fact.event == "spawned": spawned += 1)
	# A cast in progress must survive the final kill/clear transition.
	shoot()
	step(1)
	check(arena.player.runner.busy(), "right input enters wave release/recovery")
	check(spawned == 1, "wave launches on first accepted input frame")
	arena._finish("victory")
	check(arena.player.runner.busy(), "victory preserves committed player cast")
	for actor in arena.actors:
		if actor != arena.player: actor.receive_hit(actor.health.maximum)
	step(25)
	check(spawned == 1, "instant wave crossing clear remains exactly one projectile")
	var generation: int = arena.builds.runtime.diagnostics().room_generation
	var state: Dictionary = arena.builds.session.snapshot()
	step(120)
	shoot()
	step(25)
	check(spawned == 2, "right input launches again after clear")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("builds")
		check(DirAccess.make_dir_recursive_absolute(output) == OK, "screenshot directory created")
		check(root.get_texture().get_image().save_png(output.path_join("post_clear_wave.png")) == OK, "post-clear screenshot saved")
	check(arena.state == "victory" and not arena.builds._stopped, "room remains won while skill runtime lives")
	check(arena.builds.session.snapshot() == state, "empty casts do not change rewards or RNG")
	arena.builds.reward_wave(99)
	check(arena.builds._pending == 0, "late automatic reward ignored after clear")
	arena._finish("victory")
	check(arena.builds.runtime.diagnostics().room_generation == generation, "duplicate victory does not clear projectiles")
	arena.paused = true
	var shots: Array = arena.builds.runtime.projectiles()
	step(30)
	check(arena.builds.runtime.projectiles() == shots, "pause still freezes post-clear projectiles")
	arena.paused = false
	arena.player.receive_hit(arena.player.health.maximum)
	shoot()
	step(60)
	check(arena.state == "defeat" and spawned == 2 and arena.builds._stopped, "death after clear still stops skills")
	arena._shutdown()
	shoot()
	step(60)
	check(spawned == 2 and arena.builds.runtime.diagnostics().roots == 0, "exit stops skill execution and clears roots")
	await process_frame
	await process_frame
	arena.queue_free()
	await process_frame
	print("POST_CLEAR_SKILLS ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
