extends RefCounted
## Pure spatial plan. No recursive events and no visual dependency.
const Targets = preload("res://combat/effects/area_targets.gd")
static func plan(center: Vector3, team: int, primary: int, damage: float, params: Dictionary, targets: Array, wall_query: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hit in Targets.select(center, team, primary, params, params, targets, wall_query):
		hit.damage = damage * lerpf(1.0, float(params.edge_ratio), float(hit.distance) / float(params.radius_m))
		result.append(hit)
	return result
