extends RefCounted
## One configured shape / one hit group per cast; no recursive effects.
const Damage = preload("res://combat/effects/damage_executor.gd")
signal enemy_contact(source, cast_id: int, ability_id: String, target_handle: int, position: Vector3, damage: float)
signal confirmed_hit(source, target, cast_id: int, ability_id: String, applied_damage: float)
var _damage_modifier: Callable
var _hit_filter: Callable
func set_hit_filter(filter: Callable) -> void:
	_hit_filter = filter
func set_damage_modifier(modifier: Callable) -> void:
	_damage_modifier = modifier
func resolve(source, targets: Array) -> void:
	if not source.health.alive() or not source.runner.active_this_step: return
	var ability = source.runner.ability
	for target in targets:
		if target == source or target.team == source.team or not target.health.alive(): continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		# Actor center is the authoritative hurt point in this flat-ground slice.
		if not _contains(ability, source.runner.direction, offset): continue
		if _hit_filter.is_valid() and not _hit_filter.call(source, target): continue
		if source.runner.claim_target(target.handle):
			var amount: float = _damage_modifier.call(source, ability.damage) if _damage_modifier.is_valid() else ability.damage
			var point: Vector3 = target.global_position
			var victim: int = target.handle
			var cast: int = source.runner.cast_id
			var applied: float = Damage.apply(target, amount, source.team)
			enemy_contact.emit(source, cast, ability.id, victim, point, amount)
			if applied > 0.0:
				var direction: Vector3 = offset.normalized() if not offset.is_zero_approx() else source.runner.direction
				target.apply_knockback(direction, ability.knockback_speed, ability.knockback_duration)
				confirmed_hit.emit(source, target, source.runner.cast_id, ability.id, applied)

func _contains(ability, direction: Vector3, offset: Vector3) -> bool:
	match ability.hit_shape:
		"sector":
			return offset.length() <= ability.radius and (offset.is_zero_approx() or direction.dot(offset.normalized()) >= cos(ability.angle / 2.0))
		"thrust":
			var forward_distance: float = direction.dot(offset)
			var side_distance: float = absf(direction.cross(Vector3.UP).dot(offset))
			return forward_distance >= 0.0 and forward_distance <= ability.radius and side_distance <= ability.thrust_width / 2.0
	assert(false, "Unsupported validated melee shape: " + ability.hit_shape)
	return false
