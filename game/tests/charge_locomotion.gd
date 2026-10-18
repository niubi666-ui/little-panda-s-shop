extends "res://tests/action_build_runtime.gd"
## Real native skeleton: charge upper body, eight-direction gait, pause and release.
const Visual = preload("res://presentation/combat/rigs/nodachi_visual.tscn")
const DT := 1.0 / 60.0
var out: String
var visual
var reference
var camera: Camera3D

func run() -> void:
	out = ProjectSettings.globalize_path("res://../builds/charge_motion_review/")
	DirAccess.make_dir_recursive_absolute(out)
	builds = BuildLoader.new().load_catalog()
	combat = CombatLoader.new().load_catalog()
	resolver.configure(builds)
	var f := setup([select("ice_core", "skill"), select("charged_wave", "skill")])
	var p = f.player
	visual = Visual.instantiate(); p.add_child(visual)
	reference = Visual.instantiate(); root.add_child(reference); reference.hide()
	await process_frame
	check(visual.validate_assets(), "native assets and charge blend config valid")
	_setup_review()
	p.facing = Vector3.FORWARD
	p.charging_skill = true
	var leg: int = visual.skeleton.find_bone("calf_l")
	var arm: int = visual.skeleton.find_bone("upperarm_r")
	for speed in [2.5, p.definition.speed]:
		for direction in 8:
			p.velocity = Vector3(sin(direction * TAU / 8.0), 0, -cos(direction * TAU / 8.0)) * speed
			for i in 20: visual.refresh_actor(p, DT)
			var first: Quaternion = visual.skeleton.get_bone_pose_rotation(leg)
			for i in 12: visual.refresh_actor(p, DT)
			check(first.angle_to(visual.skeleton.get_bone_pose_rotation(leg)) > 0.03, "legs step while charging: " + str([speed, direction]))
			var expected: StringName = visual.nodachi.walk_directions[direction] if speed < visual.nodachi.walk_below_speed else visual.nodachi.run_directions[direction]
			check(visual._charge_gait == expected, "charge uses matching directional gait: " + str([speed, direction]))
			reference.animation.play("charge"); reference.animation.seek(fmod(visual._clock, visual._length("charge")), true)
			check(visual.skeleton.get_bone_pose_rotation(arm).is_equal_approx(reference.skeleton.get_bone_pose_rotation(arm)), "arms retain charge instead of walking: " + str([speed, direction]))
			if speed == 2.5 and direction == 2: await capture("charge_strafe")
	var phase: float = visual._charge_gait_phase
	var pose: Quaternion = visual.skeleton.get_bone_pose_rotation(leg)
	for i in 10: visual.refresh_actor(p, 0.0)
	check(is_equal_approx(phase, visual._charge_gait_phase) and pose.is_equal_approx(visual.skeleton.get_bone_pose_rotation(leg)), "pause freezes both animation layers")
	p.control_locked = true
	for i in 8: visual.refresh_actor(p, DT)
	check(is_equal_approx(phase, visual._charge_gait_phase), "freeze cannot advance gait")
	p.control_locked = false
	p.velocity = Vector3.ZERO
	for i in 20: visual.refresh_actor(p, DT)
	reference.animation.play("charge"); reference.animation.seek(fmod(visual._clock, visual._length("charge")), true)
	check(visual._charge_gait.is_empty() and visual.skeleton.get_bone_pose_rotation(leg).is_equal_approx(reference.skeleton.get_bone_pose_rotation(leg)), "stopping returns to stationary charge smoothly")
	await capture("charge_still")
	p.velocity = Vector3.RIGHT * 2.5
	for i in 20: visual.refresh_actor(p, DT)
	# Skill release enters the real action/cue path; the visual must not change its damage/cooldown.
	p.charge_elapsed = p.charge_parameters().threshold_sec
	p.release_skill()
	p.step(DT)
	visual.refresh_actor(p, DT)
	check(p.runner.busy() and visual._clip == &"cast" and visual._charge_gait.is_empty(), "release blends into actual wave cast")
	await capture("charge_release")
	for i in 120:
		if not f.runtime.projectiles().is_empty(): break
		p.step(DT); f.runtime.tick(DT); visual.refresh_actor(p, DT)
	check(not f.runtime.projectiles().is_empty(), "wave emits at the actual configured swing cue")
	if not f.runtime.projectiles().is_empty():
		var wave: Dictionary = f.runtime.projectiles()[0]
		check(wave.charged and is_equal_approx(wave.radius, builds.projectile("sword_wave").radius_m * p.charge_parameters().radius_ratio), "full charge preserves configured wide projectile")
	p.cancel(); p.dodge_left = 0.0; p.stagger_left = 0.0; p.charging_skill = true
	for i in 20: visual.refresh_actor(p, DT)
	p.health.apply(p.health.current, false)
	visual.refresh_actor(p, .2)
	check(visual._clip == &"death" and visual._charge_gait.is_empty(), "death overrides charge layers")
	print("CHARGE_LOCOMOTION ", JSON.stringify({"failures": failures}))
	reference.free(); clean(f)
	quit(0 if failures.is_empty() else 1)

func _setup_review() -> void:
	if DisplayServer.get_name() == "headless": return
	root.size = Vector2i(1000, 720)
	var world := WorldEnvironment.new(); world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR; world.environment.background_color = Color(.07,.09,.10)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.7,.75,.8); world.environment.ambient_light_energy = .6
	root.add_child(world)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-35,0); light.light_energy = 1.5; root.add_child(light)
	camera = Camera3D.new(); root.add_child(camera); camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 4.5
	camera.position = Vector3(4, 2.5, -6); camera.look_at(Vector3.UP)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 3: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + label + ".png")
