extends SceneTree
## Native Manny/Nodachi acceptance using the real combat actor, animation adapter and room.
const OUT := "E:/ShopGame/builds/nodachi_review/"
var arena
var player
var view
var camera: Camera3D
var failures: Array[String] = []
var checks := 0
var committed: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	create_timer(300.0).timeout.connect(func(): push_error("Nodachi test timeout"); quit(1))
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.set_process_unhandled_input(false)
	arena.encounter.cancel()
	arena.input_adapter.actor = null
	player = arena.player
	view = arena.views[0]
	player.collision_mask = 0
	player.position = Vector3(0, player.position.y, 1.5)
	player.facing = Vector3(0, 0, 1)
	for actor in arena.actors:
		if actor != player: actor.position = Vector3(60, 0, 60)
	arena.get_node("UIRoot").hide()
	# Close review views need native resolution; the forest's temporal upscaler is tuned for its game camera.
	root.scaling_3d_scale = 1.0
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.use_taa = false
	camera = arena.get_node("Camera")
	await process_frame
	check(view.visual.validate_assets(), "all 34 clips and real sword anchors resolve")
	check(view.animation.get_animation_list().size() == 34, "only approved native clips exported")
	check(view.animation.get_animation("death").loop_mode == Animation.LOOP_NONE, "death must not loop back to standing")
	check(view.visual.skeleton.get_bone_count() >= 89, "native Manny skeleton retained")
	check(view.visual.weapon_fx_length() > 1.2 and view.visual.weapon_fx_length() < 1.6, "weapon has plausible meter scale")
	view.refresh(0.016)
	await capture("godot_idle")
	var clips = view.visual.nodachi
	for i in 8:
		var direction := Vector3(sin(i * TAU / 8.0), 0, -cos(i * TAU / 8.0))
		player.facing = Vector3.FORWARD
		player.velocity = direction * player.definition.speed
		view.refresh(0.12)
		check(view.visual._clip == clips.run_directions[i], "run direction " + str(i))
		player.velocity = direction * 2.5
		view.refresh(0.12)
		check(view.visual._clip == clips.walk_directions[i], "walk direction " + str(i))
		player.velocity = Vector3.ZERO
		player.dodge_left = player.dodge.duration
		player.dodge_age = 0.0
		player.dodge_direction = direction
		view.refresh(0.05)
		check(view.visual._clip == clips.roll_directions[i], "roll direction " + str(i))
		player.dodge_age = player.dodge.duration * 0.45
		player.dodge_left -= player.dodge_age
		view.refresh(0.16)
		var locked_basis: Basis = view.visual.model.global_basis
		player.facing = Vector3.RIGHT
		view.refresh(0.016)
		check(view.visual._clip == clips.roll_directions[i], "mouse movement cannot change roll clip " + str(i))
		check(view.visual.model.global_basis.is_equal_approx(locked_basis), "mouse movement cannot spin body during roll " + str(i))
		if i in [0,2,4,6]: await capture("godot_" + String(clips.roll_directions[i]))
		player.dodge_left = 0.0
		view.refresh(0.016)
	player.facing = Vector3(0,0,1)
	player.runner.committed.connect(func(_id: int, ability: String): committed.append(ability))
	for action in ["primary", "primary", "primary", "special", "skill"]:
		await play_action(action)
	check(committed == ["slash.1", "slash.2", "slash.3", "heavy_slash", "wave_cast"], "actual action queue covers combo, heavy and cast")
	# Full roll: fixed displacement gives way to held movement during stand-up.
	player.position = Vector3(0,player.position.y,1.5)
	player.movement = Vector3.FORWARD
	player.charges = player.dodge.charges
	player.request_dodge()
	var moving_time := 0.0
	var recovering := false
	for i in 44:
		await physics_frame
		player.step(1.0/60.0)
		view.refresh(1.0/60.0)
		if player.dodge_left > 0.0 and player.dodge_age > player.dodge.movement_duration:
			recovering = true
			check(is_equal_approx(player.velocity.length(),player.definition.speed), "roll stand-up immediately allows held movement")
			check(not player.invulnerable(), "roll recovery does not extend invulnerability")
	check(recovering, "roll reaches stand-up phase")
	player.movement = Vector3.ZERO
	player.velocity = Vector3.ZERO
	view.refresh(.1)
	var clock: float = view.visual._clock
	var pose: Quaternion = view.visual.skeleton.get_bone_pose_rotation(5)
	for i in 8: view.refresh(0.0)
	check(is_equal_approx(clock, view.visual._clock) and pose.is_equal_approx(view.visual.skeleton.get_bone_pose_rotation(5)), "pause freezes pose and animation clock")
	player.health.apply(player.health.current, false)
	view.refresh(1.0)
	check(view.visual._clip == &"death", "death uses native reaction, not idle")
	view.refresh(5.0)
	var final_pose: Transform3D = view.visual.skeleton.get_bone_global_pose(view.visual.skeleton.find_bone("pelvis"))
	view.refresh(1.0)
	check(final_pose.is_equal_approx(view.visual.skeleton.get_bone_global_pose(view.visual.skeleton.find_bone("pelvis"))), "finished death holds its final pose")
	await capture("godot_death")
	var report := {"checks": checks, "failures": failures, "committed": committed}
	FileAccess.open(OUT + "godot_acceptance.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NODACHI_ACCEPTANCE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func play_action(action: String) -> void:
	player.position = Vector3(0, player.position.y, 1.5)
	player.movement = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.motor.clear_impulse()
	player.request_action(action)
	var started := false
	var samples: Array[Image] = []
	var captured: Dictionary = {}
	for i in 240:
		await physics_frame
		player.step(1.0/60.0)
		view.refresh(1.0/60.0)
		if player.runner.busy():
			started = true
			var ability = player.runner.ability
			var phase: String = player.runner.phase()
			if not captured.has(phase):
				captured[phase] = true
				await capture("godot_" + ability.id + "_" + phase)
			if phase == "active":
				check(view.visual._clip == view.visual.clip_set.attacks[ability.id], "attack maps to native clip " + ability.id)
				var expected: Transform3D = view.visual.weapon_fx_transform()
				check(view.blade.global_position.distance_to(expected.origin)<.01, "VFX follows real sword " + ability.id)
				if not captured.has("active_mid") and player.runner.elapsed > ability.windup + ability.active*.5:
					captured.active_mid = true
					await capture("godot_"+ability.id+"_active_mid")
		elif started: break
	check(started and not player.runner.busy(), "action starts and completes " + action)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40
	camera.global_position = player.global_position + Vector3(-3.4,2.8,5.5)
	camera.look_at(player.global_position + Vector3.UP * .85)
	for i in 3: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
