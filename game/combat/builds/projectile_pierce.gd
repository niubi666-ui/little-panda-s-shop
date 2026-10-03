extends RefCounted
## Contact cardinality only; motion, damage snapshots and root ownership stay unchanged.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")

static func max_hits(definition: Dictionary, program: Dictionary, limits: Dictionary) -> int:
	# A single contact is the base linear_contact executor's termination rule.
	var count := 1
	for effect in program.effects:
		if effect.type == "pierce" and Capabilities.supports_pierce(definition, effect.params):
			count = maxi(count, int(effect.params.max_hits))
	return mini(count, int(limits.max_projectile_hits))
