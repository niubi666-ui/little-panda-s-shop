extends RefCounted
## Shared, pure geometry/occlusion selection for independent damage/status policies.
static func select(center: Vector3, team: int, primary: int, geometry: Dictionary, policy: Dictionary, targets: Array, wall_query: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if geometry.occlusion == "world_ray" and not wall_query.is_valid(): return result
	var seen: Dictionary = {}
	for target in targets:
		if not is_instance_valid(target) or not target.health.alive() or target.team == team or seen.has(target.handle): continue
		seen[target.handle] = true
		if not policy.include_primary and target.handle == primary: continue
		var offset: Vector3 = target.global_position - center
		offset.y = 0.0
		var distance := offset.length()
		if distance > float(geometry.radius_m): continue
		if geometry.occlusion == "world_ray":
			var from := center + Vector3.UP * float(geometry.sight_height_m)
			var to: Vector3 = target.global_position + Vector3.UP * float(geometry.sight_height_m)
			if wall_query.call(from, to) is Vector3: continue
		result.append({"target": target, "distance": distance, "handle": target.handle})
	result.sort_custom(func(a, b): return a.handle < b.handle if a.distance == b.distance else a.distance < b.distance)
	if result.size() > int(policy.max_targets): result.resize(int(policy.max_targets))
	return result
