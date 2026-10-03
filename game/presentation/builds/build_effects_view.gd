extends Node3D
## Read-only adapter for committed projectile positions and chain cues.
var _style: Resource
var _projectiles: Dictionary = {}
var _chains: Array[Dictionary] = []
var _trails: Dictionary = {}
var _events: Array[Dictionary] = []


func configure(style: Resource) -> void:
	assert(style != null)
	assert(not style.enabled or (style.projectile_mesh != null and style.projectile_material != null))
	assert(style.chain_material != null and style.chain_lifetime_sec > 0.0)
	assert(style.projectile_size_per_radius.x > 0.0)
	assert(style.projectile_size_per_radius.y > 0.0)
	assert(style.projectile_size_per_radius.z > 0.0)
	for rule in style.projectile_scene_rules:
		assert(rule.has("definition_id") and rule.has("required_effect_id") and rule.has("scene"))
		assert(rule.definition_id is String and not rule.definition_id.is_empty())
		assert(rule.required_effect_id is String and not rule.required_effect_id.is_empty())
		assert(style.projectile_scenes.has(rule.definition_id), "A projectile variant requires an explicit base scene slot.")
		assert(rule.scene == null or rule.scene is PackedScene)
	_style = style


func sync(projectiles: Array, delta: float) -> void:
	assert(_style != null and delta >= 0.0)
	if not _style.enabled:
		clear()
		return
	var present: Dictionary = {}
	for snapshot in projectiles:
		var id: int = snapshot["id"]
		present[id] = true
		if not _projectiles.has(id):
			var created: Node3D
			if _style.projectile_scenes.has(snapshot.definition_id):
				created = _instantiate(_projectile_scene(snapshot), snapshot)
			else:
				var mesh := MeshInstance3D.new()
				mesh.mesh = _style.projectile_mesh_overrides.get(snapshot["definition_id"], _style.projectile_mesh)
				mesh.material_override = _style.projectile_material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mesh)
				created = mesh
			if created != null: created.name = "BuildProjectile_%s" % id
			_projectiles[id] = created
			if _style.trail_scenes.has(snapshot.definition_id): _trails[id] = _instantiate(_style.trail_scenes[snapshot.definition_id], snapshot)
		var visual: Node3D = _projectiles[id]
		var point: Vector3 = snapshot["position"]
		var direction: Vector3 = snapshot["direction"]
		var orientation := Basis.IDENTITY
		if not direction.is_zero_approx():
			orientation = Basis.looking_at(direction.normalized(), Vector3.UP)
		if visual != null:
			visual.global_position = point + Vector3.UP * _style.projectile_height
			visual.global_basis = orientation * Basis.from_scale(_style.projectile_size_per_radius * float(snapshot["radius"]))
			_sync_scene(visual, snapshot, delta)
		if _trails.has(id) and _trails[id] != null:
			_trails[id].global_position = point
			_sync_scene(_trails[id], snapshot, delta)
	for id in _projectiles.keys():
		if not present.has(id):
			_dispose(_projectiles[id])
			_projectiles.erase(id)
			if _trails.has(id):
				_dispose(_trails[id])
				_trails.erase(id)
	for index in range(_events.size() - 1, -1, -1):
		var entry: Dictionary = _events[index]
		_sync_scene(entry.node, entry.fact, delta)
		entry.remaining -= delta
		if entry.remaining <= 0.0:
			_dispose(entry.node)
			_events.remove_at(index)
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


func _projectile_scene(snapshot: Dictionary) -> PackedScene:
	var base: PackedScene = _style.projectile_scenes[snapshot.definition_id]
	if base == null: return null
	# This runs only when an authoritative projectile ID first enters the view.
	# No current Build lookup: later revisions cannot replace an in-flight visual.
	for rule in _style.projectile_scene_rules:
		if rule.definition_id == snapshot.definition_id and snapshot.effect_ids.has(rule.required_effect_id):
			return rule.scene
	return base


func show_chain(points: PackedVector3Array) -> void:
	assert(_style != null)
	if not _style.enabled: return
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
	for trail in _trails.values(): _dispose(trail)
	_trails.clear()
	for event in _events: _dispose(event.node)
	_events.clear()

func on_projectile_event(fact: Dictionary) -> void:
	if not _style.enabled: return
	var scenes: Dictionary = _style.contact_scenes if fact.event == "contact" else _style.termination_scenes
	if fact.event in ["contact", "terminated"] and scenes.has(fact.definition_id):
		_show_event(scenes[fact.definition_id], fact)
	if fact.event == "terminated":
		for collection in [_projectiles, _trails]:
			if collection.has(fact.id) and is_instance_valid(collection[fact.id]) and collection[fact.id].has_method("finish"):
				collection[fact.id].finish(fact.reason)

func on_action_event(fact: Dictionary) -> void:
	if not _style.enabled: return
	var key: String = fact.presentation_key + "/" + fact.event
	if _style.action_scenes.has(key): _show_event(_style.action_scenes[key], fact)
	if not fact.event in ["started", "cue"]:
		for index in range(_events.size() - 1, -1, -1):
			if _events[index].fact.get("cast_id") == fact.cast_id and _events[index].fact.get("event") in ["started", "cue"]:
				_dispose(_events[index].node)
				_events.remove_at(index)

func _instantiate(scene: PackedScene, fact: Dictionary) -> Node3D:
	if scene == null: return null
	var node: Node3D = scene.instantiate()
	add_child(node)
	if node.has_method("configure_effect"): node.configure_effect(fact.duplicate(true))
	return node

func _show_event(scene: PackedScene, fact: Dictionary) -> void:
	var node := _instantiate(scene, fact)
	if node == null: return
	node.global_position = fact.position
	_events.append({"node": node, "fact": fact.duplicate(true), "remaining": _style.event_lifetime_sec})

func _sync_scene(node: Node3D, fact: Dictionary, delta: float) -> void:
	if node.has_method("set_time_running"): node.set_time_running(delta > 0.0)
	if node.has_method("sync_effect"): node.sync_effect(fact.duplicate(true), delta)


func _dispose(visual: Node) -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
