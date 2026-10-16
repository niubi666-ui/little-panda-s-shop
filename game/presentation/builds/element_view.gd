extends Node3D
## 元素表现：敌人身上的元素状态、命中闪光、反应爆发与文字、熔岩区域、感电电弧。
## 只消费 BuildRuntime 已提交的元素事实和快照，不做任何判定；关掉不影响伤害。
const Style = preload("res://presentation/builds/element_style.gd")

var style: Style
var _font: Font
var _catalog
## handle → {badge: Label3D, ring: MeshInstance3D}
var _marks: Dictionary = {}
## handle → {element_id: CPUParticles3D}
var _auras: Dictionary = {}
## 一次性效果：[node, 剩余时间, 类型, 额外数据]
var _transients: Array = []
## zone_id → {node, embers, remaining, total}
var _zones: Dictionary = {}
var _running := true

## catalog：BuildCatalog（读元素名的翻译 key）
func configure(settings: Style, font: Font, catalog) -> void:
	assert(settings != null and settings.ring_material != null and settings.zone_material != null and settings.under_ring_material != null, "element style incomplete")
	style = settings
	_font = font
	_catalog = catalog

## BuildRuntime.element_presented
func on_fact(fact: Dictionary) -> void:
	match String(fact.event):
		"applied":
			var at: Vector3 = fact.position + Vector3.UP * style.burst_height_m
			_burst(style.apply_burst, at, _element_color(fact.element))
			_flash(at, _element_color(fact.element), style.apply_flash_energy, style.apply_flash_range_m)
		"discharge": _arcs(fact.points, _element_color(fact.element))
		"reaction": _reaction(fact, style.reaction_colors.get(fact.reaction_id, Color.WHITE))
		"mastery":
			# 同元素专精爆发：沿用反应的冲击波/闪光/名字，颜色取元素色；放电专精再画电弧
			var color := _element_color(fact.element)
			if fact.points.size() > 0:
				var arcs := PackedVector3Array()
				for point in fact.points: arcs.append_array([fact.position, point])
				_arcs(arcs, color)
			_reaction({"reaction_id": "", "position": fact.position, "radius": fact.radius, "pull": false, "zone_id": -1,
				"name_key": "element.mastery." + String(fact.element)}, color)
		"zone_ended": _end_zone(int(fact.zone_id))
		"cleared": _drop_aura(int(fact.handle))

## 每帧：按快照同步敌人身上的元素特效；delta 为 0 时（暂停）全部冻结
func sync(snapshot: Array, delta: float) -> void:
	_running = delta > 0.0
	var seen: Dictionary = {}
	for entry in snapshot:
		var target = entry.target
		if not is_instance_valid(target): continue
		seen[entry.handle] = true
		var auras: Dictionary = _auras.get(entry.handle, {})
		for id in entry.elements:
			if not auras.has(id) and style.status_scenes.has(id):
				var node: CPUParticles3D = style.status_scenes[id].instantiate()
				add_child(node)
				auras[id] = node
			if auras.has(id):
				var node: CPUParticles3D = auras[id]
				node.global_position = target.global_position + Vector3.UP * style.status_height_m
				node.scale = Vector3.ONE * (1.0 + style.status_scale_per_stack * (int(entry.elements[id]) - 1))
		for id in auras.keys():
			if not entry.elements.has(id):
				auras[id].queue_free()
				auras.erase(id)
		_auras[entry.handle] = auras
		_sync_mark(entry, target)
	for handle in _auras.keys():
		if not seen.has(handle): _drop_aura(handle)
	for node in get_children():
		if node is CPUParticles3D: node.speed_scale = 1.0 if _running else 0.0
	_tick(delta)

func _drop_aura(handle: int) -> void:
	if _marks.has(handle):
		_marks[handle].badge.queue_free()
		_marks[handle].ring.queue_free()
		_marks.erase(handle)
	if not _auras.has(handle): return
	for node in _auras[handle].values(): node.queue_free()
	_auras.erase(handle)

