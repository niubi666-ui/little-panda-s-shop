extends RefCounted
## Pure, RNG-free formulas shared by execution and the character sheet.
static func linear(profile: Dictionary, stats: Dictionary) -> float:
	return preload("res://content/combat/attribute_catalog.gd").linear(profile, stats)
static func elemental_growth(catalog, stats: Dictionary, base: Dictionary) -> float:
	var policy: Dictionary = catalog.data.growth_policies.elemental_growth
	return 1.0 + maxf(0.0, stats.attack_power - base.attack_power) * policy.positive_bonus_attack_power_ratio + stats.spell_power * policy.spell_power_ratio
static func mitigation(catalog, damage_type: String, stats: Dictionary) -> float:
	var rule: Dictionary = catalog.data.damage_rules[damage_type]
	if rule.resistance_stat == null: return 1.0
	var k: float = catalog.data.damage_rules.resistance_constant
	return k / (k + maxf(0.0, stats[rule.resistance_stat]))
static func preview(actor, profile_id: String, weapon_scale: float = 1.0, basis_scale: float = 1.0) -> Dictionary:
	var profile: Dictionary = actor.attribute_catalog.profile(profile_id)
	var basis := linear(profile, actor.attributes.final) * basis_scale
	var outgoing: float = weapon_scale * actor.spawn_damage_multiplier if actor.attribute_catalog.data.damage_rules[profile.damage_type].generic_modifiers else 1.0
	return {"type": profile.damage_type, "basis": basis, "amount": basis * outgoing}
