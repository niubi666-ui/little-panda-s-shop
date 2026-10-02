extends "res://combat/enemies/role_brain.gd"
signal shot_requested(source, direction: Vector3, settings: Dictionary)
func tick(delta: float) -> void:
	if not begin_tick(delta): return
	if state == "windup":
		time_left -= delta
		if time_left <= 0.0:
			shot_requested.emit(actor, locked_direction, config)
			state = "recovery"
			time_left = config.recovery_sec
		return
	if state == "recovery":
		time_left -= delta
		if time_left <= 0.0: state = "idle"
		return
	aim()
	var distance := offset().length()
	if distance > actor.definition.aggro_range:
		state = "idle"
		return
	if distance < config.safe_min_m:
		state = "retreating"
		retreat(config.retreat_speed_multiplier)
		return
	if distance > config.safe_max_m or not visible_target():
		state = "seeking"
		approach()
	else: state = "aiming"
	if distance <= config.fire_range_m and visible_target() and cooldown <= 0.0:
		actor.movement = Vector3.ZERO
		locked_direction = actor.facing
		state = "windup"
		time_left = maxf(config.minimum_windup_sec, config.windup_sec / actor.enemy_attack_multiplier)
		windup_duration = time_left
		cooldown = config.shot_interval_sec / actor.enemy_attack_multiplier