## 头顶“元素 ×层数”和脚下光环；没有元素时隐藏
func _sync_mark(entry: Dictionary, target) -> void:
	if not _marks.has(entry.handle):
		var badge := Label3D.new()
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.no_depth_test = true
		badge.pixel_size = 0.01
		badge.font_size = style.badge_font_size
		badge.outline_size = maxi(style.badge_font_size / 5, 1)
		badge.outline_modulate = style.badge_outline
		if _font != null: badge.font = _font
		add_child(badge)
		var ring := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * style.under_ring_radius_m * 2.0
		quad.orientation = PlaneMesh.FACE_Y
		ring.mesh = quad
		ring.material_override = style.under_ring_material.duplicate()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_marks[entry.handle] = {"badge": badge, "ring": ring}
	var mark: Dictionary = _marks[entry.handle]
	var parts: PackedStringArray = []
	var color := Color.WHITE
	var strength := 0.0
	for id in entry.elements:
		var stacks := int(entry.elements[id])
		var name := tr(_catalog.element(id).name_key) if _catalog != null and _catalog.has_element(id) else String(id)
		parts.append(name + (" ×%d" % stacks if stacks > 1 else ""))
		if parts.size() == 1:
			color = _element_color(id)
			strength = float(stacks) / float(_catalog.element(id).max_stacks) if _catalog != null and _catalog.has_element(id) else 1.0
	var shown := not parts.is_empty()
	mark.badge.visible = shown
	mark.ring.visible = shown
	if not shown: return
	mark.badge.text = "  ".join(parts)
	mark.badge.modulate = color.lerp(Color.WHITE, 0.15)
	var camera := get_viewport().get_camera_3d()
	var toward := Vector3.BACK
	if camera != null:
		toward = camera.global_position - target.global_position
		toward.y = 0.0
		toward = toward.normalized() if not toward.is_zero_approx() else Vector3.BACK
	mark.badge.global_position = target.global_position + Vector3.UP * style.badge_height_m + toward * style.badge_toward_camera_m
	mark.ring.global_position = target.global_position + Vector3.UP * 0.05
	mark.ring.material_override.set_shader_parameter("color", color)
	mark.ring.material_override.set_shader_parameter("strength", strength)

func _flash(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)
	light.global_position = at
	_transients.append([light, style.flash_sec, "light", style.flash_sec, energy])

func _element_color(id: String) -> Color:
	return style.element_colors.get(id, Color.WHITE)

func _burst(scene: PackedScene, at: Vector3, color: Color) -> CPUParticles3D:
	var node: CPUParticles3D = scene.instantiate()
	node.color = color
	add_child(node)
	node.global_position = at
	node.finished.connect(node.queue_free)
	node.restart()
	return node

func _reaction(fact: Dictionary, color: Color) -> void:
	var center: Vector3 = fact.position
	_burst(style.reaction_burst, center + Vector3.UP * style.burst_height_m, color)
	if style.smoke_reactions.has(fact.reaction_id):
		_burst(style.reaction_smoke, center + Vector3.UP * style.burst_height_m, color.lerp(Color.WHITE, 0.5))
	var radius: float = maxf(float(fact.radius), style.ring_min_radius_m)
	if bool(fact.pull):
		var pull := _burst(style.pull_burst, center + Vector3.UP * style.burst_height_m, color)
		pull.emission_ring_radius = radius
		pull.emission_ring_inner_radius = radius * 0.8
	# 贴地冲击波
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	var material: ShaderMaterial = style.ring_material.duplicate()
	material.set_shader_parameter("color", color)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = center + Vector3.UP * 0.06
	_transients.append([ring, style.ring_sec, "ring", style.ring_sec])
	# 闪光
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = style.flash_energy
	light.omni_range = style.flash_range_m
	add_child(light)
	light.global_position = center + Vector3.UP * 1.0
	_transients.append([light, style.flash_sec, "light", style.flash_sec, style.flash_energy])
	# 反应名
	var label := Label3D.new()
	label.text = tr(fact.name_key)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = style.label_font_size
	label.outline_size = maxi(style.label_font_size / 6, 1)
	label.modulate = color.lerp(Color.WHITE, 0.25)
	label.outline_modulate = style.label_outline
	if _font != null: label.font = _font
	add_child(label)
	var label_at := center + Vector3.UP * style.label_height_m
	label.global_position = label_at
	_transients.append([label, style.label_sec, "label", label_at])
	if int(fact.zone_id) >= 0: _start_zone(int(fact.zone_id), center, float(fact.zone_radius), float(fact.zone_sec))

