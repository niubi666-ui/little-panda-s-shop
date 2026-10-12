extends RefCounted
## One battle clock owns active statuses and target-side thaw immunity.
## Only weak actors and stable source values are retained; roots stay in BuildRuntime.
const Catalog = preload("res://content/builds/build_catalog.gd")
signal freeze_window_applied(target, status_id: String, source: Dictionary)
var _catalog
var _clock := 0.0
var _generation := 0
var _actors: Dictionary = {}
var _instances: Dictionary = {}
var _control_groups: Dictionary = {}
var _freeze_hits: Dictionary = {}

func configure(catalog) -> void:
	clear()
	_catalog = catalog

func apply(target, status_id: String, duration: float, source: Dictionary, root_attempts: Dictionary = {}) -> bool:
	if not is_instance_valid(target) or not target.health.alive(): return false
	var definition: Dictionary = _catalog.status(status_id)
	var group: String = definition.control_group
	if not group.is_empty():
		# An alive target consumes this root's single group attempt even when immune,
		# already frozen, or in its thaw window. A later contact cannot retry it.
		if not root_attempts.has(target.handle): root_attempts[target.handle] = {}
		if root_attempts[target.handle].has(group): return false
		root_attempts[target.handle][group] = true
		if _control_groups.has(target.handle) and _control_groups[target.handle].has(group):
			var guard: Dictionary = _control_groups[target.handle][group]
			if _clock < float(guard.immune_until): return false
	var response: Dictionary = _catalog.status_response(target.definition.id)
	if response.immune_kinds.has(definition.kind): return false
	var remaining := minf(duration, float(definition.max_duration_sec)) * float(response[definition.kind + "_duration_scale"])
	if remaining <= 0.0: return false
	_attach(target)
	if definition.kind == "freeze":
		var hits: int = int(_freeze_hits[target.handle].get(group, 0)) + 1
		if hits < int(response.freeze_hits_required):
			_freeze_hits[target.handle][group] = hits
			return false
		_freeze_hits[target.handle].erase(group)
	var expires_at := _clock + remaining
	var values: Dictionary = _instances[target.handle]
	if not group.is_empty():
		var immunity := float(_catalog.control_group(group).thaw_immunity_sec) * float(response.thaw_immunity_scale)
		_control_groups[target.handle][group] = {
			"active_until": expires_at,
			"immune_until": expires_at + immunity, "immunity_sec": immunity,
		}
	# Slow keeps longest remaining time. Validated freeze rejects every active
	# application above, including a different status id in the same group.
	if not values.has(status_id) or expires_at >= float(values[status_id].expires_at):
		values[status_id] = {"definition": definition, "expires_at": expires_at, "applied_at": _clock,
			"source": Catalog.freeze_copy(source)}
	var handle: int = target.handle
	var generation := _generation
	_recompute(handle)
	if definition.kind == "freeze" and generation == _generation and _instances.has(handle) and _instances[handle].has(status_id):
		freeze_window_applied.emit(target, status_id, Catalog.freeze_copy(source))
	# set_control emits synchronously. The receiver may clear the room, dispel
	# this status, or kill the target before apply returns to its caller.
	return generation == _generation and is_instance_valid(target) and target.health.alive() and _instances.has(handle) and _instances[handle].has(status_id)

