extends RefCounted
## Combat-owned pure policy. Tags are not proof of executor support.
const Catalog = preload("res://content/builds/build_catalog.gd")

static func supports_split(definition: Dictionary, params: Dictionary) -> bool:
	return params.scope == "linear_projectile" and params.trigger == "enemy_contact" and definition.executor == "linear_contact" and not str(definition.child_id).is_empty()

static func supports_pierce(definition: Dictionary, params: Dictionary) -> bool:
	return params.scope == "linear_projectile" and params.trigger == "enemy_contact" and definition.executor == "linear_contact"

static func valid_program(program: Dictionary, catalog = null) -> bool:
	# Current upgrades apply globally. Until per-attack binding exists these two
	# contact strategies are mutually exclusive even if a caller bypasses session.
	for field in ["damage_scale", "move_scale", "tags", "effects"]:
		if not program.has(field): return false
	if not program.effects is Array or not program.tags is Array: return false
	if not _positive(program.damage_scale) or not _positive(program.move_scale): return false
	var seen: Dictionary = {}
	var split := false
	var pierce := false
	for effect in program.effects:
		if not effect is Dictionary: return false
		for field in ["upgrade_id", "type", "rank", "params"]:
			if not effect.has(field): return false
		if seen.has(effect.upgrade_id) or not effect.params is Dictionary: return false
		if not _positive_integer(effect.rank): return false
		seen[effect.upgrade_id] = true
		if not effect.type in ["projectile", "chain", "split", "pierce", "explosion", "status"]: return false
		if effect.type == "split": split = true
		if effect.type == "pierce":
			pierce = true
			for field in ["trigger", "scope", "max_hits"]:
				if not effect.params.has(field): return false
			if effect.params.trigger != "enemy_contact" or effect.params.scope != "linear_projectile" or not _positive_integer(effect.params.max_hits): return false
		if effect.type == "explosion" and not _valid_area_plan(effect.params): return false
		if catalog != null and not _known_effect(effect, catalog): return false
	return not (split and pierce)

static func _known_effect(effect: Dictionary, catalog) -> bool:
	if not catalog.has_upgrade(str(effect.upgrade_id)): return false
	var definition: Dictionary = catalog.upgrade(str(effect.upgrade_id))
	if definition.effect_type != effect.type or int(effect.rank) > int(definition.max_rank): return false
	var authored: Dictionary = definition.ranks[int(effect.rank) - 1]
	for field in ["projectile_id", "status_id", "allowed_origins", "trigger", "scope"]:
		if authored.has(field) and (not effect.params.has(field) or effect.params[field] != authored[field]): return false
	if effect.type != "explosion": return true
	for payload in effect.params.payloads:
		if payload.type != "apply_status": continue
		if not catalog.has_upgrade(str(payload.upgrade_id)): return false
		var grant: Dictionary = catalog.upgrade(str(payload.upgrade_id))
		if grant.effect_type != "area_status" or int(payload.rank) > int(grant.max_rank): return false
		var params: Dictionary = grant.ranks[int(payload.rank) - 1]
		if params.source_effect_id != effect.upgrade_id: return false
		for field in ["status_id", "allowed_origins", "include_primary", "max_targets"]:
			if payload[field] != params[field]: return false
	return true

static func _valid_area_plan(params: Dictionary) -> bool:
	for field in ["payloads", "allowed_origins", "trigger", "radius_m", "occlusion", "sight_height_m", "include_primary", "max_targets", "edge_ratio"]:
		if not params.has(field): return false
	if not params.payloads is Array or params.payloads.size() < 1 or params.payloads.size() > 2: return false
	if params.trigger != "enemy_contact" or not params.allowed_origins is Array or params.allowed_origins.is_empty(): return false
	for origin in params.allowed_origins:
		if not origin in ["direct_melee", "direct_projectile", "split_projectile"]: return false
	if not _positive(params.radius_m) or not _positive(params.sight_height_m) or not params.occlusion in ["none", "world_ray"]: return false
	for index in params.payloads.size():
		var payload: Variant = params.payloads[index]
		if not payload is Dictionary: return false
		for field in ["type", "include_primary", "max_targets"]:
			if not payload.has(field): return false
		if not payload.include_primary is bool or not _positive_integer(payload.max_targets): return false
		if index == 0:
			if payload.type != "damage" or not payload.has("edge_ratio"): return false
			if not _nonnegative(payload.edge_ratio) or float(payload.edge_ratio) > 1.0: return false
			if payload.include_primary != params.include_primary or payload.max_targets != params.max_targets or payload.edge_ratio != params.edge_ratio: return false
		else:
			if payload.type != "apply_status": return false
			for field in ["status_id", "duration_sec", "allowed_origins", "upgrade_id", "rank"]:
				if not payload.has(field): return false
			if not payload.status_id is String or payload.status_id.is_empty() or not payload.upgrade_id is String or payload.upgrade_id.is_empty(): return false
			if not _positive(payload.duration_sec) or not payload.allowed_origins is Array or payload.allowed_origins.is_empty(): return false
			if not _positive_integer(payload.rank): return false
			var matches_source := false
			for origin in payload.allowed_origins:
				if not origin in ["direct_melee", "direct_projectile", "split_projectile"]: return false
				if params.allowed_origins.has(origin): matches_source = true
			if not matches_source: return false
	return true

