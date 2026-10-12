extends Node3D
## Simple replaceable geometry; reads snapshots only.
const Style = preload("res://presentation/builds/mechanism_style.tres")
var _paths: Array[MeshInstance3D] = []
var _shield: MeshInstance3D
var _charge: MeshInstance3D
func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
func sync(runtime, player) -> void:
	if _shield == null:
		_shield = _mesh(Style.freeze_mesh, Style.freeze_material)
		_charge = _mesh(Style.mark_mesh, Style.mark_material)
	visible = Style.enabled
	if not visible: return
	_shield.visible = player.protection_amount > 0.0
	_shield.global_position = player.global_position + Style.freeze_offset
	_charge.visible = player.charging_skill
	_charge.global_position = player.global_position + Style.mark_offset
	if player.charging_skill:
		var params: Dictionary = player.charge_parameters()
		_charge.scale = Vector3.ONE * (1.0 + minf(player.charge_elapsed / float(params.threshold_sec), 1.0))
	while _paths.size() > runtime.frost.paths.size(): _paths.pop_back().queue_free()
	while _paths.size() < runtime.frost.paths.size(): _paths.append(_mesh(Style.area_mesh, Style.frost_area_material))
	for i in _paths.size():
		var path: Dictionary = runtime.frost.paths[i]
		_paths[i].global_position = Vector3(path.position.x, 0.0, path.position.z) + Style.area_offset
		_paths[i].scale = Vector3(float(path.params.radius_m), 1.0, float(path.params.radius_m))
func clear() -> void:
	for node in _paths: node.queue_free()
	_paths.clear()
	if _shield != null: _shield.hide(); _charge.hide()
