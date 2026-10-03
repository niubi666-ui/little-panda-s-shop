extends RefCounted
## Snapshot one swept segment. A wall clips both contact distance and hurt points.
const Sweep = preload("res://combat/builds/build_sweep.gd")

static func collect(projectile: Dictionary, start: Vector3, direction: Vector3, distance: float, wall_blocked: bool, targets: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for target in targets:
		if not is_instance_valid(target) or not target.health.alive(): continue
		if seen.has(target.handle) or projectile.excluded.has(target.handle): continue
		seen[target.handle] = true
		# Width must not reach through the wall to a hurt point on its far side.
		if wall_blocked and direction.dot(target.global_position - start) >= distance: continue
		var contact := Sweep.contact_distance(start, direction, distance, target.global_position, float(projectile.radius))
		if contact < 0.0 or (wall_blocked and contact >= distance): continue
		result.append({"target": target, "distance": contact, "handle": target.handle})
	result.sort_custom(func(a, b): return a.handle < b.handle if a.distance == b.distance else a.distance < b.distance)
	return result
