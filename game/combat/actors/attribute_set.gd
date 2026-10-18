extends RefCounted
## Idempotent modifiers keyed by source/stat/operation. Rebuild never heals an actor.
signal changed
var catalog
var base: Dictionary
var _modifiers: Dictionary = {}
var final: Dictionary = {}
func _init(definitions, actor_id: String) -> void:
	catalog = definitions
	base = catalog.actor(actor_id)
	_rebuild()
func set_modifier(source: String, stat: String, operation: String, amount: float) -> void:
	assert(not source.is_empty() and base.has(stat) and operation in ["flat", "percent", "multiply"] and is_finite(amount))
	assert(stat not in catalog.data.stat_modifier_rule.percentage_point_stats or operation == "flat")
	var key := source + ":" + stat + ":" + operation
	if _modifiers.has(key) and _modifiers[key].amount == amount: return
	_modifiers[key] = {"source": source, "stat": stat, "operation": operation, "amount": amount}
	_rebuild()
func remove_source(source: String) -> void:
	var removed := false
	for key in _modifiers.keys():
		if _modifiers[key].source == source:
			_modifiers.erase(key)
			removed = true
	if removed: _rebuild()
func value(stat: String) -> float: return final[stat]
func sources() -> Array: return _modifiers.values().duplicate(true)
func _rebuild() -> void:
	var result: Dictionary = {}
	for stat in base:
		var flat := 0.0
		var percent := 0.0
		var multiplier := 1.0
		for entry in _modifiers.values():
			if entry.stat != stat: continue
			match entry.operation:
				"flat": flat += entry.amount
				"percent": percent += entry.amount
				"multiply": multiplier *= entry.amount
		var number: float = (base[stat] + flat) * (1.0 + percent) * multiplier
		var bound: Dictionary = catalog.data.stat_bounds[stat]
		result[stat] = maxf(number, bound.min)
		if bound.max != null: result[stat] = minf(result[stat], bound.max)
	result.make_read_only()
	final = result
	changed.emit()
