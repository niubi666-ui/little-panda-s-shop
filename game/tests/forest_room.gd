extends SceneTree
const HOST = preload("res://app/combat_training.tscn")
var failures: Array[String] = []
var scene
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	var original_taa := root.use_taa
	scene = HOST.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(.3).timeout
	check(scene.room != null and scene.room_presentation.template_id == &"forest_courtyard.v001", "injected authored room")
	check(scene.builds.is_choosing(), "three-choice in new room")
	var offer: Dictionary = scene.builds.session.snapshot()["offer"]
	scene.builds.choice_panel.choice_requested.emit(offer["id"], offer["candidates"][0])
	check(not scene.builds.is_choosing(), "choice resumes new room")
	scene.set_physics_process(false)
	scene.brains.clear()
	await physics_frame
	var space = scene.get_world_3d().direct_space_state
	for point in scene.room.enemy_spawns():
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = scene.player.get_node("CollisionShape3D").shape if scene.player.has_node("CollisionShape3D") else scene.player.get_child(0).shape
		shape.transform.origin = point + Vector3.UP * .525
		shape.collision_mask = 1
		check(space.intersect_shape(shape).is_empty(), "enemy marker clear of room blockers")
	for endpoint in [Vector3(12, 1, 0),Vector3(-12, 1, 0),Vector3(0, 1, -12),Vector3(0, 1, 12)]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0,1,0),endpoint,1)
		check(not space.intersect_ray(ray).is_empty(), "boundary stops wall query")
	# Real motor crosses the central arena, then stops at an authored stone railing.
	# Outside the random placement surface; tests the authored railing itself.
	scene.player.position = Vector3(7.2, .04, 0)
	scene.player.movement = Vector3.RIGHT
	for frame in 60:
		await physics_frame
		scene.player.step(1.0/60.0)
	check(scene.player.position.x > 7.0 and scene.player.position.x < 8.6, "movement and physical east railing")
	scene.player.cancel()
	var camera: Camera3D = scene.get_node("Camera")
	for position in [Vector3(-8,.04,7),Vector3(8,.04,-6),Vector3.ZERO]:
		scene.player.position = position
		scene._follow_camera()
		check(not camera.is_position_behind(scene.player.global_position), "camera sees player across room")
		check(root.get_visible_rect().has_point(camera.unproject_position(scene.player.global_position)), "player remains onscreen")
	# Complete both waves with real attacks/resolver, preserving the normal reward gate.
	for wave in scene.catalog.waves().size():
		for enemy in scene.actors.duplicate():
			if enemy.team == 0 or not enemy.health.alive(): continue
			enemy.position = Vector3(0,.04,-2)
			scene.player.position = Vector3(0,.04,-1)
			scene.player.facing = Vector3.FORWARD
			var attempts := 0
			while enemy.health.alive() and attempts < 30:
				scene.player.runner.cancel()
				scene.player.runner.cooldown = 0.0
				scene.player.request_attack()
				scene.player.step(.01)
				scene.player.runner.tick(scene.player.runner.ability.windup)
				scene.resolver.resolve(scene.player,[enemy])
				scene.builds.step(.01)
				attempts += 1
			check(not enemy.health.alive(), "real attacks kill in forest courtyard")
		if wave + 1 < scene.catalog.waves().size():
			scene.builds.flush_offers()
			check(scene.builds.is_choosing(), "wave reward retained")
			offer = scene.builds.session.snapshot()["offer"]
			scene.builds.choice_panel.choice_requested.emit(offer["id"],offer["candidates"][0])
			scene.encounter.tick(scene.catalog.wave_delay())
	check(scene.state == "victory", "new room completes full encounter")
	scene._retry()
	await scene._transition.completed
	scene = current_scene
	check(scene.room != null and scene.builds.is_choosing(), "retry retains injected room and resets build")
	scene._return()
	await scene._transition.completed
	check(current_scene.scene_file_path == "res://app/main.tscn", "return to shop")
	check(root.use_taa == original_taa, "restore viewport presentation after leaving room")
	current_scene._enter_training()
	await current_scene._transition.completed
	check(current_scene.scene_file_path == "res://app/combat_training.tscn", "shop enters generic room host")
	check(current_scene.room != null, "shop entry uses current authored room")
	print("FOREST_ROOM ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
