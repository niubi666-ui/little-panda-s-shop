extends "res://tests/enemy_training.gd"
func run() -> void:
	catalog = EnemyLoader.new().load_catalog(CombatLoader.new().load_catalog())
	var arena = spawn(plan_for("crossfire_charge"))
	var spear = arena.actors.filter(func(a): return a.definition.id == "charger")[0]
	var brain = arena.brains.filter(func(b): return b.actor == spear)[0]
	for a in arena.actors:
		if a != spear and a != arena.player: a.collision_layer = 0
	await physics_frame
	var cases := 0
	for prop in arena.room_props.props:
		if prop.definition.kind != "obstacle": continue
		for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var start: Vector3 = prop.global_position + axis * 3.0
			start.y = arena.player.position.y
			spear.global_position = start
			spear.cancel(); brain.cancel()
			arena.player.global_position = start + axis * 3.0
			await physics_frame
			if not arena._enemy_sight(spear, arena.player): continue
			# The player dodged after commitment: force the locked dash toward cover.
			brain.state = "charging"
			brain.start_position = start
			brain.previous_position = start
			brain.locked_direction = -axis
			brain.hit_claimed = false
			for frame in 60:
				await physics_frame
				brain.tick(1.0/60.0); spear.step(1.0/60.0)
				brain.after_motion(arena.enemy_runtime.target_radius)
				if brain.state == "recovery": break
			check(brain.state == "recovery", "dash stops at real obstacle: " + prop.name)
			check(absf(spear.position.y - start.y) < 0.01, "dash does not climb model: " + prop.name)
			var contact: Vector3 = spear.global_position
			brain.cooldown = 0.0
			arena.player.health.current = arena.player.health.maximum
			for frame in 300:
				await physics_frame
				brain.tick(1.0/60.0); spear.step(1.0/60.0)
				brain.after_motion(arena.enemy_runtime.target_radius)
				if spear.global_position.distance_to(contact) > 1.0: break
			if spear.global_position.distance_to(contact) <= 1.0:
				print("STUCK ", prop.name, " start=", start, " contact=", contact, " end=", spear.global_position, " player=", arena.player.global_position, " state=", brain.state, " movement=", spear.movement, " sight=", arena._enemy_sight(spear, arena.player))
			check(spear.global_position.distance_to(contact) > 1.0, "leaves cover after recovery: " + prop.name)
			cases += 1
	check(cases >= 4, "multiple real obstacle approaches covered")
	arena.queue_free(); await process_frame
	print("CHARGER_OBSTACLES ", JSON.stringify({"failures": failures, "cases": cases}))
	quit(0 if failures.is_empty() else 1)
