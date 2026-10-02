extends SceneTree
## Graphical training-arena acceptance. Uses the actual queued actor combo.
## Run independently: --path game --script res://tests/combo_feel.gd

const ARENA = preload("res://rogue/scenes/training_arena.tscn")
const STYLE = preload("res://presentation/combat/training_style.tres")
const STEP := 1.0 / 120.0
const OUTPUT_DIRECTORY := "E:/ShopGame/docs/previews"
const FRAME_LIMIT := 1200
var failures: Array[String] = []
var captures: Array[String] = []
var trace: Array[Dictionary] = []
var committed: Array[String] = []
var hits: Array[Dictionary] = []
var arena
var camera: Camera3D
var finished := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(120.0).timeout.connect(func():
		if not finished:
			check(false, "graphical acceptance watchdog expired")
			finish()
	)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	_new_arena()
	await create_timer(0.3).timeout
	await _test_queued_combo()
	_new_arena()
	await process_frame
	await _test_hit_camera()
	finish()


func _new_arena() -> void:
	if is_instance_valid(arena):
		arena.free()
	arena = ARENA.instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.set_process_unhandled_input(false)
	arena.brains.clear()
	camera = arena.get_node("Camera") as Camera3D
	camera.size = STYLE.camera_min_size
	arena.player.position = Vector3.ZERO
	arena.player.facing = Vector3(-STYLE.camera_offset.x, 0.0, -STYLE.camera_offset.z).normalized()
	arena._follow_camera()
	for index in range(1, arena.actors.size()):
		arena.actors[index].position = Vector3(7.0, 0.0, -7.0 + index)
		arena.actors[index].cancel()
	arena.player.runner.committed.connect(func(_cast_id: int, ability_id: String): committed.append(ability_id))
	arena.resolver.confirmed_hit.connect(func(source, target, cast_id: int, ability_id: String, amount: float):
		hits.append({"source": source.handle, "target": target.handle, "cast_id": cast_id, "ability": ability_id, "damage": amount})
	)
	_refresh(STEP)


func _test_queued_combo() -> void:
	committed.clear()
	hits.clear()
	var player = arena.player
	var right: Vector3 = player.facing.cross(Vector3.UP)
	var starting_position: Vector3 = player.position
	var queued_casts: Dictionary = {}
	var samples: Dictionary = {}
	var screenshots: Dictionary = {}
	var frames := 0
	player.movement = right
	player.request_attack()
	while frames < FRAME_LIMIT:
		player.step(STEP)
		arena.resolver.resolve(player, arena.actors)
		_refresh(STEP)
		frames += 1
		if player.runner.busy():
			var ability = player.runner.ability
			var id: String = ability.id
			if player.runner.phase() == "active":
				player.movement = Vector3.ZERO
				var sample := _blade_sample()
				if not samples.has(id): samples[id] = []
				samples[id].append(sample)
				trace.append(sample)
				var progress: float = (player.runner.elapsed - ability.windup) / ability.active
				if progress >= 0.65 and not screenshots.has(id):
					screenshots[id] = true
					await _capture({"slash.1": "slash_1", "slash.2": "slash_2", "slash.3": "thrust_3"}[id])
				# Queue the next request while the previous attack is still active.
				if committed.size() < 3 and not queued_casts.has(player.runner.cast_id):
					queued_casts[player.runner.cast_id] = true
					player.request_attack()
		if committed.size() >= 3 and not player.runner.busy(): break
		await process_frame
	check(frames < FRAME_LIMIT, "queued combo completes without a stalled timeline")
	check(committed == ["slash.1", "slash.2", "slash.3"], "real request_attack queue produces first, second, third in order")
	check(queued_casts.size() == 2, "second and third inputs were queued during their preceding attack")
	check(player.position.distance_to(starting_position) > 0.0, "player can move during an attack")
	check(hits.is_empty(), "all three empty swings produce no confirmed hit")
	check(_camera_offset() == Vector2.ZERO, "empty swings do not shake the camera")
	for id in ["slash.1", "slash.2", "slash.3"]:
		if not check(samples.has(id) and samples[id].size() >= 2, "active blade samples exist: " + id): continue
		var first: Dictionary = samples[id][0]
		var last: Dictionary = samples[id][-1]
		if id == "slash.1":
			check(first.side < last.side, "first slash travels from the actor's left to right")
			check(first.screen_x < last.screen_x, "first slash projects left to right on screen")
		elif id == "slash.2":
			check(first.side > last.side, "second slash travels from the actor's right to left")
			check(first.screen_x > last.screen_x, "second slash projects right to left on screen")
		else:
			check(last.forward > first.forward, "third strike extends forward")
			for sample in samples[id]:
				check(is_equal_approx(sample.side, first.side), "third strike retains its lateral axis without sweeping")
			check(player.attacks[2].hit_shape == "thrust", "third strike uses the actual narrow thrust hit shape")
	check(screenshots.size() == 3, "captured all three real combo stages")


