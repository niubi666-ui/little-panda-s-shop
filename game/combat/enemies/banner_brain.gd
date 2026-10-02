extends "res://combat/enemies/role_brain.gd"
func tick(delta: float) -> void:
	if not begin_tick(delta): return
	aim()
	var distance := offset().length()
	if distance < config.retreat_range_m:
		state = "retreating"
		retreat(config.retreat_speed_multiplier)
	elif distance > config.safe_max_m and distance <= actor.definition.aggro_range:
		state = "seeking"
		approach()
	else: state = "supporting"
