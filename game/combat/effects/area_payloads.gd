extends RefCounted
## Finite synchronous plan: damage first, then an explicitly granted status payload.
const Targets = preload("res://combat/effects/area_targets.gd")

static func plan(request: Dictionary, team: int, targets: Array, wall_query: Callable) -> Dictionary:
	var result := {"damage": [], "statuses": []}
	for payload in request.payloads:
		for hit in Targets.select(request.position, team, request.primary, request.params, payload, targets, wall_query):
			match str(payload.type):
				"damage":
					hit.damage = float(request.damage) * lerpf(1.0, float(payload.edge_ratio), float(hit.distance) / float(request.params.radius_m))
					result.damage.append(hit)
				"apply_status":
					hit.status_id = payload.status_id
					hit.duration = payload.duration_sec
					result.statuses.append(hit)
	return result
