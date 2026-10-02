extends RefCounted
## Compiles selected ranks once. Content definitions and the result stay immutable.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
var _catalog

func configure(catalog) -> void:
	_catalog = catalog

func resolve(ranks: Dictionary) -> Dictionary:
	assert(_catalog != null, "BuildResolver needs a validated catalog")
	if not validate_ranks(ranks).is_empty(): return {}
	var ids: Array = ranks.keys()
	ids.sort()
	var damage_bonus := 0.0
	var move_bonus := 0.0
	var tags: Array[String] = []
	var effects: Array[Dictionary] = []
	var durations: Dictionary = {}
	var area_grants: Array[Dictionary] = []
	for id in ids:
		var entry: Dictionary = _catalog.upgrade(str(id))
		var rank := int(ranks[id])
		assert(rank > 0 and rank <= int(entry.max_rank), "Invalid selected upgrade rank")
		var params: Dictionary = entry.ranks[rank - 1].duplicate(true)
		for tag in entry.granted_tags:
			if not tags.has(str(tag)): tags.append(str(tag))
		match str(entry.effect_type):
			"damage_scale": damage_bonus += float(params.bonus)
			"move_scale": move_bonus += float(params.bonus)
			"status_duration": durations[params.status_id] = float(durations.get(params.status_id, 0.0)) + float(params.bonus)
			"area_status": area_grants.append({"upgrade_id": str(id), "rank": rank, "params": params})
			"projectile", "chain", "split", "pierce", "explosion", "status":
				effects.append({"upgrade_id": str(id), "type": str(entry.effect_type), "rank": rank, "params": params})
			_: assert(false, "Unsupported validated build effect")
	for effect in effects:
		if effect.type == "status": effect.params.duration_sec = _duration(effect.params.status_id, durations)
		if effect.type != "explosion": continue
		var params: Dictionary = effect.params
		params.payloads = [{"type": "damage", "edge_ratio": params.edge_ratio, "include_primary": params.include_primary, "max_targets": params.max_targets}]
		for grant in area_grants:
			if grant.params.source_effect_id != effect.upgrade_id: continue
			params.payloads.append({"type": "apply_status", "status_id": grant.params.status_id,
				"duration_sec": _duration(grant.params.status_id, durations), "include_primary": grant.params.include_primary,
				"max_targets": grant.params.max_targets, "allowed_origins": grant.params.allowed_origins,
				"upgrade_id": grant.upgrade_id, "rank": grant.rank})
	tags.sort()
	var limits: Dictionary = _catalog.stat_limits()
	var program := {
		"damage_scale": clampf(1.0 + damage_bonus, float(limits.damage_scale_min), float(limits.damage_scale_max)),
		"move_scale": clampf(1.0 + move_bonus, float(limits.move_scale_min), float(limits.move_scale_max)),
		"tags": tags,
		"effects": effects,
	}
	if not Capabilities.valid_program(program, _catalog): return {}
	freeze(program)
	return program

func _duration(status_id: String, bonuses: Dictionary) -> float:
	var definition: Dictionary = _catalog.status(status_id)
	return minf(float(definition.max_duration_sec), float(definition.duration_sec) * (1.0 + float(bonuses.get(status_id, 0.0))))

func validate_ranks(ranks: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var tags: Array = []
	for id in ranks:
		if not _catalog.has_upgrade(str(id)):
			errors.append("unknown_upgrade:" + str(id))
			continue
		var rank: Variant = ranks[id]
		var entry: Dictionary = _catalog.upgrade(str(id))
		if not (rank is int or rank is float) or not is_finite(float(rank)) or float(rank) != floorf(float(rank)) or float(rank) < 1 or float(rank) > int(entry.max_rank):
			errors.append("invalid_rank:" + str(id))
		for tag in entry.granted_tags:
			if not tags.has(tag): tags.append(tag)
	if not errors.is_empty(): return errors
	var area_sources: Dictionary = {}
	var strategies: Array = []
	for id in ranks:
		var entry: Dictionary = _catalog.upgrade(str(id))
		for required in entry.requires:
			if not ranks.has(required): errors.append("missing_prerequisite:" + str(id))
		for excluded in entry.excludes:
			if ranks.has(excluded): errors.append("excluded_upgrade:" + str(id))
		for required in entry.required_tags:
			if not tags.has(required): errors.append("missing_tag:" + str(id))
		if entry.effect_type in ["split", "pierce"] and not strategies.has(entry.effect_type): strategies.append(entry.effect_type)
		if entry.effect_type != "area_status": continue
		var params: Dictionary = entry.ranks[int(ranks[id]) - 1]
		if not ranks.has(params.source_effect_id):
			errors.append("missing_area_source:" + str(id))
			continue
		if area_sources.has(params.source_effect_id): errors.append("duplicate_area_payload:" + str(id))
		area_sources[params.source_effect_id] = true
		var source: Dictionary = _catalog.upgrade(params.source_effect_id)
		if source.effect_type != "explosion":
			errors.append("unsupported_area_source:" + str(id))
			continue
		var source_params: Dictionary = source.ranks[int(ranks[params.source_effect_id]) - 1]
		var compatible := false
		for origin in params.allowed_origins:
			if Capabilities.supports_impact(origin, source_params): compatible = true
		if not compatible: errors.append("incompatible_area_source:" + str(id))
	if strategies.has("split") and strategies.has("pierce"): errors.append("incompatible_contact_strategies")
	return errors

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item in value: freeze(item)
		value.make_read_only()
