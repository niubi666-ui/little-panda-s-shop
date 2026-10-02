extends RefCounted
## Local status clock. No timers, delayed damage, or new root budgets.
const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog
var _actors: Dictionary = {}
var _instances: Dictionary = {}
func configure(catalog) -> void:
	clear()
	_catalog = catalog
func apply(target, status_id: String, duration: float, source: Dictionary) -> bool:
	if not is_instance_valid(target) or not target.health.alive(): return false
	var definition: Dictionary = _catalog.status(status_id)
	var response: Dictionary = _catalog.status_response(target.definition.id)
	if response.immune_kinds.has(definition.kind): return false
	var remaining := minf(duration, float(definition.max_duration_sec)) * float(response[definition.kind + "_duration_scale"])
	if remaining <= 0.0: return false
	if not _actors.has(target.handle):
		_actors[target.handle] = weakref(target)
		_instances[target.handle] = {}
		target.killed.connect(_on_killed)
	var values: Dictionary = _instances[target.handle]
	# One instance per definition; longest remaining duration, never additive stacks.
	if not values.has(status_id) or remaining >= float(values[status_id].remaining):
		values[status_id] = {"definition": definition, "remaining": remaining, "source": Catalog.freeze_copy(source)}
	_recompute(target.handle)
	return true
func tick(delta: float) -> void:
	if delta <= 0.0: return
	for handle in _actors.keys():
		var target = _actors[handle].get_ref()
		if not is_instance_valid(target) or not target.health.alive():
			_detach(handle)
			continue
		var values: Dictionary = _instances[handle]
		for id in values.keys():
			values[id].remaining -= delta
			if values[id].remaining <= 0.0: values.erase(id)
		_recompute(handle)
func remove(target, status_id: String) -> void:
	if not is_instance_valid(target) or not _instances.has(target.handle): return
	_instances[target.handle].erase(status_id)
	_recompute(target.handle)
func clear() -> void:
	for handle in _actors.keys(): _detach(handle)
func snapshot(target) -> Dictionary:
	return Catalog.freeze_copy(_instances[target.handle]) if is_instance_valid(target) and _instances.has(target.handle) else {}
func visuals() -> Array:
	var result: Array = []
	for handle in _actors:
		var target = _actors[handle].get_ref()
		if is_instance_valid(target) and target.health.alive():
			result.append({"handle": handle, "position": target.global_position, "frozen": target.control_locked})
	return Catalog.freeze_copy(result)
func _recompute(handle: int) -> void:
	if _instances[handle].is_empty():
		_detach(handle)
		return
	var target = _actors[handle].get_ref()
	if not is_instance_valid(target):
		_detach(handle)
		return
	var scale := 1.0
	var locked := false
	for status in _instances[handle].values():
		scale = minf(scale, float(status.definition.move_scale))
		locked = locked or status.definition.kind == "freeze"
	target.set_control(scale, locked)
func _on_killed(actor) -> void: _detach(actor.handle)
func _detach(handle: int) -> void:
	if not _actors.has(handle): return
	var target = _actors[handle].get_ref()
	if is_instance_valid(target):
		if target.killed.is_connected(_on_killed): target.killed.disconnect(_on_killed)
		target.set_control(1.0, false)
	_actors.erase(handle)
	_instances.erase(handle)
