extends RefCounted
## Reuses complete furniture roots from the loaded shop. Does not edit source scenes.
var _shop: Node3D
var _style
var _catalog
var _geometry
var errors: PackedStringArray = []
func configure(shop: Node3D, style, catalog, geometry) -> bool:
	_shop = shop
	_style = style
	_catalog = catalog
	_geometry = geometry
	for item in catalog.entries():
		if not style.source_nodes.has(item.asset_id) or not shop.has_node(style.source_nodes[item.asset_id]):
			errors.append("Missing furniture source " + item.asset_id)
	return errors.is_empty()
func create(entry: Dictionary, ghost: bool) -> Node3D:
	var item = _catalog.furniture(entry.definition_id)
	var source: Node3D = _shop.get_node(_style.source_nodes[item.asset_id])
	var node: Node3D = source.duplicate(0)
	node.name = entry.instance_id.replace(".", "_")
	# The source scale is authored calibration; yaw is the player's quarter turn.
	node.transform = Transform3D(Basis(Vector3.UP, entry.quarter_turn * PI / 2.0) * Basis.from_scale(source.scale), _geometry.placement_center(entry))
	_reidentify(node, entry.instance_id)
	if ghost:
		for body in node.find_children("*", "CollisionObject3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
		for light in node.find_children("*", "Light3D", true, false): light.visible = false
	return node
func _reidentify(node: Node, id: String) -> void:
	if node.has_meta("instance_id"): node.set_meta("instance_id", id)
	if node.has_meta("part_of"): node.set_meta("part_of", id)
	for child in node.get_children(): _reidentify(child, id)
func tint_ghost(node: Node3D, valid: bool) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _style.valid_material if valid else _style.invalid_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func targets(node: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for marker in node.find_children("*", "Marker3D", true, false):
		if marker.has_meta("instance_id") and marker.has_meta("name_key"): result.append(marker)
	return result
