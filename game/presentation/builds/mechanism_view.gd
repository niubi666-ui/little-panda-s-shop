extends Node3D
## Consumes committed radius/state snapshots; never damages or controls actors.
var _style: Resource
var _areas: Array[Dictionary] = []
var _statuses: Dictionary = {}
var _tails: Array[Node] = []
func configure(style: Resource) -> void:
	assert(style.area_lifetime > 0.0 and style.area_mesh != null and style.freeze_mesh != null and style.slow_mesh != null)
	_style = style
func show_area(center: Vector3, radius: float) -> void:
	show_payload_area(center, radius, false)
func show_conditional_fact(fact: Dictionary) -> void:
	if not _style.enabled: return
	var label := Label3D.new()
	label.name = "ConditionalDamageFeedback"
	label.font = _style.conditional_font
	label.font_size = _style.conditional_font_size
	label.pixel_size = _style.conditional_pixel_size
	label.modulate = _style.conditional_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = tr("build.feedback.conditional").format({"bonus_percent": roundi(float(fact.bonus) * 100.0)})
	add_child(label)
	label.global_position = fact.position + _style.conditional_offset
	_areas.append({"node": label, "remaining": _style.conditional_lifetime, "fact": fact})
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
	_tick_tails(delta)
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
		if not snapshot.frozen and snapshot.statuses.all(func(s): return s.get("kind", "slow") == "mark"): key = "mark"
		if snapshot.statuses.is_empty(): key = "immune"
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
			elif key == "immune":
				created = Node3D.new()
				add_child(created)
			elif key == "mark": created = _mesh(_style.mark_mesh, _style.mark_material)
			else: created = _mesh(_style.freeze_mesh if snapshot.frozen else _style.slow_mesh, _style.freeze_material if snapshot.frozen else _style.slow_material)
			_statuses[snapshot.handle] = {"key": key, "node": created}
			if created != null:
				var label := Label3D.new()
				label.name = "StatusText"
				label.font = _style.conditional_font
				label.font_size = _style.conditional_font_size
				label.pixel_size = _style.conditional_pixel_size
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				created.add_child(label)
		var node: Node3D = _statuses[snapshot.handle].node
		if node != null:
			node.global_position = snapshot.position + (_style.freeze_offset if snapshot.frozen else _style.slow_offset)
			if key == "mark": node.global_position = snapshot.position + _style.mark_offset
			var label: Label3D = node.get_node("StatusText")
			label.global_position = snapshot.position + _style.mark_offset
			var tags: PackedStringArray = []
			if snapshot.get("marked", false): tags.append(tr("build.status.mark"))
			if snapshot.get("freeze_window", false): tags.append(tr("build.status.hard" if snapshot.frozen else "build.status.window"))
			if snapshot.get("thaw_immune", false): tags.append(tr("build.status.immune"))
			label.text = " / ".join(tags)
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
	# 清场（换房间、关闭特效）时收尾动画不再播，直接释放
	for node in _tails:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_tails.clear()
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
	# 有收尾动画的状态场景（如冰冻碎裂）：状态已经结束，继续跟战斗时钟播完再释放
	if node.has_method("has_tail") and node.has_tail() and not _tails.has(node):
		var label := node.get_node_or_null("StatusText")
		if label != null: label.hide()
		_tails.append(node)
		return
	remove_child(node)
	node.queue_free()
func _tick_tails(delta: float) -> void:
	for i in range(_tails.size() - 1, -1, -1):
		var node: Node = _tails[i]
		if is_instance_valid(node): node.tail_tick(delta)
		if not is_instance_valid(node) or not node.has_tail():
			_tails.remove_at(i)
			if is_instance_valid(node):
				remove_child(node)
				node.queue_free()
