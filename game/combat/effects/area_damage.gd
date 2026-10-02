extends RefCounted
## Pure spatial plan. No recursive events and no visual dependency.
static func plan(center: Vector3, team: int, primary: int, damage: float, params: Dictionary, targets: Array, wall_query: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if params.occlusion == "world_ray" and not wall_query.is_valid(): return result
	var seen: Dictionary = {}
	for target in targets:
		if not is_instance_valid(target) or not target.health.alive() or target.team == team or seen.has(target.handle): continue
		seen[target.handle] = true
		if not params.include_primary and target.handle == primary: continue
		var offset: Vector3 = target.global_position - center
		offset.y = 0.0
		var distance := offset.length()
		if distance > float(params.radius_m): continue
		if params.occlusion == "world_ray" and wall_query.is_valid():
			var from := center + Vector3.UP * float(params.sight_height_m)
			var to: Vector3 = target.global_position + Vector3.UP * float(params.sight_height_m)
			if wall_query.call(from, to) is Vector3: continue
		var ratio := lerpf(1.0, float(params.edge_ratio), distance / float(params.radius_m))
		result.append({"target": target, "distance": distance, "handle": target.handle, "damage": damage * ratio})
	result.sort_custom(func(a, b): return a.handle < b.handle if a.distance == b.distance else a.distance < b.distance)
	if result.size() > int(params.max_targets): result.resize(int(params.max_targets))
	return result
