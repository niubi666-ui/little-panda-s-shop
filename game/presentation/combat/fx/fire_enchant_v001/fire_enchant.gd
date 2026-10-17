extends Node3D
## 火元素附魔：选了火元素后剑一直燃烧，挥动时火团留在身后形成拖尾（效果来自 vfx_lab/fire_katana）。
## 只读剑的姿态，不参与任何判定。挂在 ActorView.blade 下：原点在刀身中点，刀尖朝 -Z，长度由 configure_blade 给出。
##
## 三层：
## - Flames：几百个火团从刀身上的发射点持续冒出、向上飘、按寿命变色成烟（世界坐标，刀一动就甩在后面）。
## - ArcFlames：挥剑很快时一帧能扫过很大角度，按帧发射会断成一条条；这里按上一帧到这一帧之间的刀身姿态补发火团，拖尾连续。
## - Embers：剑尖速度够快时甩出火星。

@export var flames: GPUParticles3D
@export var arc_flames: GPUParticles3D
@export var embers: GPUParticles3D
@export var light: OmniLight3D
## 场景里粒子尺寸是按这把刀身长度调的（实验室太刀刀身）
@export var reference_length := 0.71
## 火团相对刀身的比例；1 = 和演示场景一样（用户确认过的密度）
@export var size_scale := 1.0
@export var point_count := 512
## 发射区间：0 = 刀根，1 = 刀尖（略超出刀尖，火焰包住刀尖）
@export var blade_span := Vector2(0.06, 1.04)
## 补发火团的间距 = 火团大小 × 这个系数（越小越密；按火团大小算，换刀长、换缩放都保持同样的重叠）
@export var arc_overlap := 0.5
@export var arc_max_per_frame := 160
## 一帧内剑尖移动超过这个距离视为瞬移（换姿态、复活），不补发
@export var teleport_m := 3.0
## 剑尖速度超过这个值（米/秒）才甩火星
@export var ember_speed := 5.0
@export var light_energy := 1.4

var _length := 1.0
var _scale := 1.0
var _prev := Transform3D.IDENTITY
var _has_prev := false
var _t := 0.0
## 累计补发的火团数（测试用）
var arc_emitted := 0


func _ready() -> void:
	assert(flames != null and arc_flames != null and embers != null and light != null)


## ActorView.set_weapon_enchant 调用：按实际刀身长度生成发射点、缩放火团
func configure_blade(length: float) -> void:
	_length = maxf(length, 0.1)
	_scale = _length / reference_length * size_scale
	var points := _blade_points()
	for p: GPUParticles3D in [flames, arc_flames, embers]:
		p.process_material = p.process_material.duplicate()
		p.draw_pass_1 = p.draw_pass_1.duplicate()
		p.draw_pass_1.size *= _scale
		var pm: ParticleProcessMaterial = p.process_material
		pm.gravity *= _scale
		pm.initial_velocity_min *= _scale
		pm.initial_velocity_max *= _scale
	for p: GPUParticles3D in [flames, embers]:
		var pm: ParticleProcessMaterial = p.process_material
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		pm.emission_point_texture = points
		pm.emission_point_count = point_count
	light.omni_range *= _scale
	arc_flames.top_level = true
	arc_flames.global_transform = Transform3D.IDENTITY
	# 这个发射器放在世界原点、火团在世界坐标里：可见范围要盖住整个房间，否则主角走远就整片被裁掉
	arc_flames.visibility_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	flames.emitting = true
	embers.emitting = false
	arc_flames.emitting = false
	_has_prev = false


## ActorView.refresh 每帧调用（剑姿态已经更新之后）；delta 为 0 表示暂停，所有粒子冻结
func tick(delta: float) -> void:
	var speed := 1.0 if delta > 0.0 else 0.0
	for p: GPUParticles3D in [flames, arc_flames, embers]:
		p.speed_scale = speed
	if delta <= 0.0:
		return
	_t += delta
	var xf := global_transform
	if _has_prev:
		_fill_between(_prev, xf, delta)
	_prev = xf
	_has_prev = true
	var flick := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 17.3)
	light.light_energy = light_energy * flick


func _blade_point(s: float) -> Vector3:
	# s：0 = 刀根，1 = 刀尖；刀尖在 -Z
	var jitter := 0.012 * _length
	return Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), _length * (0.5 - s))


func _blade_points() -> ImageTexture:
	var img := Image.create(point_count, 1, false, Image.FORMAT_RGBF)
	for i in point_count:
		# 越靠刀尖越密一点
		var s := lerpf(blade_span.x, blade_span.y, sqrt(randf()))
		var p := _blade_point(s)
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	return ImageTexture.create_from_image(img)


func _fill_between(a: Transform3D, b: Transform3D, delta: float) -> void:
	var tip := Vector3(0.0, 0.0, -_length * 0.5)
	var travel := (a * tip).distance_to(b * tip)
	embers.emitting = travel / delta > ember_speed and travel < teleport_m
	if travel >= teleport_m:
		return
	# 刀扫过的是一个扇面：沿剑尖轨迹分若干步，每一步沿整条刀身均匀铺一排火团，扇面才铺满不留空洞
	var step: float = arc_flames.draw_pass_1.size.x * arc_overlap
	var steps := maxi(ceili(travel / step), 0)
	if steps <= 0:
		return
	var per_row := maxi(ceili(_length * (blade_span.y - blade_span.x) / step), 1)
	if steps * per_row > arc_max_per_frame:
		per_row = maxi(arc_max_per_frame / steps, 1)
		steps = mini(steps, arc_max_per_frame)
	var qa := a.basis.orthonormalized().get_rotation_quaternion()
	var qb := b.basis.orthonormalized().get_rotation_quaternion()
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	for i in steps:
		var k := (i + randf()) / steps
		var at := Transform3D(Basis(qa.slerp(qb, k)), a.origin.lerp(b.origin, k))
		for j in per_row:
			var s := lerpf(blade_span.x, blade_span.y, (j + randf()) / per_row)
			var pos := at * _blade_point(s)
			var vel := Vector3(randf_range(-0.25, 0.25), randf_range(0.3, 0.8), randf_range(-0.25, 0.25)) * _scale
			# 自定义数据：x = 转角，y = 年龄(0)，z = 图集格，w = 寿命系数（不显式给的话颜色渐变不会走）
			var custom := Color(randf() * TAU, 0.0, randf(), randf_range(0.6, 1.0))
			arc_flames.emit_particle(Transform3D(Basis(), pos), vel, Color.WHITE, custom, flags)
			arc_emitted += 1
