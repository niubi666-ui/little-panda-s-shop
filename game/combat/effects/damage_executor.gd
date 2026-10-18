extends RefCounted
## Components resolve independently, then commit shields/health/reactions once.
const Formula = preload("res://combat/effects/damage_formula.gd")
static func request(source, profile_id: String, basis: float, root_id: int, action_id: String, critical: bool = false) -> Dictionary:
	var profile: Dictionary = source.attribute_catalog.profile(profile_id)
	return {"catalog": source.attribute_catalog, "source": weakref(source), "source_handle": source.handle,
		"source_runtime_id": source.get_instance_id(), "team": source.team, "root_id": root_id,
		"runtime_id": 0, "runtime": null, "room_generation": 0, "event_id": root_id,
		"ability_id": profile_id, "action_id": action_id, "profile_id": profile_id, "origin": "direct",
		"components": [{"type": profile.damage_type, "basis": basis}], "source_scale": source.spawn_damage_multiplier,
		"conditional_bonus": 0.0, "critical": critical, "crit_multiplier": source.attributes.value("crit_damage_multiplier"),
		"allows_on_hit": true, "allows_poise": true}

static func submit(target, hit: Dictionary) -> Dictionary:
	var result := {"valid_hit": false, "critical": false, "components": [], "raw": 0.0,
		"mitigated": 0.0, "shield_loss": 0.0, "health_loss": 0.0, "poise_basis": 0.0,
		"profile_id": hit.profile_id, "source_handle": hit.source_handle, "root_id": hit.root_id,
		"event_id": hit.event_id, "origin": hit.origin, "source_runtime_id": hit.source_runtime_id,
		"team": hit.team, "runtime_id": hit.runtime_id, "room_generation": hit.room_generation,
		"action_id": hit.action_id, "ability_id": hit.ability_id}
	if not is_instance_valid(target) or not target.health.alive() or target.team == hit.team or target.invulnerable(): return result
	if hit.source != null:
		var source = hit.source.get_ref()
		if source == null or not source.health.alive() or source.handle != hit.source_handle or source.get_instance_id() != hit.source_runtime_id: return result
	if hit.runtime != null:
		var runtime = hit.runtime.get_ref()
		if runtime == null or runtime.get_instance_id() != hit.runtime_id or runtime._room_generation != hit.room_generation: return result
	var catalog = hit.catalog
	var defenses: Dictionary = target.defenses()
	var incoming: Dictionary = target.damage_modifiers()
	var total := 0.0
	var poise := 0.0
	for component in hit.components:
		assert(catalog.data.damage_rules.has(component.type), "Damage type must be explicit")
		var rule: Dictionary = catalog.data.damage_rules[component.type]
		var amount: float = maxf(0.0, component.basis)
		if rule.generic_modifiers:
			amount *= hit.source_scale * (1.0 + hit.conditional_bonus)
			poise += amount
			if hit.critical:
				amount *= hit.crit_multiplier
				result.critical = true
			amount *= incoming.vulnerability * incoming.break_multiplier * incoming.reduction
		else: poise += amount
		var applied := amount * Formula.mitigation(catalog, component.type, defenses)
		result.components.append({"type": component.type, "basis": component.basis, "raw": amount, "after_resistance": applied})
		result.raw += amount
		total += applied
	if total <= 0.0: return result
	result.valid_hit = true
	result.mitigated = total
	result.poise_basis = poise if hit.allows_poise else 0.0
	var committed: Dictionary = target.commit_damage(total, result.poise_basis)
	result.shield_loss = committed.shield_loss
	result.health_loss = committed.health_loss
	preload("res://content/combat/attribute_catalog.gd").freeze(result)
	if is_instance_valid(target): target.damage_received.emit(result)
	return result

## Explicit legacy/debug physical hit; never a fallback for a missing damage type.
static func raw_physical(target, amount: float, catalog, source_team: int) -> Dictionary:
	var adapter: Dictionary = catalog.data.raw_hit_adapter
	var hit := {"catalog": catalog, "source": null, "source_handle": -1, "source_runtime_id": 0,
		"team": source_team, "root_id": 0, "runtime_id": 0, "runtime": null, "room_generation": 0,
		"event_id": 0, "ability_id": "", "action_id": "", "profile_id": "raw_hit_adapter", "origin": adapter.origin,
		"components": [{"type": adapter.damage_type, "basis": amount}], "source_scale": 1.0,
		"conditional_bonus": 0.0, "critical": false, "crit_multiplier": 1.0, "allows_on_hit": false, "allows_poise": true}
	return submit(target, hit)
