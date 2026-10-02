extends RefCounted
## Compiles selected ranks once. Content definitions and the result stay immutable.
var _catalog

func configure(catalog) -> void:
	_catalog = catalog

func resolve(ranks: Dictionary) -> Dictionary:
	assert(_catalog != null, "BuildResolver needs a validated catalog")
	var ids: Array = ranks.keys()
	ids.sort()
	var damage_bonus := 0.0
	var move_bonus := 0.0
	var tags: Array[String] = []
	var effects: Array[Dictionary] = []
	var durations: Dictionary = {}
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
			"projectile", "chain", "split", "explosion", "status":
				effects.append({"upgrade_id": str(id), "type": str(entry.effect_type), "rank": rank, "params": params})
			_: assert(false, "Unsupported validated build effect")
	for effect in effects:
		if effect.type != "status": continue
		var definition: Dictionary = _catalog.status(effect.params.status_id)
		effect.params.duration_sec = minf(float(definition.max_duration_sec), float(definition.duration_sec) * (1.0 + float(durations.get(definition.id, 0.0))))
	tags.sort()
	var limits: Dictionary = _catalog.stat_limits()
	var program := {
		"damage_scale": clampf(1.0 + damage_bonus, float(limits.damage_scale_min), float(limits.damage_scale_max)),
		"move_scale": clampf(1.0 + move_bonus, float(limits.move_scale_min), float(limits.move_scale_max)),
		"tags": tags,
		"effects": effects,
	}
	freeze(program)
	return program

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item in value: freeze(item)
		value.make_read_only()
