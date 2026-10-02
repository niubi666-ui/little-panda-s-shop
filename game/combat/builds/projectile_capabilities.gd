extends RefCounted
## Combat-owned pure policy. Tags are not proof of executor support.
const Catalog = preload("res://content/builds/build_catalog.gd")

static func supports_split(definition: Dictionary, params: Dictionary) -> bool:
	return params.scope == "linear_projectile" and params.trigger == "enemy_contact" and definition.executor == "linear_contact" and not str(definition.child_id).is_empty()

static func summarize(catalog, program: Dictionary, attack_ids: Array, has_melee: bool = false) -> Array:
	var result: Array = []
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
		for effect in program.effects:
			if effect.type == "status" and supports_impact(attack.origin, effect.params): attack.status_ids.append(effect.params.status_id)
	return Catalog.freeze_copy(result)

static func eligible(entry: Dictionary, summary: Array) -> bool:
	if entry.effect_type in ["explosion", "status"]:
		for attack in summary:
			if supports_impact(attack.origin, entry.ranks[0]): return true
		return false
	if entry.effect_type == "status_duration":
		for attack in summary:
			if attack.status_ids.has(entry.ranks[0].status_id): return true
		return false
	if entry.effect_type != "split": return true
	for attack in summary:
		if not attack.projectile.is_empty() and supports_split(attack.projectile, entry.ranks[0]): return true
	return false

static func supports_impact(origin: String, params: Dictionary) -> bool:
	return params.trigger == "enemy_contact" and origin in ["direct_melee", "direct_projectile", "split_projectile"] and params.allowed_origins.has(origin)
