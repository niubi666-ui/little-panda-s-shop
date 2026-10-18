extends RefCounted
## Immutable authored attributes and finite damage policies; no runtime actor state.
var data: Dictionary
func _init(value: Dictionary) -> void:
	data = value.duplicate(true)
	freeze(data)
static func freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value: freeze(child)
		value.make_read_only()
func actor(id: String) -> Dictionary: return data.actors[id]
static func linear(profile: Dictionary, stats: Dictionary) -> float:
	return profile.base + stats.attack_power * profile.attack_power_ratio + stats.spell_power * profile.spell_power_ratio
func profile(id: String) -> Dictionary:
	for group in ["linear_profiles", "derived_profiles", "effect_profiles"]:
		if data[group].has(id): return data[group][id]
	assert(false, "Unknown damage profile: " + id)
	return {}
func has_profile(id: String) -> bool:
	return data.linear_profiles.has(id) or data.derived_profiles.has(id) or data.effect_profiles.has(id)
