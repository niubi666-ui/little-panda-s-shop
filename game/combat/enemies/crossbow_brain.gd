extends "res://combat/enemies/role_brain.gd"
signal shot_requested(source, direction: Vector3, settings: Dictionary)
func tick(delta: float) -> void:
	if not begin_tick(delta): return
	if state == "windup":
		time_left -= delta
		if time_left <= 0.0:
			var shot := config.duplicate(true)
			shot.damage_request = attack_request
			shot_requested.emit(actor, locked_direction, shot)
			state = "recovery"
			time_left = config.recovery_sec / attack_tempo
			recovery_duration = time_left
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
		commit_attack(config.damage_profile_id)
		actor.movement = Vector3.ZERO
		locked_direction = actor.facing
		state = "windup"
		time_left = actor.attack_windup(config.damage_profile_id, config.windup_sec)
		windup_duration = time_left
		cooldown = actor.skill_cooldown(config.shot_interval_sec)