static func _nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

static func _positive(value: Variant) -> bool:
	return _nonnegative(value) and float(value) > 0.0

static func _positive_integer(value: Variant) -> bool:
	return _positive(value) and float(value) == floorf(float(value))

static func summarize(catalog, program: Dictionary, attack_ids: Array, has_melee: bool = false) -> Array:
	var result: Array = []
	if not valid_program(program): return Catalog.freeze_copy(result)
	for id in attack_ids:
		var attack: Dictionary = catalog.test_attack(id)
		result.append({"attack_id": id, "projectile": catalog.projectile(attack.projectile_id)})
	for effect in program.effects:
		if effect.type == "projectile":
			result.append({"attack_id": effect.upgrade_id, "projectile": catalog.projectile(effect.params.projectile_id)})
	# Derived-only carriers exist only after an actual split grant with a valid child.
	for attack in result.duplicate():
		for effect in program.effects:
			if effect.type == "split" and supports_split(attack.projectile, effect.params):
				result.append({"attack_id": str(attack.attack_id) + "/split/" + str(effect.upgrade_id), "projectile": catalog.projectile(attack.projectile.child_id), "origin": "split_projectile"})
	if has_melee: result.append({"attack_id": "melee", "projectile": {}, "origin": "direct_melee"})
	for attack in result:
		if not attack.has("origin"): attack.origin = "direct_projectile"
		attack.status_ids = []
		attack.area_effects = []
		attack.modifiers = []
		for effect in program.effects:
			if effect.type == "status" and supports_impact(attack.origin, effect.params): attack.status_ids.append(effect.params.status_id)
			if effect.type in ["pierce", "split"] and not attack.projectile.is_empty():
				var supported := supports_pierce(attack.projectile, effect.params) if effect.type == "pierce" else supports_split(attack.projectile, effect.params)
				if supported: attack.modifiers.append(effect.type)
			if effect.type == "explosion" and supports_impact(attack.origin, effect.params):
				var area := {"source_effect_id": effect.upgrade_id, "status_ids": []}
				for payload in effect.params.payloads:
					if payload.type == "apply_status" and payload.allowed_origins.has(attack.origin):
						area.status_ids.append(payload.status_id)
				attack.area_effects.append(area)
	return Catalog.freeze_copy(result)

static func eligible(entry: Dictionary, summary: Array) -> bool:
	if entry.effect_type == "area_status":
		var params: Dictionary = entry.ranks[0]
		for attack in summary:
			if not params.allowed_origins.has(attack.origin): continue
			for area in attack.area_effects:
				if area.source_effect_id == params.source_effect_id: return true
		return false
	if entry.effect_type in ["explosion", "status"]:
		for attack in summary:
			if supports_impact(attack.origin, entry.ranks[0]): return true
		return false
	if entry.effect_type == "status_duration":
		for attack in summary:
			if attack.status_ids.has(entry.ranks[0].status_id): return true
			for area in attack.area_effects:
				if area.status_ids.has(entry.ranks[0].status_id): return true
		return false
	if not entry.effect_type in ["split", "pierce"]: return true
	var opposite := "split" if entry.effect_type == "pierce" else "pierce"
	for attack in summary:
		if attack.has("modifiers") and attack.modifiers.has(opposite): return false
	for attack in summary:
		if attack.projectile.is_empty(): continue
		if entry.effect_type == "pierce" and supports_pierce(attack.projectile, entry.ranks[0]): return true
		if entry.effect_type == "split" and supports_split(attack.projectile, entry.ranks[0]): return true
	return false

static func supports_impact(origin: String, params: Dictionary) -> bool:
	return params.trigger == "enemy_contact" and origin in ["direct_melee", "direct_projectile", "split_projectile"] and params.allowed_origins.has(origin)