func _test_hit_camera() -> void:
	hits.clear()
	var player = arena.player
	var target = arena.actors[1]
	var second_enemy = arena.actors[2]
	var forward: Vector3 = player.facing
	if not _next_player_active(): return
	target.position = player.position + forward * (player.runner.ability.radius / 2.0)
	arena._camera_shake.clear()
	arena._apply_camera_shake(0.0)
	var hp_before: float = target.health.current
	arena.resolver.resolve(player, [target])
	check(target.health.current < hp_before and hits.size() == 1, "a real player hit applies damage and emits one confirmed hit")
	var shake_step: float = STYLE.hit_camera_shake.duration_seconds / 8.0
	arena._apply_camera_shake(shake_step)
	check(_camera_offset().length() > 0.0, "confirmed player hit produces screen-plane camera motion")
	check(_camera_offset().length() <= STYLE.hit_camera_shake.maximum_offset_meters, "applied camera offset obeys the resource bound")
	var elapsed_before: float = arena._camera_shake._elapsed
	arena.resolver.resolve(player, [target])
	arena._apply_camera_shake(shake_step)
	check(hits.size() == 1, "a duplicate target contact in the same cast emits no second hit")
	check(is_equal_approx(arena._camera_shake._elapsed, elapsed_before + shake_step), "duplicate contact does not restart the shake timer")
	var paused_offset := _camera_offset()
	var paused_elapsed: float = arena._camera_shake._elapsed
	var camera_basis: Basis = camera.global_basis
	arena.paused = true
	arena._physics_process(STEP)
	check(_camera_offset() == paused_offset, "training pause freezes the displayed shake")
	check(arena._camera_shake._elapsed == paused_elapsed, "training pause freezes shake time")
	check(camera.global_basis.is_equal_approx(camera_basis), "shake leaves camera rotation unchanged")
	arena.paused = false
	await _test_stable_aim()
	arena._apply_camera_shake(STYLE.hit_camera_shake.duration_seconds)
	check(_camera_offset() == Vector2.ZERO, "expired hit shake restores the exact camera baseline")
	# Arrange a lethal real resolver hit, while keeping the second enemy alive.
	player.facing = forward
	if not _next_player_active(): return
	target.position = player.position + forward * (player.runner.ability.radius / 2.0)
	var remaining_hp: float = player.runner.ability.damage / 2.0
	if target.health.current > remaining_hp:
		target.receive_hit(target.health.current - remaining_hp)
	arena._camera_shake.clear()
	arena._apply_camera_shake(0.0)
	var count_before := hits.size()
	arena.resolver.resolve(player, [target])
	arena._apply_camera_shake(shake_step)
	check(not target.health.alive(), "test applies a lethal confirmed player strike")
	check(hits.size() == count_before + 1 and _camera_offset().length() > 0.0, "lethal hits retain camera feedback")
	# Enemy damage is confirmed through the same resolver, but must not kick it.
	player.cancel()
	player.movement = Vector3.ZERO
	second_enemy.cancel()
	second_enemy.position = player.position + forward * (second_enemy.attacks[0].radius / 2.0)
	second_enemy.facing = -forward
	second_enemy.request_attack()
	var frames := 0
	while second_enemy.runner.phase() != "active" and frames < FRAME_LIMIT:
		second_enemy.step(STEP)
		frames += 1
	if not check(frames < FRAME_LIMIT, "enemy enters a real active attack"): return
	arena._camera_shake.clear()
	arena._apply_camera_shake(0.0)
	hp_before = player.health.current
	arena.resolver.resolve(second_enemy, [player])
	arena._apply_camera_shake(shake_step)
	check(player.health.current < hp_before, "enemy attack really damages the player")
	check(_camera_offset() == Vector2.ZERO, "enemy damage does not trigger player-hit camera feedback")
	arena._camera_shake.kick()
	arena._apply_camera_shake(shake_step)
	arena._shutdown()
	check(_camera_offset() == Vector2.ZERO, "leaving training clears the camera offset")


