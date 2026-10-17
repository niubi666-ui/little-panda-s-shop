extends Node3D
## 闪电线条渲染：每条闪电是一串折线点（中点位移法生成），每帧建成面向镜头的带子。
## 两层：宽而暗的辉光 + 细而亮的白芯。闪电寿命很短（几十毫秒），活着时也在闪烁。
## 节点放在世界原点（top_level），所有点都用世界坐标。

@export var glow_material: Material
@export var core_material: Material
@export var glow_width_scale := 5.0

var _bolts: Array = []   # {pts, age, life, width, power}
var _mesh := ImmediateMesh.new()
var _mi: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.randomize()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	add_child(_mi)


func clear() -> void:
	_bolts.clear()


func bolt_count() -> int:
	return _bolts.size()


## 加一条从 a 到 b 的闪电。jag：弯折程度（相对长度），branches：分叉数
func add_bolt(a: Vector3, b: Vector3, life: float, width: float, jag := 0.22, branches := 0, power := 1.0, depth := 5) -> void:
	var pts := make_path(a, b, jag, depth)
	_bolts.append({"pts": pts, "age": 0.0, "life": life, "width": width, "power": power})
	for i in branches:
		if pts.size() < 4:
			break
		var from: Vector3 = pts[_rng.randi_range(1, pts.size() - 2)]
		var dir := (b - a)
		var side := _random_perpendicular(dir.normalized())
		var to := from + (dir * _rng.randf_range(0.25, 0.5)) + side * dir.length() * _rng.randf_range(0.15, 0.35)
		_bolts.append({"pts": make_path(from, to, jag * 1.2, depth - 1), "age": 0.0, "life": life * 0.8,
			"width": width * 0.55, "power": power * 0.7})


func make_path(a: Vector3, b: Vector3, jag: float, depth: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var disp := a.distance_to(b) * jag
	for level in depth:
		var next := PackedVector3Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var d := q - p
			var mid := (p + q) * 0.5
			if d.length_squared() > 1e-10:
				mid += _random_perpendicular(d.normalized()) * _rng.randf_range(-disp, disp)
			next.append(p)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		disp *= 0.55
	return pts


func _random_perpendicular(d: Vector3) -> Vector3:
	var r := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	r -= d * r.dot(d)
	return r.normalized() if r.length_squared() > 1e-8 else Vector3.UP


func update(delta: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i].age += delta
		if _bolts[i].age >= _bolts[i].life:
			_bolts.remove_at(i)
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _bolts.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	for pass_i in 2:
		var wide := pass_i == 0
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for bolt in _bolts:
			var k: float = 1.0 - bolt.age / bolt.life
			var alpha: float = k * k * bolt.power * _rng.randf_range(0.65, 1.0)
			var w: float = bolt.width * (glow_width_scale if wide else 1.0)
			_strip(bolt.pts, w, alpha, eye)
		_mesh.surface_end()
		_mesh.surface_set_material(pass_i, glow_material if wide else core_material)


func _strip(pts: PackedVector3Array, width: float, alpha: float, eye: Vector3) -> void:
	var n := pts.size()
	if n < 2:
		return
	var sides := PackedVector3Array()
	sides.resize(n)
	for i in n:
		var d := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var view := (eye - pts[i]).normalized()
		var s := d.cross(view)
		sides[i] = s.normalized() * width * 0.5 if s.length_squared() > 1e-12 else Vector3.ZERO
	for i in n - 1:
		var u0 := float(i) / (n - 1)
		var u1 := float(i + 1) / (n - 1)
		# 两端收尖
		var t0 := sin(PI * clampf(u0, 0.0, 1.0)) * 0.7 + 0.3
		var t1 := sin(PI * clampf(u1, 0.0, 1.0)) * 0.7 + 0.3
		var a0 := pts[i] - sides[i] * t0
		var b0 := pts[i] + sides[i] * t0
		var a1 := pts[i + 1] - sides[i + 1] * t1
		var b1 := pts[i + 1] + sides[i + 1] * t1
		var c := Color(1, 1, 1, alpha)
		for v in [[a0, Vector2(u0, 0)], [b0, Vector2(u0, 1)], [b1, Vector2(u1, 1)], [a0, Vector2(u0, 0)], [b1, Vector2(u1, 1)], [a1, Vector2(u1, 0)]]:
			_mesh.surface_set_color(c)
			_mesh.surface_set_uv(v[1])
			_mesh.surface_add_vertex(v[0])
