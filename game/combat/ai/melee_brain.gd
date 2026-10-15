extends RefCounted
## 近战敌人（斥候、重装）的决策。决策节奏独立于 AbilityRunner 的前摇/判定/收招。
## 有来有回：同时出手的近战敌人有名额上限，没轮到的在外圈绕着走；打完一下会短暂后撤，给玩家反打的空档。
## 参数来自 enemies/roles.json 该角色的 config。
var actor
var target
var decision_left := 0.0
var state := "idle"
var config: Dictionary
var _route: Callable
var _clear_path: Callable
## 返回此刻正在出手（前摇到后撤结束）的近战敌人数量，不含自己
var _engaged_others: Callable
var _retreat_left := 0.0
var _was_busy := false
var _strafe_clock := 0.0
var _strafe_sign := 1.0
func configure_navigation(route: Callable, clear_path: Callable) -> void:
	_route = route
	_clear_path = clear_path
func configure_behavior(settings: Dictionary, engaged_others: Callable) -> void:
	config = settings
	_engaged_others = engaged_others
	# 各自从不同的绕圈相位开始，避免整群同步转向
	_strafe_sign = 1.0 if actor.handle % 2 == 0 else -1.0
	_strafe_clock = fmod(float(actor.handle) * 0.37, float(config.strafe_flip_sec))
func _init(owner_actor, target_actor) -> void:
	actor = owner_actor
	target = target_actor
## 正在出手或刚出完手在后撤：占用一个出手名额
func engaged() -> bool:
	return actor.health.alive() and (actor.runner.busy() or _was_busy or _retreat_left > 0.0 or state == "closing")
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
		_was_busy = false
		return
	if actor.runner.busy():
		state = actor.runner.phase()
		_was_busy = true
		return
	if _was_busy:
		# 刚打完一下：后撤一小段
		_was_busy = false
		_retreat_left = config.retreat_sec
	var offset: Vector3 = target.global_position - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > actor.definition.aggro_range:
		state = "idle"
		return
	if not offset.is_zero_approx(): actor.facing = offset.normalized()
	if _retreat_left > 0.0:
		_retreat_left = maxf(0.0, _retreat_left - delta)
		state = "retreating"
		actor.movement = -actor.facing * float(config.retreat_speed_multiplier)
		return
	var clear: bool = not _clear_path.is_valid() or _clear_path.call(actor, target)
	var reach: float = actor.attacks[0].radius
	var has_slot: bool = not _engaged_others.is_valid() or int(_engaged_others.call(self)) < int(config.attack_slots)
	if not has_slot and distance <= float(config.engage_distance_m) and clear:
		# 没轮到出手：在外圈横移，保持距离
		state = "circling"
		_strafe_clock += delta
		if _strafe_clock >= float(config.strafe_flip_sec):
			_strafe_clock = 0.0
			_strafe_sign = -_strafe_sign
		var side := Vector3(-actor.facing.z, 0.0, actor.facing.x) * _strafe_sign
		var keep := 0.0
		if distance < float(config.engage_distance_m) * 0.8: keep = -0.6
		actor.movement = (side + actor.facing * keep).normalized() * float(config.strafe_speed_multiplier)
		return
	state = "closing" if has_slot and distance <= float(config.engage_distance_m) else "seeking"
	if distance > reach or not clear:
		actor.movement = _route.call(actor, target) if _route.is_valid() else actor.facing
	decision_left -= delta
	if decision_left > 0.0: return
	decision_left = actor.definition.decision_interval
	if clear and has_slot and distance <= reach and actor.runner.cooldown <= 0.0:
		actor.request_attack()

func cancel() -> void:
	actor.cancel()
	_retreat_left = 0.0
	_was_busy = false
	state = "frozen" if actor.control_locked else "idle"
