extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func run() -> void:
	var demo = load("res://presentation/combat/demos/slash_showcase_v001/showcase.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	for scene in demo.Settings.effects:
		demo._arena.views[0].set_weapon_effect(scene)
		var effect = demo._arena.views[0].weapon_effect
		effect.set_process(false)
		effect.set_time_running(true)
		effect.set_active(true)
		effect._process(0.01)
		effect.position.x += 0.1
		effect._process(0.01)
		check(effect._mesh.get_surface_count() == 1, "ribbon samples a moving blade")
		var ages = effect._ages.duplicate()
		effect.set_time_running(false)
		effect._process(1.0)
		check(effect._ages == ages and effect.get_node("Particles").speed_scale == 0.0, "pause freezes ribbon and particles")
		effect.set_time_running(true)
		effect.set_active(false)
		effect._process(effect.tail_lifetime_sec)
		check(effect._ages.is_empty() and effect._mesh.get_surface_count() == 0, "tail expires after emission ends")
		effect.set_active(true)
		effect._process(0.01)
		effect.set_active(false)
		effect.set_active(true)
		effect._process(0.01)
		check(effect._mesh.get_surface_count() == 0, "separate strokes are not joined")
		effect.clear_tail()
		check(effect._ages.is_empty() and not effect._active, "explicit reset clears samples")
	var cast_id: int = demo._arena.player.runner.cast_id
	demo._arena.views[0].set_weapon_effect(demo.Settings.effects[0])
	check(demo._arena.player.runner.cast_id == cast_id, "visual replacement preserves cast")
	demo.queue_free()
	await process_frame
	print("SLASH_VERIFY ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
