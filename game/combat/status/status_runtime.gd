extends RefCounted
## One battle clock owns active statuses and target-side thaw immunity.
## Only weak actors and stable source values are retained; roots stay in BuildRuntime.
const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog
var _clock := 0.0
var _generation := 0
var _actors: Dictionary = {}
var _instances: Dictionary = {}
var _control_groups: Dictionary = {}

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
	var expires_at := _clock + remaining
	var values: Dictionary = _instances[target.handle]
	if not group.is_empty():
		_control_groups[target.handle][group] = {
			"active_until": expires_at,
			"immune_until": expires_at + float(_catalog.control_group(group).thaw_immunity_sec),
		}
	# Slow keeps longest remaining time. Validated freeze rejects every active
	# application above, including a different status id in the same group.
	if not values.has(status_id) or expires_at >= float(values[status_id].expires_at):
		values[status_id] = {"definition": definition, "expires_at": expires_at,
			"source": Catalog.freeze_copy(source)}
	var handle: int = target.handle
	var generation := _generation
	_recompute(handle)
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
		_control_groups[target.handle][group] = {"active_until": _clock,
			"immune_until": _clock + float(_catalog.control_group(group).thaw_immunity_sec)}
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

func diagnostics() -> Dictionary:
	return {"clock": _clock, "tracked_actors": _actors.size()}

func visuals() -> Array:
	var result: Array = []
	for handle in _actors:
		var target = _actors[handle].get_ref()
		if is_instance_valid(target) and target.health.alive() and not _instances[handle].is_empty():
			var active: Array = []
			for id in _instances[handle]:
				active.append({"status_id": id, "source": _instances[handle][id].source})
			result.append({"handle": handle, "position": target.global_position, "frozen": target.control_locked, "statuses": active})
	return Catalog.freeze_copy(result)

func _attach(target) -> void:
	if _actors.has(target.handle): return
	_actors[target.handle] = weakref(target)
	_instances[target.handle] = {}
	_control_groups[target.handle] = {}
	target.killed.connect(_on_killed)

func _recompute(handle: int) -> void:
	if not _actors.has(handle): return
	var target = _actors[handle].get_ref()
	if not is_instance_valid(target) or not target.health.alive():
		_detach(handle)
		return
	var scale := 1.0
	var locked := false
	for status in _instances[handle].values():
		scale = minf(scale, float(status.definition.move_scale))
		locked = locked or status.definition.kind == "freeze"
	var generation := _generation
	target.set_control(scale, locked)
	if generation != _generation or not _actors.has(handle): return
	if _instances[handle].is_empty() and _control_groups[handle].is_empty(): _detach(handle)

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
