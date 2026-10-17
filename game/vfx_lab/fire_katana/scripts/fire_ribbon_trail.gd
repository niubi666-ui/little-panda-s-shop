extends Node3D
## 刀光拖尾带：记录刀根/刀尖在世界里的轨迹，每帧重建一条带子。
## 子节点里的 MeshInstance3D 共用这条网格，各自用不同材质（烟 / 火 / 白热线）。
## 挥砍很快（一帧转十几度），所以由 katana_rig 在一帧内按解析姿态补采样，带子才是圆弧不是折线。

@export var max_age := 0.7
@export var across_segments := 6
@export var tip_extend := 0.08

var _samples: Array = []   # [base, tip, birth_time, intensity]
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for child in get_children():
		if child is MeshInstance3D:
			child.mesh = _mesh
			child.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_sample(base: Vector3, tip: Vector3, time: float, intensity: float) -> void:
	_samples.append([base, tip, time, intensity])


func break_strip() -> void:
	# 两次挥砍之间断开，避免把上一刀的尾巴和下一刀连起来
	if not _samples.is_empty():
		_samples.append(null)


func update_mesh(now: float) -> void:
	while not _samples.is_empty() and (_samples[0] == null or now - _samples[0][2] > max_age):
		_samples.pop_front()
	_mesh.clear_surfaces()
	var strips: Array = [[]]
	for s in _samples:
		if s == null:
			strips.append([])
		else:
			strips[-1].append(s)
	var began := false
	for strip in strips:
		if strip.size() < 2:
			continue
		if not began:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			began = true
		for i in strip.size() - 1:
			_add_quad_row(strip[i], strip[i + 1], now)
	if began:
		_mesh.surface_end()


func _row_point(s: Array, k: float) -> Vector3:
	var base: Vector3 = s[0]
	var tip: Vector3 = s[1]
	var ext := tip + (tip - base).normalized() * tip_extend
	return base.lerp(ext, k)


func _add_quad_row(a: Array, b: Array, now: float) -> void:
	for j in across_segments:
		var k0 := float(j) / across_segments
		var k1 := float(j + 1) / across_segments
		var verts := [
			[a, k0], [a, k1], [b, k1],
			[a, k0], [b, k1], [b, k0],
		]
		for v in verts:
			var s: Array = v[0]
			_mesh.surface_set_uv(Vector2(now - s[2], v[1]))
			_mesh.surface_set_uv2(Vector2(s[2], s[3]))
			_mesh.surface_add_vertex(_row_point(s, v[1]))
