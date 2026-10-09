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
var cooldowns := {"fast":0.0, "volley":0.0, "rain":0.0, "charged":0.0, "burst":0.0, "combo":0.0}
var random := RandomNumberGenerator.new()
var roll_path: Callable
var ground: Callable
var _attack_since_roll := false
var _interrupt_recovery := false
var _interrupt_recovery_time := 0.0
var _roll_retry_left := 0.0
var action_id := ""
var phase_two := false
var pending_steps: Array[String] = []
var rain_admission: Callable
var rain_busy: Callable
var charged_admission: Callable
var _combo_since_single := false

func configure_queries(queries: Dictionary) -> void:
	roll_path = queries.roll_path
	ground = queries.ground
	rain_admission = queries.rain_admission
	rain_busy = queries.rain_busy
	charged_admission = queries.charged_admission
	random.seed = int(queries.seed)
	adjust_left = config.reposition_sec

func tick(delta: float) -> void:
	actor.movement = Vector3.ZERO
	actor.forced_velocity = Vector3.ZERO
	for id in cooldowns: cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	_roll_retry_left = maxf(0.0, _roll_retry_left - delta)
	if not actor.health.alive() or not target.health.alive():
		pending_steps.clear()
		state = "dead" if not actor.health.alive() else "idle"
		return
	phase_two = phase_two or actor.health.current <= actor.health.maximum * config.phase_two_health_ratio
	if actor.control_locked or actor.stagger_left > 0.0:
		if state in ["windup", "rolling", "sequence_gap"]: cancel()
		return
	# Sense pressure during aiming and recovery, not only idle decision frames.
	_sense_pressure(delta)
	if _interrupt_recovery:
		_interrupt_recovery = false
		state = "recovery"
		time_left = _interrupt_recovery_time
		recovery_duration = time_left
	if state == "recovery":
		time_left -= delta
		if time_left <= 0.0:
			if _attack_since_roll: roll_ready = true
			state = "idle"
			adjust_left = config.reposition_sec
		return
	if state == "rolling":
		_drive_roll(delta)
		return
	if state == "sequence_gap":
		time_left -= delta
		if time_left <= 0.0:
			var next: String = pending_steps.pop_front()
			if next == "rain" and not rain_admission.call(actor, target.global_position, config):
				pending_steps.clear()
				_finish_action()
			else: _begin_step(next)
		return
	if state == "windup":
		if attack_id != "rain" and time_left > config[attack_id + "_lock_sec"]:
			var desired := offset().normalized()
			var angle := locked_direction.signed_angle_to(desired, Vector3.UP)
			var tracking_time: float = minf(delta, time_left - config[attack_id + "_lock_sec"])
			locked_direction = locked_direction.rotated(Vector3.UP, clampf(angle, -config.turn_speed_radps * tracking_time, config.turn_speed_radps * tracking_time))
			actor.facing = locked_direction
			locked_distance = offset().length()
		time_left -= delta
		if time_left <= 0.0:
			if attack_id == "rain": rain_requested.emit(actor, target_point, config)
			else:
				var shot := {"damage":config[attack_id + "_damage"], "projectile_speed_mps":config[attack_id + "_speed_mps"], "projectile_radius_m":config.arrow_radius_m, "projectile_lifetime_sec":config.arrow_lifetime_sec, "ranger_arrow":true, "charged":attack_id == "charged", "volley_id":str(actor.handle) + ":" + str(cast_id), "aim_distance_m":locked_distance, "spawn_height_m":config.arrow_height_m, "spawn_forward_m":config.arrow_spawn_forward_m}
				if attack_id == "charged":
					shot.projectile_lifetime_sec = config.charged_range_m / config.charged_speed_mps
					shot.rift = {"range_m":config.charged_range_m,"half_width_m":config.charged_rift_half_width_m,"duration_sec":config.charged_rift_duration_sec,"interval_sec":config.charged_rift_interval_sec,"damage":config.charged_rift_damage,"max_areas":config.charged_rift_max_areas,"charge_sec":config.charged_windup_sec}
				var count := int(config.volley_count) if attack_id == "volley" else 1
				for index in count:
					var angle := deg_to_rad(config.volley_angle_deg) * (float(index) / (count - 1) - 0.5) if count > 1 else 0.0
					shot_requested.emit(actor, locked_direction.rotated(Vector3.UP, angle), shot)
			if pending_steps.is_empty(): _finish_action()
			else:
				state = "sequence_gap"
				time_left = config.rain_gap_sec if attack_id == "rain" else config.burst_gap_sec
				recovery_duration = time_left
		return
	var distance := offset().length()
	if distance > actor.definition.aggro_range: return
	aim()
	if _try_roll(delta): return
	decision_left -= delta
	if decision_left <= 0.0:
		decision_left = actor.definition.decision_interval
		var legal := _legal_actions(distance)
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

