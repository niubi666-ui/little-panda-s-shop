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
	var node := _mesh(_style.area_mesh, _style.frost_area_material if has_status else _style.area_material)
	node.global_position = center + _style.area_offset
	node.scale = Vector3(radius, 1.0, radius)
	_areas.append({"node": node, "remaining": _style.area_lifetime})
func sync(snapshots: Array, delta: float) -> void:
	for i in range(_areas.size() - 1, -1, -1):
		_areas[i].remaining -= delta
		if _areas[i].remaining <= 0.0:
			_dispose(_areas[i].node)
			_areas.remove_at(i)
	var seen: Dictionary = {}
	for snapshot in snapshots:
		seen[snapshot.handle] = true
		if not _statuses.has(snapshot.handle): _statuses[snapshot.handle] = _mesh(_style.slow_mesh, _style.slow_material)
		var node: MeshInstance3D = _statuses[snapshot.handle]
		node.mesh = _style.freeze_mesh if snapshot.frozen else _style.slow_mesh
		node.material_override = _style.freeze_material if snapshot.frozen else _style.slow_material
		node.global_position = snapshot.position + (_style.freeze_offset if snapshot.frozen else _style.slow_offset)
	for handle in _statuses.keys():
		if not seen.has(handle):
			_dispose(_statuses[handle])
			_statuses.erase(handle)
func clear() -> void:
	for value in _areas: _dispose(value.node)
	for value in _statuses.values(): _dispose(value)
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
	remove_child(node)
	node.queue_free()
