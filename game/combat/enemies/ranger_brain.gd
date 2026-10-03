extends "res://combat/enemies/role_brain.gd"
## One committed action, bounded reposition, and an attack-gated roll token.
signal shot_requested(source, direction: Vector3, settings: Dictionary)
signal rain_requested(source, center: Vector3, settings: Dictionary)
signal action_started(id: String, cast_id: int)
var attack_id := ""
var cast_id := 0
var target_point := Vector3.ZERO
var roll_direction := Vector3.ZERO
var roll_duration := 0.0
var roll_distance := 0.0
var roll_left := 0.0
var roll_ready := true
var roll_cooldown := 0.0
var threat_age := 0.0
var adjust_left := 0.0
var decision_left := 0.0
var recovery_duration := 0.0
var last_attack := ""
var locked_distance := 0.0
var repeat_count := 0
var cooldowns := {"fast":0.0, "volley":0.0, "rain":0.0}
var random := RandomNumberGenerator.new()
var roll_path: Callable
var ground: Callable
var _attack_since_roll := false
var _interrupt_recovery := false

func configure_queries(queries: Dictionary) -> void:
	roll_path = queries.roll_path
	ground = queries.ground
	random.seed = int(queries.seed)
	adjust_left = config.reposition_sec

func tick(delta: float) -> void:
	actor.movement = Vector3.ZERO
	actor.forced_velocity = Vector3.ZERO
	for id in cooldowns: cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	if not actor.health.alive() or not target.health.alive():
		state = "dead" if not actor.health.alive() else "idle"
		return
	if actor.control_locked or actor.stagger_left > 0.0:
		if state in ["windup", "rolling"]: cancel()
		return
	if _interrupt_recovery:
		_interrupt_recovery = false
		state = "recovery"
		time_left = config.interrupt_recovery_sec
		recovery_duration = time_left
	if state == "recovery":
		time_left -= delta
		if time_left <= 0.0:
			if _attack_since_roll: roll_ready = true
			state = "idle"
			adjust_left = config.reposition_sec
		return
	if state == "rolling":
		roll_left = maxf(0.0, roll_left - delta)
		if roll_left <= 0.0:
			state = "idle"
			adjust_left = config.reposition_sec
		else: actor.forced_velocity = roll_direction * roll_distance / config.roll_duration_sec
		return
	if state == "windup":
		if attack_id != "rain" and time_left > config[attack_id + "_lock_sec"]:
			var desired := offset().normalized()
			var angle := locked_direction.signed_angle_to(desired, Vector3.UP)
			locked_direction = locked_direction.rotated(Vector3.UP, clampf(angle, -config.turn_speed_radps * delta, config.turn_speed_radps * delta))
			actor.facing = locked_direction
			locked_distance = offset().length()
		time_left -= delta
		if time_left <= 0.0:
			if attack_id == "rain": rain_requested.emit(actor, target_point, config)
			else:
				var shot := {"damage":config[attack_id + "_damage"], "projectile_speed_mps":config[attack_id + "_speed_mps"], "projectile_radius_m":config.arrow_radius_m, "projectile_lifetime_sec":config.arrow_lifetime_sec, "ranger_arrow":true, "volley_id":str(actor.handle) + ":" + str(cast_id), "aim_distance_m":locked_distance, "spawn_height_m":config.arrow_height_m, "spawn_forward_m":config.arrow_spawn_forward_m}
				var count := int(config.volley_count) if attack_id == "volley" else 1
				for index in count:
					var angle := deg_to_rad(config.volley_angle_deg) * (float(index) / (count - 1) - 0.5) if count > 1 else 0.0
					shot_requested.emit(actor, locked_direction.rotated(Vector3.UP, angle), shot)
			state = "recovery"
			time_left = config[attack_id + "_recovery_sec"]
			recovery_duration = time_left
		return
	var distance := offset().length()
	if distance > actor.definition.aggro_range: return
	aim()
	threat_age = threat_age + delta if distance <= config.roll_trigger_m and visible_target() else 0.0
	if roll_ready and roll_cooldown <= 0.0 and threat_age >= config.roll_reaction_sec:
		# Prefer full distance; bounded fallback helps large bodies near cover.
		for distance_m in [config.roll_distance_m, config.roll_min_distance_m]:
			for side in [1.0, -1.0, 1.5, -1.5, 2.0]:
				var direction: Vector3 = actor.facing.rotated(Vector3.UP, side * PI / 2.0)
				if roll_path.call(actor, direction * distance_m):
					roll_ready = false
					_attack_since_roll = false
					roll_cooldown = config.roll_cooldown_sec
					roll_duration = config.roll_duration_sec
					roll_left = roll_duration
					roll_distance = distance_m
					roll_direction = direction
					state = "rolling"
					threat_age = 0.0
					actor.forced_velocity = direction * distance_m / roll_duration
					action_started.emit("roll", cast_id)
					return
	decision_left -= delta
	if decision_left <= 0.0:
		decision_left = actor.definition.decision_interval
		var legal: Array[String] = []
		if visible_target() and distance <= config.fire_range_m:
			for id in ["fast", "volley"]:
				if cooldowns[id] <= 0.0: legal.append(id)
		if distance >= config.rain_min_range_m and distance <= config.fire_range_m and cooldowns.rain <= 0.0 and ground.call(target.global_position): legal.append("rain")
		if not legal.is_empty():
			if last_attack.is_empty() and legal.has("fast"): legal = ["fast"]
			elif not roll_ready and legal.has("fast"): legal = ["fast"]
			elif legal.size() > 1 and repeat_count >= int(config.max_repeat): legal.erase(last_attack)
			var total := 0.0
			for id in legal: total += config[id + "_weight"]
			var pick := random.randf() * total
			var chosen: String = legal.back()
			for id in legal:
				pick -= config[id + "_weight"]
				if pick <= 0.0:
					chosen = id
					break
			_start(chosen)
			return
	# A bounded movement interval is followed by an explicit stationary decision pause.
	adjust_left -= delta
	if adjust_left > 0.0:
		state = "seeking"
		if not visible_target() or distance > config.safe_max_m: approach()
		elif distance < config.safe_min_m: retreat(config.retreat_speed_multiplier)
	elif adjust_left <= -config.reposition_pause_sec:
		adjust_left = config.reposition_sec

func _start(id: String) -> void:
	attack_id = id
	cast_id += 1
	state = "windup"
	locked_direction = actor.facing
	locked_distance = offset().length()
	target_point = target.global_position
	time_left = config[id + "_windup_sec"]
	windup_duration = time_left
	cooldowns[id] = config[id + "_cooldown_sec"]
	repeat_count = repeat_count + 1 if last_attack == id else 1
	last_attack = id
	_attack_since_roll = true
	actor.movement = Vector3.ZERO
	action_started.emit(id, cast_id)

func cancel() -> void:
	# Interruption consumes the committed action; frozen/unfrozen never resumes its cue.
	_interrupt_recovery = true
	state = "interrupted"
	time_left = 0.0
	roll_left = 0.0
	actor.movement = Vector3.ZERO
	actor.forced_velocity = Vector3.ZERO
