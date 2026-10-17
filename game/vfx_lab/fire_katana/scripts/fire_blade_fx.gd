extends Node3D
## 刀身上的火：刀身升温发光、刀上的火光、蓄力时往刀上聚的火星、刀身持续冒火、挥砍时甩出的火星，
## 以及挥砍时沿刀弧补出来的火团（由 katana_rig 在每个补采样点调用 emit_arc，不靠粒子自己按帧发射，否则一帧一簇）。

@export var blade_mesh: MeshInstance3D
@export var light: OmniLight3D
@export var gather: GPUParticles3D
@export var flames: GPUParticles3D
@export var embers: GPUParticles3D
@export var arc_flames: GPUParticles3D
@export var light_energy_per_heat := 2.2
@export var flame_threshold := 0.3
@export var arc_flame_rise := 0.6
## 刀弧火团只从刀身靠外的这一段出（0 = 刀根，1 = 刀尖）
@export var arc_span := Vector2(0.35, 1.05)

var _heat := 0.0
var _blade_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	_blade_mat = blade_mesh.get_surface_override_material(0)
	gather.emitting = false
	flames.emitting = false
	embers.emitting = false
	arc_flames.emitting = false


func set_heat(h: float) -> void:
	_heat = h


func set_charging(on: bool) -> void:
	gather.emitting = on


func set_slashing(on: bool) -> void:
	embers.emitting = on


func emit_arc(base: Vector3, tip: Vector3, intensity: float) -> void:
	if randf() > clampf(intensity, 0.0, 1.0) * 0.8:
		return
	var p := base.lerp(tip, randf_range(arc_span.x, arc_span.y))
	var vel := Vector3(randf_range(-0.2, 0.2), arc_flame_rise * randf_range(0.5, 1.0), randf_range(-0.2, 0.2))
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
	arc_flames.emit_particle(Transform3D(Basis(), p), vel, Color.WHITE, Color.WHITE, flags)


func _process(delta: float) -> void:
	_t += delta
	_blade_mat.set_shader_parameter("heat", _heat)
	var flick := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 17.3)
	light.light_energy = _heat * light_energy_per_heat * flick
	var burning := _heat > flame_threshold
	if flames.emitting != burning:
		flames.emitting = burning
	flames.amount_ratio = clampf(_heat, 0.25, 1.0)