func _legal_actions(distance: float) -> Array[String]:
	var legal: Array[String] = []
	var lingering_rain: bool = rain_busy.call(actor)
	if not lingering_rain and visible_target() and distance <= config.fire_range_m:
		for id in ["fast", "volley", "charged", "burst"]:
			if id in ["charged","burst"] and (distance>config.charged_range_m or not charged_admission.call(config)): continue
			if cooldowns[id] <= 0.0: legal.append(id)
	if not lingering_rain and distance >= config.rain_min_range_m and distance <= config.fire_range_m and cooldowns.rain <= 0.0 and rain_admission.call(actor, target.global_position, config):
		legal.append("rain")
		if phase_two and not _combo_since_single and cooldowns.combo <= 0.0 and visible_target(): legal.append("combo")
	return legal

func _sense_pressure(delta: float) -> void:
	if state == "rolling":
		threat_age = 0.0
		return
	if offset().length() <= config.roll_trigger_m and visible_target():
		threat_age = minf(threat_age + delta, config.roll_reaction_sec)
	else:
		threat_age = 0.0

func _try_roll(delta: float) -> bool:
	if not roll_ready or roll_cooldown > 0.0 or _roll_retry_left > 0.0 or threat_age < config.roll_reaction_sec: return false
	_roll_retry_left = config.roll_path_retry_sec
	# Compare safe endpoints over a bounded max/mid/min distance search.
	var best_distance := 0.0
	var best_direction := Vector3.ZERO
	var best_separation := -INF
	for distance_m in [config.roll_distance_m, (config.roll_distance_m + config.roll_min_distance_m) / 2.0, config.roll_min_distance_m]:
		for side in [1.0, -1.0, 1.5, -1.5, 2.0]:
			var direction: Vector3 = actor.facing.rotated(Vector3.UP, side * PI / 2.0)
			if roll_path.call(actor, direction * distance_m):
				var actual_separation: float = (actor.global_position + direction * distance_m).distance_to(target.global_position)
				if actual_separation < offset().length() + config.roll_min_separation_gain_m: continue
				var separation := minf(actual_separation, config.safe_max_m)
				if separation > best_separation or (is_equal_approx(separation, best_separation) and distance_m < best_distance):
					best_separation = separation
					best_distance = distance_m
					best_direction = direction
	if best_distance > 0.0:
		roll_ready = false
		_attack_since_roll = false
		roll_cooldown = config.roll_cooldown_sec
		roll_duration = config.roll_duration_sec
		roll_left = roll_duration
		roll_distance = best_distance
		roll_direction = best_direction
		state = "rolling"
		threat_age = 0.0
		_drive_roll(delta)
		action_started.emit("roll", cast_id)
		return true
	return false

func _drive_roll(delta: float) -> void:
	if delta <= 0.0: return
	var travel_time := minf(delta, roll_left)
	actor.forced_velocity = roll_direction * (roll_distance / roll_duration) * (travel_time / delta)
	roll_left = maxf(0.0, roll_left - delta)
	if roll_left <= 0.0:
		state = "idle"
		adjust_left = config.reposition_sec

func _start(id: String) -> void:
	action_id = id
	pending_steps.clear()
	_interrupt_recovery = false
	if id in ["rain", "combo"]:
		for i in int(config.rain_sequence_count): pending_steps.append("rain")
		if id == "combo": pending_steps.append("charged")
	elif id == "burst":
		for i in int(config.burst_fast_count): pending_steps.append("fast")
		pending_steps.append("charged")
	else: pending_steps.append(id)
	cooldowns[id] = config[id + "_cooldown_sec"]
	repeat_count = repeat_count + 1 if last_attack == id else 1
	last_attack = id
	_combo_since_single = id == "combo"
	_attack_since_roll = true
	actor.movement = Vector3.ZERO
	_begin_step(pending_steps.pop_front())

func _begin_step(id: String) -> void:
	if id == "charged" and not charged_admission.call(config):
		pending_steps.clear()
		_finish_action()
		return
	attack_id = id
	# Sequences own their internal cadence; independent reuse still pays the move cooldown.
	cooldowns[id] = maxf(cooldowns[id], config[id + "_cooldown_sec"])
	cast_id += 1
	state = "windup"
	# Every sub-shot has its own visible windup and fixed final lock window.
	aim()
	locked_direction = actor.facing
	locked_distance = offset().length()
	target_point = target.global_position
	time_left = config[id + "_windup_sec"]
	windup_duration = time_left
	action_started.emit(id, cast_id)

func _finish_action() -> void:
	state = "recovery"
	time_left = config[action_id + "_recovery_sec"]
	recovery_duration = time_left

func cancel() -> void:
	# Interruption consumes the committed action; frozen/unfrozen never resumes its cue.
	var remaining_recovery := time_left if state == "recovery" else 0.0
	if _interrupt_recovery: remaining_recovery = maxf(remaining_recovery, _interrupt_recovery_time)
	_interrupt_recovery_time = maxf(config.interrupt_recovery_sec, remaining_recovery)
	_interrupt_recovery = true
	pending_steps.clear()
	threat_age = 0.0
	state = "interrupted"
	time_left = 0.0
	roll_left = 0.0
	actor.movement = Vector3.ZERO
	actor.forced_velocity = Vector3.ZERO
