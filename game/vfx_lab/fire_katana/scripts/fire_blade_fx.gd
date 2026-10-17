extends Node3D
## 刀身上的火：刀身附魔火层和升温、刀上的火光、蓄力时往刀上聚的火星、刀身持续燃烧的火团，
## 挥砍时额外加大火团量（ArcFlames）和甩出的火星。火团都在世界坐标里，挥刀时自然甩在后面成拖尾。
## 演示切到冰/雷时 set_enabled(false)：火的粒子和火光全关，但刀身覆盖层（next_pass）仍收到热度，当作冰/雷的强度。

@export var blade_mesh: MeshInstance3D
@export var light: OmniLight3D
@export var gather: GPUParticles3D
@export var flames: GPUParticles3D
@export var embers: GPUParticles3D
@export var arc_flames: GPUParticles3D
@export var light_energy_per_heat := 2.2
@export var flame_threshold := 0.3
## 刀弧火团从刀身这一段出（0 = 刀根，1 = 刀尖）
@export var arc_span := Vector2(0.35, 1.05)
@export var arc_puffs_per_sample := 4.0

var _heat := 0.0
var _blade_mat: ShaderMaterial
var _t := 0.0
var _enabled := true


func _ready() -> void:
	_blade_mat = blade_mesh.get_surface_override_material(0)
	gather.emitting = false
	flames.emitting = false
	embers.emitting = false
	arc_flames.emitting = false


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		gather.emitting = false
		flames.emitting = false
		embers.emitting = false
		light.light_energy = 0.0


func set_heat(h: float) -> void:
	_heat = h


func set_charging(on: bool) -> void:
	gather.emitting = on and _enabled


func set_slashing(on: bool) -> void:
	embers.emitting = on and _enabled


## 挥砍最快时一帧能转几十度，按帧发射会断成一条条；由 katana_rig 在每个补采样点调用，补出连续的火团拖尾。
## 自定义数据要显式给：x = 转角，y = 年龄(0)，z = 图集格，w = 寿命系数，否则颜色渐变不会走。
func emit_arc(base: Vector3, tip: Vector3, intensity: float) -> void:
	if not _enabled:
		return
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	for i in int(round(arc_puffs_per_sample * intensity)):
		var p := base.lerp(tip, randf_range(arc_span.x, arc_span.y))
		var vel := Vector3(randf_range(-0.25, 0.25), randf_range(0.3, 0.8), randf_range(-0.25, 0.25))
		var custom := Color(randf() * TAU, 0.0, randf(), randf_range(0.6, 1.0))
		arc_flames.emit_particle(Transform3D(Basis(), p), vel, Color.WHITE, custom, flags)


func _process(delta: float) -> void:
	_t += delta
	_blade_mat.set_shader_parameter("heat", _heat if _enabled else 0.0)
	if _blade_mat.next_pass:
		_blade_mat.next_pass.set_shader_parameter("heat", _heat)
	if not _enabled:
		return
	var flick := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 17.3)
	light.light_energy = _heat * light_energy_per_heat * flick
	var burning := _heat > flame_threshold
	if flames.emitting != burning:
		flames.emitting = burning
	flames.amount_ratio = clampf(_heat, 0.45, 1.0)
