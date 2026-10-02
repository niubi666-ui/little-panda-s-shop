extends RefCounted
## Physical initialization only; no card lookup, branching by weapon, or budget ownership.
static func initial(definition: Dictionary, position: Vector3, direction: Vector3, damage: float) -> Dictionary:
	return {"type": "spawn", "definition": definition,
		"position": position + Vector3.UP * float(definition.height_m), "direction": direction,
		"damage": damage, "speed": definition.speed_mps, "radius": definition.radius_m,
		"lifetime": definition.lifetime_sec, "generation": 0, "excluded": {}, "split_triggers": {}}

static func child(definition: Dictionary, parent: Dictionary, direction: Vector3, damage_ratio: float, target_handle: int) -> Dictionary:
	var excluded: Dictionary = parent.excluded.duplicate()
	excluded[target_handle] = true
	# Child definition supplies speed/radius; remaining lifetime can only decrease.
	return {"type": "spawn", "definition": definition, "position": parent.position,
		"direction": direction, "damage": float(parent.damage) * damage_ratio,
		"speed": definition.speed_mps, "radius": definition.radius_m,
		"lifetime": minf(float(parent.lifetime), float(definition.lifetime_sec)),
		"generation": int(parent.generation) + 1, "excluded": excluded, "split_triggers": {}}
