extends RefCounted
## One enemy-contact trigger per object/upgrade; children keep the parent's root queue.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Factory = preload("res://combat/builds/projectile_factory.gd")

static func requests(catalog, limits: Dictionary, program: Dictionary, projectile: Dictionary, target_handle: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if float(projectile.lifetime) <= 0.0: return result
	for effect in program.effects:
		if effect.type != "split" or projectile.split_triggers.has(effect.upgrade_id): continue
		var params: Dictionary = effect.params
		if not Capabilities.supports_split(projectile.definition, params): continue
		if int(projectile.generation) + 1 > mini(int(params.max_generation), int(limits.max_split_generation)): continue
		projectile.split_triggers[effect.upgrade_id] = true
		var definition: Dictionary = catalog.projectile(projectile.definition.child_id)
		var count := int(params.count)
		for index in count:
			var angle := 0.0 if count == 1 else deg_to_rad(float(params.spread_deg)) * (float(index) / float(count - 1) - 0.5)
			result.append(Factory.child(definition, projectile, projectile.direction.rotated(Vector3.UP, angle), float(params.damage_ratio), target_handle))
	return result
