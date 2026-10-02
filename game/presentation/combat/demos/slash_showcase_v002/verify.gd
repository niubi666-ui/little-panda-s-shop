extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func run() -> void:
	var demo = load("res://presentation/combat/demos/slash_showcase_v002/showcase.tscn").instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	for scene in demo.Settings.effects:
		demo._arena.views[0].set_weapon_effect(scene)
		var effect = demo._arena.views[0].weapon_effect
		effect.set_process(false)
		effect.clear_tail()
		effect.set_time_running(true)
		effect.set_active(false)
		effect._process(0.01)
		effect.set_active(true)
		effect.rotation.y = deg_to_rad(30.0)
		effect._process(0.01)
		check(effect._mesh.get_surface_count() == 1 and effect._tips.size() >= 6, "angular interpolation produces smooth arc")
		check(effect._roots.back().distance_to(effect._tips.back()) >= demo._arena.Style.blade_size.z, "root/tip ribbon covers full sword length")
		var ages = effect._ages.duplicate()
		effect.set_time_running(false)
		effect._process(1.0)
		check(effect._ages == ages and effect.get_node("Particles").speed_scale == 0.0, "pause freezes ribbon and particles")
		effect.set_time_running(true)
		effect.set_active(false)
		effect._process(0.01)
		effect._process(effect.tail_lifetime_sec)
		check(effect._ages.is_empty() and effect._mesh.get_surface_count() == 0, "tail expires after final sword pose")
		effect.set_active(true)
		effect.rotation.y += deg_to_rad(20.0)
		effect._process(0.01)
		effect.set_active(false)
		effect._process(0.01)
		effect.set_active(true)
		effect.rotation.y += deg_to_rad(20.0)
		effect._process(0.01)
		var expected_vertices := 0
		for i in range(1, effect._strokes.size()):
			if effect._strokes[i - 1] == effect._strokes[i]: expected_vertices += 6
		check(effect._mesh.get_faces().size() == expected_vertices, "no triangles connect separate strokes")
		effect.clear_tail()
		check(effect._ages.is_empty() and not effect._active, "explicit reset clears samples")
	var cast_id: int = demo._arena.player.runner.cast_id
	demo._arena.views[0].set_weapon_effect(demo._arena.Style.weapon_effect_scene)
	check(demo._arena.player.runner.cast_id == cast_id, "training default replacement preserves cast")
	demo.queue_free()
	await process_frame
	print("SLASH_VERIFY_V002 ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
