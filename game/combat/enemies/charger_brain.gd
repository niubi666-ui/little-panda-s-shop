extends "res://combat/enemies/role_brain.gd"
signal impact(source, target, damage: Dictionary, direction: Vector3, speed: float, duration: float)
var start_position := Vector3.ZERO
var previous_position := Vector3.ZERO
var hit_claimed := false
func tick(delta: float) -> void:
	if not begin_tick(delta): return
	if state == "windup":
		time_left -= delta
		if time_left > 0.0: return
		state = "charging"
		start_position = actor.global_position
		previous_position = start_position
		hit_claimed = false
		# Produce the first dash motion now. Otherwise after_motion observes a
		# stationary contact from the windup and cancels every attempted escape.
	if state == "charging":
		if _reached_charge_end():
			_recover()
			return
		var remaining: float = config.charge_distance_m - start_position.distance_to(actor.global_position)
		actor.forced_velocity = locked_direction * minf(config.charge_speed_mps, remaining / delta) if delta > 0.0 else Vector3.ZERO
		return
	if state == "recovery":
		time_left -= delta
		if time_left <= 0.0: state = "idle"
		return
	aim()
	var distance := offset().length()
	if distance > actor.definition.aggro_range: return
	state = "seeking"
	if not visible_target():
		approach()
	elif distance < config.minimum_range_m:
		retreat(1.0)
		if actor.movement.is_zero_approx(): approach()
	elif distance > config.trigger_range_m: approach()
	elif cooldown <= 0.0:
		commit_attack(config.damage_profile_id)
		state = "windup"
		locked_direction = actor.facing
		time_left = actor.attack_windup(config.damage_profile_id, config.windup_sec)
		windup_duration = time_left
		cooldown = actor.skill_cooldown(config.cooldown_sec)
func after_motion(target_radius: float) -> void:
	if state != "charging" or not actor.health.alive() or actor.control_locked: return
	if actor.stagger_left > 0.0:
		state = "staggered"
		actor.forced_velocity = Vector3.ZERO
		return
	# Test the swept path, not just the end point. One impact per charge.
	var closest := Geometry3D.get_closest_point_to_segment(target.global_position, previous_position, actor.global_position)
	var separation: Vector3 = target.global_position - closest
	separation.y = 0.0
	var advance: float = (actor.global_position - previous_position).dot(locked_direction)
	if not hit_claimed and separation.length() <= config.hit_radius_m + target_radius:
		hit_claimed = true
		impact.emit(actor, target, attack_request, locked_direction, config.knockback_speed_mps, config.knockback_duration_sec)
		_recover()
	elif actor.motor.blocked or _reached_charge_end() or advance <= 0.0 or is_zero_approx(advance):
		# Also stop if motion was rejected without a collision report. Keep this
		# after the swept hit so the final moving step can still deal its damage.
		_recover()
	previous_position = actor.global_position
func _reached_charge_end() -> bool:
	var travelled := start_position.distance_to(actor.global_position)
	# Vector3 positions cannot represent an exact endpoint at every origin/angle.
	# Engine float tolerance prevents a microscopic remainder looping forever.
	return travelled >= config.charge_distance_m or is_equal_approx(travelled, config.charge_distance_m)
func _recover() -> void:
	state = "recovery"
	time_left = config.recovery_sec / attack_tempo
	recovery_duration = time_left
	actor.forced_velocity = Vector3.ZERO