func tick(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	var generation := _generation
	for handle in _actors.keys():
		if generation != _generation: return
		if not _actors.has(handle): continue
		var target = _actors[handle].get_ref()
		if not is_instance_valid(target) or not target.health.alive():
			_detach(handle)
			continue
		var values: Dictionary = _instances[handle]
		for id in values.keys():
			if _clock >= float(values[id].expires_at): values.erase(id)
		var groups: Dictionary = _control_groups[handle]
		for id in groups.keys():
			# Absolute deadline: a large step spanning thaw and immunity cannot
			# accidentally start a fresh immunity window at the end of that step.
			if _clock >= float(groups[id].immune_until): groups.erase(id)
		_recompute(handle)

func remove(target, status_id: String) -> void:
	if not is_instance_valid(target) or not _instances.has(target.handle): return
	var values: Dictionary = _instances[target.handle]
	if not values.has(status_id): return
	var group: String = values[status_id].definition.control_group
	if not group.is_empty():
		# Explicit dispel thaws now and grants the complete configured window.
		var immunity: float = _control_groups[target.handle][group].immunity_sec
		_control_groups[target.handle][group] = {"active_until": _clock,
			"immune_until": _clock + immunity, "immunity_sec": immunity}
	values.erase(status_id)
	_recompute(target.handle)

func clear() -> void:
	_generation += 1
	for handle in _actors.keys(): _detach(handle)
	_clock = 0.0

func snapshot(target) -> Dictionary:
	if not is_instance_valid(target) or not _instances.has(target.handle): return {}
	var result: Dictionary = {}
	for id in _instances[target.handle]:
		var status: Dictionary = _instances[target.handle][id].duplicate()
		status.remaining = maxf(0.0, float(status.expires_at) - _clock)
		result[id] = status
	return Catalog.freeze_copy(result)

func control_snapshot(target) -> Dictionary:
	return Catalog.freeze_copy(_control_groups[target.handle]) if is_instance_valid(target) and _control_groups.has(target.handle) else {}

func freeze_progress(target) -> Dictionary:
	return Catalog.freeze_copy(_freeze_hits[target.handle]) if is_instance_valid(target) and _freeze_hits.has(target.handle) else {}

func diagnostics() -> Dictionary:
	return {"clock": _clock, "tracked_actors": _actors.size()}

func visuals() -> Array:
	var result: Array = []
	for handle in _actors:
		var target = _actors[handle].get_ref()
		if is_instance_valid(target) and target.health.alive() and (not _instances[handle].is_empty() or not _control_groups[handle].is_empty()):
			var active: Array = []
			var window := false
			var marked := false
			for id in _instances[handle]:
				window = window or _instances[handle][id].definition.kind == "freeze"
				marked = marked or _instances[handle][id].definition.kind == "mark"
				active.append({"status_id": id, "kind": _instances[handle][id].definition.kind, "source": _instances[handle][id].source})
			result.append({"handle": handle, "position": target.global_position, "frozen": target.control_locked, "statuses": active,
				"freeze_window": window, "marked": marked, "thaw_immune": not window and not _control_groups[handle].is_empty()})
	return Catalog.freeze_copy(result)

func _attach(target) -> void:
	if _actors.has(target.handle): return
	_actors[target.handle] = weakref(target)
	_instances[target.handle] = {}
	_control_groups[target.handle] = {}
	_freeze_hits[target.handle] = {}
	target.killed.connect(_on_killed)

func _recompute(handle: int) -> void:
	if not _actors.has(handle): return
	var target = _actors[handle].get_ref()
	if not is_instance_valid(target) or not target.health.alive():
		_detach(handle)
		return
	var scale := 1.0
	var action_scale := 1.0
	var locked := false
	var response: Dictionary = _catalog.status_response(target.definition.id)
	for status in _instances[handle].values():
		if status.definition.kind == "freeze":
			locked = locked or response.freeze_mode == "hard"
			if response.freeze_mode == "slow":
				scale = minf(scale, float(response.freeze_move_scale))
				action_scale = minf(action_scale, float(response.freeze_action_scale))
		else: scale = minf(scale, float(status.definition.move_scale))
	var generation := _generation
	target.set_control(scale, locked, action_scale)
	if generation != _generation or not _actors.has(handle): return
	if _instances[handle].is_empty() and _control_groups[handle].is_empty() and _freeze_hits[handle].is_empty(): _detach(handle)

func _on_killed(actor) -> void: _detach(actor.handle)

func _detach(handle: int) -> void:
	if not _actors.has(handle): return
	var target = _actors[handle].get_ref()
	if is_instance_valid(target):
		if target.killed.is_connected(_on_killed): target.killed.disconnect(_on_killed)
		target.set_control(1.0, false)
	_actors.erase(handle)
	_instances.erase(handle)
	_control_groups.erase(handle)
	_freeze_hits.erase(handle)
