extends "res://vfx_lab/elemental_enchants/scripts/enchant_base.gd"
## 冰元素附魔：刀身结霜（材质覆盖层，由演示/接入方挂到刀身材质的 next_pass），
## 寒气从刀上往下沉、细小冰晶闪烁；挥刀时留下一道寒雾，并甩出会落地弹跳的冰碴。

@export var mist: GPUParticles3D        ## 刀身持续冒出的寒气（世界坐标，挥动时自然甩在后面）
@export var glints: GPUParticles3D      ## 冰晶闪光
@export var trail_mist: GPUParticles3D  ## 挥动时补发的寒雾（世界原点 + emit_particle）
@export var shards: GPUParticles3D      ## 挥动时甩出的冰碴（三维小晶体）
@export var light: OmniLight3D
@export var light_energy := 0.6
## 每排寒雾里有多大比例的位置再甩一颗冰碴
@export var shard_chance := 0.05
@export var shard_speed := Vector2(0.6, 1.8)


func _particles() -> Array[GPUParticles3D]:
	return [mist, glints, trail_mist, shards]


func _setup() -> void:
	use_blade_points(mist)
	use_blade_points(glints)
	make_world_emitter(trail_mist)
	make_world_emitter(shards)
	light.omni_range *= _scale
	mist.emitting = true
	glints.emitting = true


func _on_tick(_delta: float) -> void:
	mist.amount_ratio = clampf(0.4 + power * 0.5, 0.3, 1.0)
	glints.amount_ratio = clampf(0.3 + power * 0.6, 0.2, 1.0)
	light.light_energy = light_energy * (0.6 + 0.4 * power)


func _fill_row(at: Transform3D, _k: float, step: float) -> void:
	var per_row := maxi(ceili(_length * (blade_span.y - blade_span.x) / step), 1)
	for j in per_row:
		var s := lerpf(blade_span.x, blade_span.y, (j + randf()) / per_row)
		var pos := at * blade_point(s)
		var vel := Vector3(randf_range(-0.15, 0.15), randf_range(-0.25, 0.05), randf_range(-0.15, 0.15)) * _scale
		emit_puff(trail_mist, pos, vel)
		if randf() < shard_chance * clampf(power, 0.5, 1.5):
			_emit_shard(at, pos)


func _emit_shard(at: Transform3D, pos: Vector3) -> void:
	# 从刀身往外甩：方向 = 离开刀身轴线 + 一点向上
	var axis_point := at * Vector3(0.0, 0.0, (at.affine_inverse() * pos).z)
	var out := (pos - axis_point)
	if out.length_squared() < 1e-6:
		out = Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1))
	var dir := (out.normalized() + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5))).normalized()
	var vel := dir * randf_range(shard_speed.x, shard_speed.y) * _scale
	var rot := Basis(Quaternion(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf() * TAU))
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	shards.emit_particle(Transform3D(rot, pos), vel, Color.WHITE, Color(0.0, 0.0, randf(), randf_range(0.6, 1.0)), flags)
