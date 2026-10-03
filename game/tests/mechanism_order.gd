extends SceneTree
const BuildFixture = preload("res://tests/fixtures/action_build_fixture.gd")
var arena
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	for actor in arena.actors:
		if actor != arena.player: actor.position += Vector3(50,0,50)
	var heavy = arena._spawn(arena.catalog.actor("brute"),Vector3(0,0,-1),1)
	for frozen in [true,false]:
		arena.builds.clear_room()
		var program: Dictionary = BuildFixture.compile(arena.builds.catalog, {"contact_freeze":1} if frozen else {}, "primary")
		check(arena.builds.runtime.set_program(program), "same-frame fixture uses valid primary plan")
		arena.player.set_action_program(program.actions, arena.catalog)
		arena.player.position = Vector3.ZERO
		heavy.position = Vector3(0,0,-1)
		arena.player.cancel(); heavy.cancel()
		arena.player.runner.cooldown = 0.0
		heavy.runner.cooldown = 0.0
		heavy.stagger_left = 0.0
		arena.player.runner.start(arena.player.attacks[0],Vector3.FORWARD,program.actions.primary)
		heavy.runner.start(heavy.attacks[0],Vector3.BACK)
		var delta := 1.0 / 60.0
		arena.player.runner.elapsed = arena.player.runner.ability.windup - delta / 2.0
		heavy.runner.elapsed = heavy.runner.ability.windup - delta / 2.0
		var before: float = arena.player.health.current
		arena._physics_process(delta)
		if frozen:
			check(heavy.control_locked and arena.player.health.current == before, "player contact freeze cancels same-frame heavy hit through real app ordering")
		else:
			check(arena.player.health.current < before, "control case proves heavy would hit without freeze")
	arena.queue_free()
	await process_frame
	print("MECHANISM_ORDER ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
