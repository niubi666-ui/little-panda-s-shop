extends RefCounted
## One configured shape / one hit group per cast; no recursive effects.
const Damage = preload("res://combat/effects/damage_executor.gd")
signal enemy_contact(source, cast_id: int, ability_id: String, target_handle: int, position: Vector3, damage: float)
signal confirmed_hit(source, target, cast_id: int, ability_id: String, applied_damage: float)
var _damage_modifier: Callable
var _direct_executor: Callable
var _hit_filter: Callable
func set_direct_damage_executor(executor: Callable) -> void:
	_direct_executor = executor
func set_hit_filter(filter: Callable) -> void:
	_hit_filter = filter
func set_damage_modifier(modifier: Callable) -> void:
	_damage_modifier = modifier
func resolve(source, targets: Array) -> void:
	if not source.health.alive() or not source.runner.active_this_step or source.runner.executor != "melee": return
	var ability = source.runner.ability
	var ordered := targets.filter(func(t): return is_instance_valid(t))
	ordered.sort_custom(func(a, b):
		var da: float = source.global_position.distance_squared_to(a.global_position)
		var db: float = source.global_position.distance_squared_to(b.global_position)
		return a.handle < b.handle if is_equal_approx(da, db) else da < db)
	for target in ordered:
		if target == source or target.team == source.team or not target.health.alive(): continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		# Actor center is the authoritative hurt point in this flat-ground slice.
		if not _contact_contains(source, ability, target.global_position, offset): continue
		if _hit_filter.is_valid() and not _hit_filter.call(source, target): continue
		if source.runner.claim_target(target.handle):
			var amount: float = _damage_modifier.call(source, ability.damage) if _damage_modifier.is_valid() else ability.damage
			var point: Vector3 = target.global_position
			var victim: int = target.handle
			var cast: int = source.runner.cast_id
			var applied: float = _direct_executor.call(source, target, amount) if _direct_executor.is_valid() else Damage.apply(target, amount, source.team)
			enemy_contact.emit(source, cast, ability.id, victim, point, amount)
			if applied > 0.0:
				var direction: Vector3 = offset.normalized() if not offset.is_zero_approx() else source.runner.direction
				target.apply_knockback(direction, ability.knockback_speed, ability.knockback_duration)
				confirmed_hit.emit(source, target, source.runner.cast_id, ability.id, applied)

func _contact_contains(source, ability, target_position: Vector3, offset: Vector3) -> bool:
	var reach: float = source.reach_scale()
	if _contains(ability, source.runner.direction, offset, reach): return true
	if not source.is_roll_attack_cast(): return false
	var travel: Vector3 = source.global_position - source.melee_sweep_from
	travel.y = 0.0
	# Sweep the sector through the actual collision-limited path, with overlapping samples.
	var steps := ceili(travel.length() / (ability.radius * reach * 0.25))
	for i in steps:
		var sample_offset: Vector3 = target_position - source.melee_sweep_from - travel * (float(i) / steps)
		sample_offset.y = 0.0
		if _contains(ability, source.runner.direction, sample_offset, reach): return true
	return false

func _contains(ability, direction: Vector3, offset: Vector3, reach: float) -> bool:
	match ability.hit_shape:
		"sector":
			return offset.length() <= ability.radius * reach and (offset.is_zero_approx() or direction.dot(offset.normalized()) >= cos(ability.angle / 2.0))
		"thrust":
			var forward_distance: float = direction.dot(offset)
			var side_distance: float = absf(direction.cross(Vector3.UP).dot(offset))
			return forward_distance >= 0.0 and forward_distance <= ability.radius * reach and side_distance <= ability.thrust_width / 2.0
	assert(false, "Unsupported validated melee shape: " + ability.hit_shape)
	return false
