extends RefCounted
const Catalog = preload("res://content/combat/combat_catalog.gd")
signal committed(cast_id: int, ability_id: String)
signal cue_reached(cast_id: int, ability_id: String)
var ability: Catalog.Ability
var cast_id := 0
var elapsed := 0.0
var cooldown := 0.0
var direction := Vector3.FORWARD
var active_this_step := false
var _running := false
var actions_allowed := true
var _hit_targets: Dictionary = {}
func start(definition: Catalog.Ability, facing: Vector3) -> bool:
	if not actions_allowed or _running or cooldown > 0.0: return false
	ability = definition
	cast_id += 1
	elapsed = 0.0
	cooldown = ability.cooldown
	direction = facing
	_hit_targets.clear()
	_running = true
	committed.emit(cast_id, ability.id)
	return true
func tick(delta: float) -> void:
	active_this_step = false
	if not actions_allowed:
		cancel()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if not _running: return
	var before := elapsed
	elapsed += delta
	if before < ability.windup and elapsed >= ability.windup:
		cue_reached.emit(cast_id, ability.id)
	# Detect crossings even when a physics step spans the whole active phase.
	active_this_step = before < ability.windup + ability.active and elapsed >= ability.windup
	if elapsed >= ability.windup + ability.active + ability.recovery:
		_running = false
func phase() -> String:
	if not _running: return "idle"
	if elapsed < ability.windup: return "windup"
	if elapsed < ability.windup + ability.active: return "active"
	return "recovery"
func busy() -> bool: return _running
func cancel() -> void:
	_running = false
	active_this_step = false
	_hit_targets.clear()
func claim_target(handle: int) -> bool:
	if _hit_targets.has(handle): return false
	_hit_targets[handle] = true
	return true
