extends Node3D
## 打击表现（纯表现，不影响判定）：
##  - 出刀：玩家技能到达判定点（cue）时，按出招方向扫出一道白色月牙（刺击是一道直线）；带元素时内缘染元素色
##  - 命中：命中点迸出几道白色尖刺
##  - 重击/第三段/击杀：再炸开一团带尖角的灰白爆团
## 按战斗时间推进：顿帧时也一起停住。形状与数值在 strike_style.tres。
const Style = preload("res://presentation/combat/strike/strike_style.gd")
const Arc = preload("res://presentation/combat/strike/strike_arc.gd")

var style: Style
var player
## [{node, material, kind, age, arc}]
var _items: Array = []
var _meshes: Dictionary = {}
var _seed := 0.0

func configure(settings: Style, owner_player) -> void:
	assert(settings != null and settings.arc_material != null and settings.star_material != null and settings.burst_material != null and settings.element_style != null, "strike style incomplete")
	for id in settings.arcs:
		var arc: Arc = settings.arcs[id]
		assert(arc.kind in ["arc", "thrust"] and arc.radius_m > arc.thickness_m and arc.segments >= 2 and arc.reveal_sec > 0.0 and arc.fade_sec > 0.0, "invalid strike arc " + str(id))
	style = settings
	player = owner_player
	player.runner.cue_reached.connect(_on_cue)

func _on_cue(_cast_id: int, ability_id: String) -> void:
	if not style.arcs.has(ability_id) or not is_instance_valid(player): return
	var arc: Arc = style.arcs[ability_id]
	var node := MeshInstance3D.new()
	node.mesh = _mesh(arc)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = style.arc_material.duplicate()
	material.set_shader_parameter("thrust", 1.0 if arc.kind == "thrust" else 0.0)
	material.set_shader_parameter("reveal", 0.0)
	material.set_shader_parameter("fade", 0.0)
	material.set_shader_parameter("seed", _next_seed())
	var element := _cast_element()
	if not element.is_empty() and style.element_style.element_colors.has(element):
		material.set_shader_parameter("tint_color", style.element_style.element_colors[element])
		material.set_shader_parameter("tint_amount", style.element_tint)
	node.material_override = material
	add_child(node)
	var direction: Vector3 = player.runner.direction
	node.global_position = player.global_position + Vector3.UP * arc.height_m
	node.rotation.y = atan2(-direction.x, -direction.z)
	_items.append({"node": node, "material": material, "kind": "arc", "age": 0.0, "arc": arc})

## 玩家命中敌人（只读已确认的命中）
func hit(ability_id: String, target, killed: bool) -> void:
	if not is_instance_valid(target): return
	var at: Vector3 = target.global_position + Vector3.UP * style.star_height_m
	_spawn_quad(style.star_material, style.star_size_m, at, "star")
	if killed or style.burst_abilities.has(ability_id):
		_spawn_quad(style.burst_material, style.kill_burst_size_m if killed else style.burst_size_m, at, "burst")

func _spawn_quad(source: ShaderMaterial, size: float, at: Vector3, kind: String) -> void:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = source.duplicate()
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("seed", _next_seed())
	node.material_override = material
	add_child(node)
	node.global_position = at
	_items.append({"node": node, "material": material, "kind": kind, "age": 0.0})

## delta 为战斗时间（顿帧时被压缩、暂停为 0）
func tick(delta: float) -> void:
	for index in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[index]
		item.age = float(item.age) + delta
		var done := false
		match String(item.kind):
			"arc":
				var arc: Arc = item.arc
				item.material.set_shader_parameter("reveal", clampf(item.age / arc.reveal_sec, 0.0, 1.0))
				var fade := (float(item.age) - arc.reveal_sec - arc.hold_sec) / arc.fade_sec
				item.material.set_shader_parameter("fade", clampf(fade, 0.0, 1.0))
				done = fade >= 1.0
			"star":
				item.material.set_shader_parameter("progress", clampf(item.age / style.star_sec, 0.0, 1.0))
				done = item.age >= style.star_sec
			"burst":
				item.material.set_shader_parameter("progress", clampf(item.age / style.burst_sec, 0.0, 1.0))
				done = item.age >= style.burst_sec
		if done:
			item.node.queue_free()
			_items.remove_at(index)

func clear() -> void:
	for item in _items: item.node.queue_free()
	_items.clear()

func _cast_element() -> String:
	if not player.runner.busy(): return ""
	for effect in player.runner.cast_context.get("effects", []):
		if effect.type == "element": return String(effect.params.element_id)
	return ""

func _next_seed() -> float:
	_seed = fmod(_seed + 7.31, 97.0)
	return _seed

## 月牙：沿刀路 segments 段，UV.x 沿刀路、UV.y 内缘 0 → 外缘 1；刺击：从身前向前的一条带，UV.y 横向 0 → 1
func _mesh(arc: Arc) -> ArrayMesh:
	if _meshes.has(arc): return _meshes[arc]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in arc.segments + 1:
		var t := float(i) / arc.segments
		var inner: Vector3
		var outer: Vector3
		if arc.kind == "arc":
			var angle := deg_to_rad(lerpf(arc.start_deg, arc.end_deg, t))
			var forward := Vector3(-sin(angle), 0.0, -cos(angle))
			inner = forward * (arc.radius_m - arc.thickness_m)
			outer = forward * arc.radius_m
		else:
			var z := -lerpf(arc.thickness_m * 0.5, arc.radius_m, t)
			inner = Vector3(-arc.thickness_m * 0.5, 0.0, z)
			outer = Vector3(arc.thickness_m * 0.5, 0.0, z)
		rows.append([inner, outer, t])
	for i in arc.segments:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for vertex in [[a[0], a[2], 0.0], [a[1], a[2], 1.0], [b[1], b[2], 1.0], [a[0], a[2], 0.0], [b[1], b[2], 1.0], [b[0], b[2], 0.0]]:
			tool.set_uv(Vector2(vertex[1], vertex[2]))
			tool.add_vertex(vertex[0])
	var mesh := tool.commit()
	_meshes[arc] = mesh
	return mesh
