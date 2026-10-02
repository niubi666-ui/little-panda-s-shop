extends RefCounted
## Shared damage submission; hit-group deduplication belongs to the caller.
static func apply(target, amount: float, source_team: int) -> float:
	if not is_instance_valid(target) or not target.health.alive() or target.team == source_team: return 0.0
	return target.receive_hit(amount)
