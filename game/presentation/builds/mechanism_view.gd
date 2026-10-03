extends Node3D
## Consumes committed radius/state snapshots; never damages or controls actors.
var _style: Resource
var _areas: Array[Dictionary] = []
var _statuses: Dictionary = {}
func configure(style: Resource) -> void:
	assert(style.area_lifetime > 0.0 and style.area_mesh != null and style.freeze_mesh != null and style.slow_mesh != null)
	_style = style
func show_area(center: Vector3, radius: float) -> void:
	show_payload_area(center, radius, false)
func show_payload_area(center: Vector3, radius: float, has_status: bool) -> void:
	if not _style.enabled: return
	var node := _mesh(_style.area_mesh, _style.frost_area_material if has_status else _style.area_material)
	node.global_position = center + _style.area_offset
	node.scale = Vector3(radius, 1.0, radius)
	_areas.append({"node": node, "remaining": _style.area_lifetime, "fact": {}})
func show_area_fact(fact: Dictionary) -> void:
	if not _style.enabled: return
	var key: String = fact.effect_id + ("/status" if fact.has_status else "/damage")
	if not _style.area_scenes.has(key):
		show_payload_area(fact.position, fact.radius, fact.has_status)
		return
	var scene: PackedScene = _style.area_scenes[key]
	if scene == null: return
	var node: Node3D = scene.instantiate()
	add_child(node)
	node.global_position = fact.position
	if node.has_method("configure_effect"): node.configure_effect(fact.duplicate(true))
	_areas.append({"node": node, "remaining": _style.area_lifetime, "fact": fact.duplicate(true)})
func sync(snapshots: Array, delta: float) -> void:
	if not _style.enabled:
		clear()
		return
	for i in range(_areas.size() - 1, -1, -1):
		if _areas[i].node.has_method("set_time_running"): _areas[i].node.set_time_running(delta > 0.0)
		if _areas[i].node.has_method("sync_effect"): _areas[i].node.sync_effect(_areas[i].fact.duplicate(true), delta)
		_areas[i].remaining -= delta
		if _areas[i].remaining <= 0.0:
			_dispose(_areas[i].node)
			_areas.remove_at(i)
	var seen: Dictionary = {}
	for snapshot in snapshots:
		seen[snapshot.handle] = true
		var key := "freeze" if snapshot.frozen else "slow"
		if _statuses.has(snapshot.handle) and _statuses[snapshot.handle].key != key:
			_dispose(_statuses[snapshot.handle].node)
			_statuses.erase(snapshot.handle)
		if not _statuses.has(snapshot.handle):
			var created: Node3D
			if _style.status_scenes.has(key):
				var scene: PackedScene = _style.status_scenes[key]
				if scene != null:
					created = scene.instantiate()
					add_child(created)
					if created.has_method("configure_effect"): created.configure_effect(snapshot.duplicate(true))
			else: created = _mesh(_style.freeze_mesh if snapshot.frozen else _style.slow_mesh, _style.freeze_material if snapshot.frozen else _style.slow_material)
			_statuses[snapshot.handle] = {"key": key, "node": created}
		var node: Node3D = _statuses[snapshot.handle].node
		if node != null:
			node.global_position = snapshot.position + (_style.freeze_offset if snapshot.frozen else _style.slow_offset)
			if node.has_method("set_time_running"): node.set_time_running(delta > 0.0)
			if node.has_method("sync_effect"): node.sync_effect(snapshot.duplicate(true), delta)
	for handle in _statuses.keys():
		if not seen.has(handle):
			_dispose(_statuses[handle].node)
			_statuses.erase(handle)
func clear() -> void:
	for value in _areas: _dispose(value.node)
	for value in _statuses.values(): _dispose(value.node)
	_areas.clear()
	_statuses.clear()
func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
func _dispose(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.has_method("finish"): node.finish("removed")
	remove_child(node)
	node.queue_free()
