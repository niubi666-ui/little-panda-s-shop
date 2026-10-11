extends RefCounted
## Finite, pure pre-hit evaluation. Never mutates status, roots or derived damage.
static func evaluate(context: Dictionary, target, base_damage: float, origin: String, statuses, catalog, runtime_id: int) -> Dictionary:
	var result := {"damage": base_damage, "base_damage": base_damage, "bonus": 0.0, "effect_ids": []}
	if not is_instance_valid(target) or not target.health.alive() or catalog.action(context.action_id).test_only: return result
	var snapshot: Dictionary = statuses.snapshot(target)
	for effect in context.program.effects:
		if effect.type != "conditional_damage": continue
		var params: Dictionary = effect.params
		if not params.allowed_origins.has(origin) or not snapshot.has(params.status_id): continue
		var status: Dictionary = snapshot[params.status_id]
		if status.remaining <= 0.0: continue
		var source: Dictionary = status.source
		# Missing provenance is not a player freeze; debug and other runtimes cannot qualify.
		if not source.has_all(["runtime_id", "room_generation", "root_id", "source_handle", "team", "action_id"]): continue
		if source.runtime_id != runtime_id or source.room_generation != context.room_generation: continue
		if source.source_handle != context.source_handle or source.team != context.team: continue
		if not catalog.has_action(source.action_id) or catalog.action(source.action_id).test_only: continue
		if int(source.root_id) >= int(context.id): continue
		result.bonus += float(params.bonus)
		result.effect_ids.append(effect.upgrade_id)
	result.bonus = minf(result.bonus, float(catalog.stat_limits().conditional_bonus_max))
	result.damage = base_damage * (1.0 + result.bonus)
	return result
