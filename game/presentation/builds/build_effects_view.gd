extends Node3D
## Read-only adapter for committed projectile positions and chain cues.
var _style: Resource
var _projectiles: Dictionary = {}
var _chains: Array[Dictionary] = []


func configure(style: Resource) -> void:
	assert(style != null)
	assert(style.projectile_mesh != null and style.projectile_material != null)
	assert(style.chain_material != null and style.chain_lifetime_sec > 0.0)
	assert(style.projectile_size_per_radius.x > 0.0)
	assert(style.projectile_size_per_radius.y > 0.0)
	assert(style.projectile_size_per_radius.z > 0.0)
	_style = style


func sync(projectiles: Array, delta: float) -> void:
	assert(_style != null and delta >= 0.0)
	var present: Dictionary = {}
	for snapshot in projectiles:
		var id: int = snapshot["id"]
		present[id] = true
		if not _projectiles.has(id):
			var created := MeshInstance3D.new()
			created.name = "BuildProjectile_%s" % id
			created.mesh = _style.projectile_mesh_overrides.get(snapshot["definition_id"], _style.projectile_mesh)
			created.material_override = _style.projectile_material
			created.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(created)
			_projectiles[id] = created
		var visual: MeshInstance3D = _projectiles[id]
		var point: Vector3 = snapshot["position"]
		var direction: Vector3 = snapshot["direction"]
		visual.global_position = point + Vector3.UP * _style.projectile_height
		var orientation := Basis.IDENTITY
		if not direction.is_zero_approx():
			orientation = Basis.looking_at(direction.normalized(), Vector3.UP)
		visual.global_basis = orientation * Basis.from_scale(_style.projectile_size_per_radius * float(snapshot["radius"]))
	for id in _projectiles.keys():
		if not present.has(id):
			_dispose(_projectiles[id])
			_projectiles.erase(id)
	if delta == 0.0:
		return
	for index in range(_chains.size() - 1, -1, -1):
		var chain: Dictionary = _chains[index]
		chain["remaining"] = maxf(0.0, float(chain["remaining"]) - delta)
		if float(chain["remaining"]) == 0.0:
			_dispose(chain["node"])
			_chains.remove_at(index)
			continue
		var material: StandardMaterial3D = chain["material"]
		var color: Color = _style.chain_material.albedo_color
		color.a *= float(chain["remaining"]) / _style.chain_lifetime_sec
		material.albedo_color = color


func show_chain(points: PackedVector3Array) -> void:
	assert(_style != null)
	if points.size() < 2:
		return
	var material: StandardMaterial3D = _style.chain_material.duplicate()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in points:
		mesh.surface_add_vertex(to_local(point + Vector3.UP * _style.chain_height))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.name = "BuildChain"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_chains.append({"node": visual, "material": material, "remaining": _style.chain_lifetime_sec})


func clear() -> void:
	for visual in _projectiles.values():
		_dispose(visual)
	_projectiles.clear()
	for chain in _chains:
		_dispose(chain["node"])
	_chains.clear()


func _dispose(visual: Node) -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
