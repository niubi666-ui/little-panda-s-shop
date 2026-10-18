extends RefCounted
## Shared intent helpers; each role owns its own small action state machine.
var actor
var target
var config: Dictionary
var state := "idle"
var locked_direction := Vector3.FORWARD
var time_left := 0.0
var windup_duration := 0.0
## 本次收招的总时长（进入 recovery 时记录），表现层按它算动作进度
var recovery_duration := 0.0
var cooldown := 0.0
var route: Callable
var clear_path: Callable
var safe_motion: Callable
var attack_serial := 0
var attack_request: Dictionary = {}
var attack_tempo := 1.0
var damage_scope: Callable
func commit_attack(profile_id: String) -> void:
	attack_serial += 1
	attack_request = actor.make_damage_request(profile_id, attack_serial, profile_id)
	if damage_scope.is_valid(): attack_request = damage_scope.call(attack_request)
	attack_tempo = actor.attributes.value("attack_speed_multiplier")
func configure(owner_actor, target_actor, settings: Dictionary, navigation: Callable, sight: Callable, motion: Callable) -> void:
	actor = owner_actor
	target = target_actor
	config = settings
	route = navigation
	clear_path = sight
	safe_motion = motion
func offset() -> Vector3:
	var result: Vector3 = target.global_position - actor.global_position
	result.y = 0.0
	return result
func begin_tick(delta: float) -> bool:
	actor.movement = Vector3.ZERO
	actor.forced_velocity = Vector3.ZERO
	if not actor.health.alive() or not target.health.alive():
		state = "idle" if actor.health.alive() else "dead"
		return false
	if actor.control_locked:
		state = "frozen"
		return false
	cooldown = maxf(0.0, cooldown - delta)
	if state == "frozen": state = "idle"
	if actor.stagger_left > 0.0:
		state = "staggered"
		return false
	if state == "staggered": state = "idle"
	return true
func aim() -> void:
	if not offset().is_zero_approx(): actor.facing = offset().normalized()
func approach() -> void:
	actor.movement = route.call(actor, target) if route.is_valid() else offset().normalized()
func retreat(multiplier: float) -> void:
	var away := -offset().normalized()
	for direction in [away, away.rotated(Vector3.UP, PI / 4.0), away.rotated(Vector3.UP, -PI / 4.0), away.rotated(Vector3.UP, PI / 2.0), away.rotated(Vector3.UP, -PI / 2.0)]:
		if not safe_motion.is_valid() or safe_motion.call(actor, direction):
			actor.movement = direction * multiplier
			return
func visible_target() -> bool: return not clear_path.is_valid() or clear_path.call(actor, target)
func cancel() -> void:
	state = "frozen" if actor.control_locked else "idle"
	time_left = 0.0
	actor.forced_velocity = Vector3.ZERO
	actor.movement = Vector3.ZERO
