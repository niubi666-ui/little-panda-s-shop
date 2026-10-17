extends Node3D
## 冰受击：从命中点冒出一簇冰刺（几帧内长出，略微回弹），停一会儿后碎掉（碎片由时间表里的 Shatter 粒子接上）。
## 受击特效的本地坐标：X = 刀的运动方向，Y = 刀身方向（指向目标里面），-Y = 朝外。

@export var spike_mesh: Mesh
@export var spike_material: Material
@export var count := 9
@export var length_range := Vector2(0.22, 0.5)
@export var radius_range := Vector2(0.05, 0.09)
@export var grow_time := 0.08
@export var hold_time := 0.5
@export var break_time := 0.06

var _spikes: Array = []   # [node, full_scale]
var _t := -1.0


func play() -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = spike_mesh
		mi.material_override = spike_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		# 方向：主要朝外（-Y），往刀的运动方向和上方张开；在世界里再偏一点向上
		var dir := (Vector3(0, -1, 0) * 0.7 + Vector3(randf_range(-0.9, 1.1), 0.0, randf_range(-0.8, 0.8))).normalized()
		var world_dir := (global_basis.orthonormalized() * dir + Vector3.UP * randf_range(0.0, 0.5)).normalized()
		dir = (global_basis.orthonormalized().inverse() * world_dir).normalized()
		var y := dir
		var x := y.cross(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))).normalized()
		var z := x.cross(y)
		var length := randf_range(length_range.x, length_range.y) * (1.0 if i > 1 else 1.25)
		var radius := randf_range(radius_range.x, radius_range.y)
		mi.basis = Basis(x, y, z)
		mi.position = -y * length * 0.12
		var full := Vector3(radius, length, radius)
		_spikes.append([mi, full])
		mi.scale = Vector3(radius, 0.001, radius)
	_t = 0.0


func tick(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var grow := clampf(_t / grow_time, 0.0, 1.0)
	# ease-out-back：长出来时冲过一点再回落
	var g := 1.0 + 2.2 * pow(grow - 1.0, 3.0) + 1.2 * pow(grow - 1.0, 2.0)
	var breaking := clampf((_t - grow_time - hold_time) / break_time, 0.0, 1.0)
	for s in _spikes:
		var full: Vector3 = s[1]
		var k := g * (1.0 - breaking)
		s[0].scale = Vector3(full.x * (1.0 - breaking * 0.6), maxf(full.y * k, 0.001), full.z * (1.0 - breaking * 0.6))
	if breaking >= 1.0:
		for s in _spikes:
			s[0].queue_free()
		_spikes.clear()
		_t = -1.0