func _test_stable_aim() -> void:
	# Choose a ground position with the unshaken camera, then retain its cursor.
	arena._camera_shake.clear()
	arena._apply_camera_shake(0.0)
	var aim_point: Vector3 = arena.player.global_position + arena.player.facing * 3.0
	root.warp_mouse(camera.unproject_position(aim_point))
	await process_frame
	arena.input_adapter.update()
	var stable_facing: Vector3 = arena.player.facing
	var stable_basis: Basis = camera.global_basis
	arena._camera_shake.kick()
	arena._apply_camera_shake(STYLE.hit_camera_shake.duration_seconds / 8.0)
	check(_camera_offset().length() > 0.0, "aim check begins with a nonzero display shake")
	arena._physics_process(0.0)
	check(arena.player.facing.is_equal_approx(stable_facing), "aim projection uses the unshaken camera before display offsets are reapplied")
	check(camera.global_basis.is_equal_approx(stable_basis), "camera feedback does not alter the aim basis")


func _next_player_active() -> bool:
	var frames := 0
	while (arena.player.runner.busy() or arena.player.runner.cooldown > 0.0) and frames < FRAME_LIMIT:
		arena.player.step(STEP)
		frames += 1
	arena.player.request_attack()
	while arena.player.runner.phase() != "active" and frames < FRAME_LIMIT:
		arena.player.step(STEP)
		frames += 1
	return check(frames < FRAME_LIMIT, "player naturally reaches the next active attack")


func _refresh(delta: float) -> void:
	for view in arena.views: view.refresh(delta)
	arena._follow_camera()
	arena._apply_camera_shake(delta)
	arena.hud.update_state(arena.player, arena.encounter, arena.catalog.waves().size(), arena.state, arena.paused)


func _blade_sample() -> Dictionary:
	var player = arena.player
	var blade: Node3D = arena.views[0].blade
	var tip: Vector3 = blade.to_global(Vector3(0.0, 0.0, -STYLE.blade_size.z / 2.0))
	var relative: Vector3 = tip - player.global_position
	var direction: Vector3 = player.runner.direction
	var screen: Vector2 = camera.unproject_position(tip)
	return {"ability": player.runner.ability.id, "elapsed": player.runner.elapsed,
		"world_tip": [tip.x, tip.y, tip.z], "side": direction.cross(Vector3.UP).dot(relative),
		"forward": direction.dot(relative), "screen_x": screen.x, "screen_y": screen.y}


func _capture(stage: String) -> void:
	var effect: Node3D = arena.views[0].weapon_effect
	effect.set_time_running(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT_DIRECTORY + "/combo_v001_" + stage + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "screenshot written: " + stage)
	captures.append(path)
	effect.set_time_running(true)


func _camera_offset() -> Vector2:
	return Vector2(camera.h_offset, camera.v_offset)


func check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
		push_error(label)
	return condition


func finish() -> void:
	if finished: return
	finished = true
	var trace_file := FileAccess.open("E:/ShopGame/builds/combo_v001_trace.json", FileAccess.WRITE)
	if trace_file != null: trace_file.store_string(JSON.stringify(trace, "\t"))
	print("COMBO_FEEL ", JSON.stringify({"failures": failures, "captures": captures, "blade_samples": trace.size()}))
	quit(0 if failures.is_empty() else 1)
