extends RefCounted
## Enemy-contact facts become bounded requests, never recursive damage calls.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
static func requests(context: Dictionary, fact: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in context.program.effects:
		if effect.type not in ["explosion", "status"]: continue
		var params: Dictionary = effect.params
		if not Capabilities.supports_impact(fact.origin, params): continue
		if not context.impact_counts.has(effect.upgrade_id): context.impact_counts[effect.upgrade_id] = {"root": 0, "parents": {}}
		var counts: Dictionary = context.impact_counts[effect.upgrade_id]
		var parent_count := int(counts.parents.get(fact.parent_id, 0))
		if parent_count >= int(params.max_per_parent) or int(counts.root) >= int(params.max_per_root): continue
		counts.parents[fact.parent_id] = parent_count + 1
		counts.root += 1
		if effect.type == "status":
			result.append({"type": "status", "target_handle": fact.target_handle, "status_id": params.status_id, "duration": params.duration_sec})
			continue
		var payloads: Array = []
		for payload in params.payloads:
			if payload.type == "damage" or payload.allowed_origins.has(fact.origin): payloads.append(payload)
		result.append({"type": "area", "position": fact.position, "primary": fact.target_handle,
			"damage": float(fact.damage) * float(params.damage_ratio), "params": params, "payloads": payloads})
	return result