func _start_zone(id: int, center: Vector3, radius: float, seconds: float) -> void:
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	disc.mesh = quad
	disc.material_override = style.zone_material.duplicate()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.global_position = center + Vector3.UP * 0.05
	var embers: CPUParticles3D = style.zone_embers.instantiate()
	embers.emission_ring_radius = radius
	add_child(embers)
	embers.global_position = center + Vector3.UP * 0.05
	_zones[id] = {"disc": disc, "embers": embers, "age": 0.0, "total": seconds}

func _end_zone(id: int) -> void:
	if not _zones.has(id): return
	var zone: Dictionary = _zones[id]
	zone.disc.queue_free()
	zone.embers.emitting = false
	_transients.append([zone.embers, zone.embers.lifetime, "linger", 0.0])
	_zones.erase(id)

func _arcs(points: PackedVector3Array, color: Color) -> void:
	if points.size() < 2: return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color.lerp(Color.WHITE, 0.4)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var lift := Vector3.UP * style.arc_height_m
	# 点列是 [中心, 目标1, 中心, 目标2, ...]：中心到每个目标画一道锯齿电弧
	for index in range(1, points.size(), 2):
		_bolt(mesh, points[0] + lift, points[index] + lift)
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_transients.append([node, style.arc_sec, "arc", style.arc_sec])
	_burst(style.apply_burst, points[0] + lift, color)

func _bolt(mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	var steps := maxi(2, int(length / style.arc_segment_m))
	var side := (to - from).cross(Vector3.UP).normalized() * style.arc_width_m * 0.5
	var previous := from
	for step in range(1, steps + 1):
		var t := float(step) / steps
		var point := from.lerp(to, t)
		if step < steps:
			point += Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * style.arc_jitter_m
		for vertex in [previous - side, previous + side, point + side, previous - side, point + side, point - side]:
			mesh.surface_add_vertex(vertex)
		previous = point

func _tick(delta: float) -> void:
	for zone in _zones.values():
		zone.age += delta
		var fade: float = clampf(minf(zone.age, zone.total - zone.age) / style.zone_fade_sec, 0.0, 1.0)
		zone.disc.material_override.set_shader_parameter("fade", fade)
	for index in range(_transients.size() - 1, -1, -1):
		var entry: Array = _transients[index]
		var node: Node3D = entry[0]
		if not is_instance_valid(node):
			_transients.remove_at(index)
			continue
		entry[1] -= delta
		var kind: String = entry[2]
		match kind:
			"ring":
				node.material_override.set_shader_parameter("progress", 1.0 - entry[1] / float(entry[3]))
			"light":
				node.light_energy = float(entry[4]) * maxf(entry[1] / float(entry[3]), 0.0)
			"label":
				var t: float = 1.0 - entry[1] / style.label_sec
				node.scale = Vector3.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - t * 6.0))
				node.global_position = entry[3] + Vector3.UP * style.label_rise_m * t
				node.modulate.a = 1.0 - smoothstep(0.65, 1.0, t)
				node.outline_modulate.a = node.modulate.a
			"arc":
				node.transparency = 1.0 - maxf(entry[1] / float(entry[3]), 0.0)
		if entry[1] <= 0.0:
			node.queue_free()
			_transients.remove_at(index)

func clear() -> void:
	for handle in _auras.keys(): _drop_aura(handle)
	for handle in _marks.keys():
		_marks[handle].badge.queue_free()
		_marks[handle].ring.queue_free()
	_marks.clear()
	for id in _zones.keys(): _end_zone(id)
	for entry in _transients:
		if is_instance_valid(entry[0]): entry[0].queue_free()
	_transients.clear()
	for node in get_children(): node.queue_free()
