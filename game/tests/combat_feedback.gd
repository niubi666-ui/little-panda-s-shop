extends SceneTree
const BarState = preload("res://presentation/combat/damage_bar_state.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func run() -> void:
	var trail := BarState.new(.1, 1.0)
	trail.set_health(.7)
	check(trail.current == .7 and trail.trailing == 1.0, "damage immediately creates white segment")
	trail.tick(.05)
	check(trail.trailing == 1.0, "white segment holds")
	trail.tick(.15)
	check(is_equal_approx(trail.trailing, .9), "white segment drains with remaining frame time")
	trail.set_health(.5)
	check(is_equal_approx(trail.trailing, .9), "rapid hits retain previous white segment")
	trail.tick(2.0)
	check(trail.trailing == .5, "trail converges without undershoot")
	trail.set_health(0.0)
	trail.tick(2.0)
	check(trail.trailing == 0.0, "lethal trail reaches zero")
	var arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	TranslationServer.set_locale("zh_CN")
	arena.hud.refresh_text()
	await create_timer(.2).timeout
	var player = arena.player
	var enemy = arena.actors[1]
	var other = arena.actors[2]
	var fixed_delta := 1.0 / Engine.physics_ticks_per_second
	player.position = Vector3.ZERO
	player.facing = Vector3.FORWARD
	player.movement = Vector3.RIGHT
	player.request_attack()
	await physics_frame
	player.step(fixed_delta)
	check(player.runner.busy() and player.velocity.x > 0.0 and player.position.x > 0.0, "move during attack windup")
	player.runner.tick(player.runner.ability.windup)
	await physics_frame
	player.step(fixed_delta)
	check(player.runner.phase() == "active" and player.velocity.x > 0.0, "move during attack active phase")
	player.runner.tick(player.runner.ability.active)
	await physics_frame
	player.step(fixed_delta)
	check(player.runner.phase() == "recovery" and player.velocity.x > 0.0, "move during attack recovery")
	player.cancel()
	player.position = Vector3.ZERO
	enemy.position = Vector3(0, 0, -1.2)
	other.position = Vector3(5, 0, -2)
	player.runner.cooldown = 0.0
	player.runner.start(arena.catalog.ability("slash.2"), Vector3.FORWARD)
	player.runner.tick(player.runner.ability.windup)
	var before: float = enemy.health.current
	arena.resolver.resolve(player, [enemy])
	check(enemy.health.current == before - player.runner.ability.damage, "second combo deals configured damage")
	check(enemy.motor.impulse_left > 0.0, "second combo starts knockback")
	var feedback = arena.views[1].hit_feedback
	check(feedback.flash_left > 0.0 and feedback._bursts.size() == 1, "hit starts body flash and particle burst")
	check(feedback.bar_state.trailing > feedback.bar_state.current, "enemy has delayed white bar")
	for mesh in feedback._overlays:
		check(mesh.material_override == feedback.settings.flash_material, "every body mesh receives white/red material")
	for mesh in arena.views[2].hit_feedback._overlays:
		check(mesh.material_override == null and mesh.material_overlay == null, "other enemy materials remain independent")
	var burst_count: int = feedback._bursts.size()
	arena.resolver.resolve(player, [enemy])
	check(feedback._bursts.size() == burst_count, "deduplicated hits do not duplicate VFX")
	for view in arena.views: view.refresh(fixed_delta)
	arena.hud.update_state(player, arena.encounter, arena.catalog.waves().size(), arena.state, false)
	arena.get_node("Camera").size = arena.Style.camera_min_size
	arena._follow_camera()
	for i in 4:
		await physics_frame
		player.runner.tick(fixed_delta)
		arena.views[0].refresh(fixed_delta)
	await create_timer(.03).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/combat_feedback_hit.png")
	var initial: Vector3 = enemy.position
	for i in 30:
		await physics_frame
		enemy.step(fixed_delta)
		arena.views[1].refresh(fixed_delta)
	check(enemy.position.z < initial.z - .8, "knockback actually moves enemy")
	check(enemy.motor.impulse_left == 0.0, "knockback expires")
	for mesh in feedback._overlays:
		check(mesh.material_override == feedback._overlays[mesh][0] and mesh.material_overlay == feedback._overlays[mesh][1], "original material restored")
	# Replacing weapon visuals leaves the active rule cast untouched.
	var cast_id: int = player.runner.cast_id
	arena.views[0].set_weapon_effect(arena.Style.weapon_effect_scene)
	check(player.runner.cast_id == cast_id, "replace weapon effect without changing rules")
	# Live collision must stop knockback at the scene boundary.
	enemy.position = Vector3(0, 0, -10.5)
	enemy.apply_knockback(Vector3.FORWARD, 10.0, .24)
	for i in 30:
		await physics_frame
		enemy.step(fixed_delta)
	check(enemy.position.z > -11.15, "knockback cannot tunnel through wall")
	# No impulse/flash on an invulnerability-rejected hit.
	player.dodge_left = player.dodge.duration
	player.dodge_age = 0.0
	enemy.position = player.position + Vector3(0, 0, -1)
	enemy.runner.cooldown = 0.0
	enemy.runner.start(arena.catalog.ability("enemy.swipe"), Vector3.BACK)
	enemy.runner.tick(enemy.runner.ability.windup)
	var hp: float = player.health.current
	arena.resolver.resolve(enemy, [player])
	check(player.health.current == hp and player.motor.impulse_left == 0.0, "invulnerable hit has no damage or knockback")
	enemy.receive_hit(enemy.health.maximum)
	arena.views[1].refresh(fixed_delta)
	check(not enemy.health.alive() and arena.views[1].visible and feedback.visual.visible, "death retains hit flash tail")
	for i in 120: arena.views[1].refresh(fixed_delta)
	check(not feedback.visual.visible and not feedback.bar.visible, "death body and bar finish without delaying rules")
	arena.free()
	await process_frame
	print("COMBAT_FEEDBACK ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
