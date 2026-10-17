extends Node3D
## 元素附魔通用部分（和游戏里的 fire_enchant.gd 同一套约定，以后接入游戏可以直接挂到 ActorView.blade 下）：
## 原点在刀身中点，刀尖朝 -Z，长度由 configure_blade 给出；tick(delta) 每帧在剑姿态更新后调用，delta 为 0 表示暂停。
## 子类实现 _setup()、_on_tick(delta)、_fill_row(at, k)（挥动时在上一帧到这一帧之间的每个插值姿态上铺一排）。

@export var reference_length := 0.71
@export var size_scale := 1.0
@export var point_count := 512
@export var blade_span := Vector2(0.06, 1.04)
## 补发间距 = 火团/雾团大小 × 这个系数
@export var fill_overlap := 0.6
@export var fill_max_rows := 24
@export var teleport_m := 3.0
## 用来算补发间距的粒子（取它的面片大小）
@export var fill_reference: GPUParticles3D

var power := 0.6          ## 0..1.5，蓄力/挥砍时升高（演示里由刀的热度驱动）
var _length := 1.0
var _scale := 1.0
var _prev := Transform3D.IDENTITY
var _has_prev := false
var _t := 0.0
var _points: ImageTexture


func configure_blade(length: float) -> void:
	_length = maxf(length, 0.1)
	_scale = _length / reference_length * size_scale
	_points = _make_points()
	for p in _particles():
		p.process_material = p.process_material.duplicate()
		if p.draw_pass_1 is QuadMesh:
			p.draw_pass_1 = p.draw_pass_1.duplicate()
			p.draw_pass_1.size *= _scale
		var pm: ParticleProcessMaterial = p.process_material
		pm.gravity *= _scale
		pm.initial_velocity_min *= _scale
		pm.initial_velocity_max *= _scale
	_setup()
	_has_prev = false


func set_power(p: float) -> void:
	power = p


func tick(delta: float) -> void:
	var speed := 1.0 if delta > 0.0 else 0.0
	for p in _particles():
		p.speed_scale = speed
	if delta <= 0.0:
		return
	_t += delta
	var xf := global_transform
	if _has_prev:
		_fill_between(_prev, xf, delta)
	_prev = xf
	_has_prev = true
	_on_tick(delta)


## 刀身上的点（本地坐标）。s：0 = 刀根，1 = 刀尖
func blade_point(s: float, jitter := 0.012) -> Vector3:
	var j := jitter * _length
	return Vector3(randf_range(-j, j), randf_range(-j, j), _length * (0.5 - s))


func random_s() -> float:
	return lerpf(blade_span.x, blade_span.y, sqrt(randf()))


## 把刀身发射点贴到粒子上（Points 发射形状）
func use_blade_points(p: GPUParticles3D) -> void:
	var pm: ParticleProcessMaterial = p.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _points
	pm.emission_point_count = point_count


## 放在世界原点、用 emit_particle 发射的粒子：可见范围盖住整个房间
func make_world_emitter(p: GPUParticles3D) -> void:
	p.top_level = true
	p.global_transform = Transform3D.IDENTITY
	p.visibility_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	p.emitting = false


func tip_travel(a: Transform3D, b: Transform3D) -> float:
	var tip := Vector3(0.0, 0.0, -_length * 0.5)
	return (a * tip).distance_to(b * tip)


func _make_points() -> ImageTexture:
	var img := Image.create(point_count, 1, false, Image.FORMAT_RGBF)
	for i in point_count:
		var p := blade_point(random_s())
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	return ImageTexture.create_from_image(img)


func _fill_between(a: Transform3D, b: Transform3D, delta: float) -> void:
	var travel := tip_travel(a, b)
	_on_motion(travel / delta, travel < teleport_m)
	if travel >= teleport_m or fill_reference == null:
		return
	var step: float = fill_reference.draw_pass_1.size.x * fill_overlap
	var rows := mini(ceili(travel / step), fill_max_rows)
	if rows <= 0:
		return
	var qa := a.basis.orthonormalized().get_rotation_quaternion()
	var qb := b.basis.orthonormalized().get_rotation_quaternion()
	for i in rows:
		var k := (i + randf()) / rows
		_fill_row(Transform3D(Basis(qa.slerp(qb, k)), a.origin.lerp(b.origin, k)), k, step)


## emit_particle 的自定义数据：x = 转角，y = 年龄(0)，z = 图集格，w = 寿命系数（不显式给的话颜色渐变不会走）
func emit_puff(p: GPUParticles3D, pos: Vector3, vel: Vector3) -> void:
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	p.emit_particle(Transform3D(Basis(), pos), vel, Color.WHITE, Color(randf() * TAU, 0.0, randf(), randf_range(0.6, 1.0)), flags)


# ---- 子类覆盖 ----
func _particles() -> Array[GPUParticles3D]:
	return []

func _setup() -> void:
	pass

func _on_tick(_delta: float) -> void:
	pass

func _on_motion(_speed: float, _valid: bool) -> void:
	pass

func _fill_row(_at: Transform3D, _k: float, _step: float) -> void:
	pass
