extends RefCounted
## Decision cadence is separate from AbilityRunner's windup/active/recovery.
var actor
var target
var decision_left := 0.0
var state := "idle"
var _route: Callable
var _clear_path: Callable
func configure_navigation(route: Callable, clear_path: Callable) -> void:
	_route = route
	_clear_path = clear_path
func _init(owner_actor, target_actor) -> void:
	actor = owner_actor
	target = target_actor
func tick(delta: float) -> void:
	if not actor.health.alive():
		state = "dead"
		return
	actor.movement = Vector3.ZERO
	if not target.health.alive():
		state = "idle"
		actor.cancel()
		return
	if actor.control_locked:
		state = "frozen"
		return
	if actor.stagger_left > 0.0:
		state = "staggered"
		return
	if actor.runner.busy():
		state = actor.runner.phase()
		return
	var offset: Vector3 = target.global_position - actor.global_position
	offset.y = 0.0
	if offset.length() > actor.definition.aggro_range:
		state = "idle"
		return
	if not offset.is_zero_approx(): actor.facing = offset.normalized()
	state = "seeking"
	var clear: bool = not _clear_path.is_valid() or _clear_path.call(actor, target)
	if offset.length() > actor.attacks[0].radius or not clear:
		actor.movement = _route.call(actor, target) if _route.is_valid() else actor.facing
	decision_left -= delta
	if decision_left > 0.0: return
	decision_left = actor.definition.decision_interval
	if clear and offset.length() <= actor.attacks[0].radius and actor.runner.cooldown <= 0.0:
		actor.request_attack()

func cancel() -> void:
	actor.cancel()
	state = "frozen" if actor.control_locked else "idle"
