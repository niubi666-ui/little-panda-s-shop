extends "res://tests/enemy_roles.gd"
## Exercise real actor/motor motion at non-axis-aligned, off-origin endpoints.
var cases := 0
func run() -> void:
	combat = CombatLoader.new().load_catalog()
	enemies = EnemyLoader.new().load_catalog(combat)
	world = Node3D.new()
	root.add_child(world)
	for fps in [30, 60, 120]:
		for scale in [1.0, 0.5]:
			for start in [Vector3(17.43, 0, -12.8), Vector3(25.75, 0, -26.7)]:
				for angle in [1.0, 8.0, 19.0, 133.0]:
					await check_endpoint(start, deg_to_rad(angle), fps, scale)
	await check_no_progress()
	await check_final_contact()
	world.free()
	print("CHARGER_COMPLETION ", JSON.stringify({"failures": failures, "cases": cases}))
	quit(0 if failures.is_empty() else 1)

func check_endpoint(start: Vector3, angle: float, fps: int, scale: float) -> void:
	var direction := Vector3.RIGHT.rotated(Vector3.UP, angle)
	var player = actor("player", start + direction * 6.0)
	var spear = actor("charger", start)
	spear.set_control(scale, false)
	var r = runtime(player)
	var brain = add(r, spear)
	await physics_frame
	brain.tick(1.0 / fps)
	check(brain.state == "windup", "test enters a real charge windup")
	player.position += direction.cross(Vector3.UP) * 8.0
	await physics_frame
	brain.tick(brain.time_left)
	var dt := 1.0 / fps
	var limit := ceili(brain.config.charge_distance_m / (brain.config.charge_speed_mps * scale) * fps) + 30
	for frame in limit:
		if frame > 0: brain.tick(dt)
		spear.step(dt)
		brain.after_motion(r.target_radius)
		if brain.state == "recovery": break
	var label := "start=%s angle=%.0f fps=%d slow=%.1f" % [start, rad_to_deg(angle), fps, scale]
	check(brain.state == "recovery", "charge terminates: " + label)
	check(absf(start.distance_to(spear.position) - brain.config.charge_distance_m) < 0.001, "charge retains configured distance: " + label)
	check(spear.forced_velocity == Vector3.ZERO, "no stale charge intent: " + label)
	check(player.health.current == player.health.maximum, "sidestep remains safe: " + label)
	if brain.state == "recovery":
		var contact: Vector3 = spear.position
		brain.tick(brain.time_left)
		player.position = contact + direction.cross(Vector3.UP) * (brain.config.trigger_range_m + 1.0)
		brain.tick(dt)
		check(brain.state == "seeking" and not spear.movement.is_zero_approx(), "resumes pursuit after recovery: " + label)
	cases += 1
	r.clear()
	reset()

func check_no_progress() -> void:
	var player = actor("player", Vector3(6, 0, 0))
	var spear = actor("charger", Vector3.ZERO)
	var r = runtime(player)
	var brain = add(r, spear)
	await physics_frame
	brain.tick(1.0 / 60.0)
	player.position.z = 8.0
	await physics_frame
	brain.tick(brain.time_left)
	# A ground constraint can reject motion without reporting a body collision.
	var before: Vector3 = spear.position
	spear.step(1.0 / 60.0)
	spear.position = before
	check(not spear.motor.blocked, "no collision was reported by the motor")
	r.after_motion(0.0)
	check(brain.state == "charging", "paused frame cannot trigger the no-progress guard")
	r.after_motion(1.0 / 60.0)
	check(brain.state == "recovery" and spear.forced_velocity == Vector3.ZERO, "no forward progress stops a charge without a collision callback")
	cases += 1
	r.clear()
	reset()

func check_final_contact() -> void:
	var player = actor("player", Vector3(6, 0, 0))
	var spear = actor("charger", Vector3.ZERO)
	var r = runtime(player)
	var brain = add(r, spear)
	await physics_frame
	brain.tick(1.0 / 60.0)
	player.position.x = brain.config.charge_distance_m + brain.config.hit_radius_m + r.target_radius - 0.01
	await physics_frame
	brain.tick(brain.time_left)
	for frame in 60:
		if frame > 0: brain.tick(1.0 / 60.0)
		spear.step(1.0 / 60.0)
		brain.after_motion(r.target_radius)
		if brain.state == "recovery": break
	check(brain.state == "recovery", "last motion step recovers")
	var expected: float = brain.attack_request.components[0].basis * preload("res://combat/effects/damage_formula.gd").mitigation(player.attribute_catalog, "physical", player.attributes.final)
	check(is_equal_approx(player.health.maximum - player.health.current, expected), "last motion step still deals exactly one impact")
	var hp: float = player.health.current
	brain.after_motion(r.target_radius)
	check(player.health.current == hp, "recovery cannot repeat impact")
	cases += 1
	r.clear()
	reset()
