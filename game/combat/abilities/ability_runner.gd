extends RefCounted
const Catalog = preload("res://content/combat/combat_catalog.gd")
signal committed(cast_id: int, ability_id: String)
signal cue_reached(cast_id: int, ability_id: String)
signal finished(cast_id: int, ability_id: String, reason: String)
var ability: Catalog.Ability
var cast_id := 0
var elapsed := 0.0
var direction := Vector3.FORWARD
var active_this_step := false
var actions_allowed := true
var _running := false
var _hit_targets: Dictionary = {}
var _cooldowns: Dictionary = {}
var _cast_context: Dictionary = {}
var cast_context: Dictionary:
	get: return _cast_context
var action_id: String:
	get: return str(_cast_context.get("action_id", "primary"))
var form_id: String:
	get: return str(_cast_context.get("form_id", ""))
var executor: String:
	get: return str(_cast_context.get("executor", "melee"))
var presentation_key: String:
	get: return str(_cast_context.get("presentation_key", ""))
# Compatibility view for enemy brains and existing direct-runner fixtures.
# Player arbitration asks cooldown_for(the_requested_action).
var cooldown: float:
	get: return cooldown_for(action_id)
	set(value): _cooldowns[action_id] = maxf(0.0, value)


func cooldown_for(id: String) -> float:
	return float(_cooldowns.get(id, 0.0))


func start(definition: Catalog.Ability, facing: Vector3, context: Dictionary = {}) -> bool:
	var next_action: String = str(context.action_id) if not context.is_empty() else "primary"
	if not actions_allowed or _running or cooldown_for(next_action) > 0.0: return false
	ability = definition
	cast_id += 1
	elapsed = 0.0
	direction = facing
	_hit_targets.clear()
	active_this_step = false
	_cast_context = context.duplicate(true) if not context.is_empty() else {
		"action_id": "primary", "form_id": "", "executor": "melee",
		"ability_ids": [definition.id], "projectile_id": "", "presentation_key": definition.id, "revision": 0,
	}
	_freeze(_cast_context)
	_cooldowns[next_action] = ability.cooldown
	_running = true
	var expected_cast := cast_id
	committed.emit(cast_id, ability.id)
	# Zero-windup actions release in the accepting call, after the committed snapshot.
	# A committed listener may cancel or replace this cast before its cue.
	if _running and cast_id == expected_cast and actions_allowed and ability.windup == 0.0:
		active_this_step = true
		cue_reached.emit(cast_id, ability.id)
	return true


func tick(delta: float) -> void:
	active_this_step = false
	if not actions_allowed:
		cancel("control")
		return
	for id in _cooldowns: _cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
	if not _running: return
	var before := elapsed
	var expected_cast := cast_id
	elapsed += delta
	if before < ability.windup and elapsed >= ability.windup:
		cue_reached.emit(cast_id, ability.id)
		# A cue consumer may cancel, kill, switch room, or start another cast.
		if not _running or cast_id != expected_cast or not actions_allowed: return
	active_this_step = before < ability.windup + ability.active and elapsed >= ability.windup
	if elapsed >= ability.windup + ability.active + ability.recovery:
		_running = false
		finished.emit(cast_id, ability.id, "completed")


func phase() -> String:
	if not _running: return "idle"
	if elapsed < ability.windup: return "windup"
	if elapsed < ability.windup + ability.active: return "active"
	return "recovery"


func busy() -> bool: return _running


func can_cancel_for_dodge() -> bool:
	return not _running or ability.dodge_cancel_phases.has(phase())


func cancel(reason: String = "cancelled") -> void:
	var was_running := _running
	_running = false
	active_this_step = false
	_hit_targets.clear()
	if was_running: finished.emit(cast_id, ability.id, reason)


func claim_target(handle: int) -> bool:
	if _hit_targets.has(handle): return false
	_hit_targets[handle] = true
	return true


func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()
