extends "res://vfx_lab/elemental_enchants/scripts/enchant_base.gd"
## 土元素附魔：刀身结一层岩壳、岩缝透出金光（材质覆盖层），小碎石悬浮着绕刀漂、细沙往下漏、带一点尘土；
## 挥刀时留下尘土拖尾，并甩出会落地弹跳的碎石块。土系不靠发光，靠实体和尘土。

@export var dust: GPUParticles3D         ## 刀身冒出的尘土（世界坐标）
@export var sand: GPUParticles3D         ## 往下漏的细沙（世界坐标）
@export var pebbles: GPUParticles3D      ## 绕刀悬浮的小碎石（局部坐标，跟着刀走）
@export var trail_dust: GPUParticles3D   ## 挥动时补发的尘土拖尾
@export var chips: GPUParticles3D        ## 挥动时甩出的碎石块
@export var light: OmniLight3D
@export var light_energy := 0.5
@export var chip_chance := 0.07
@export var chip_speed := Vector2(0.8, 2.2)


func _particles() -> Array[GPUParticles3D]:
	return [dust, sand, pebbles, trail_dust, chips]


func _setup() -> void:
	use_blade_points(dust)
	use_blade_points(sand)
	use_blade_points(pebbles)
	make_world_emitter(trail_dust)
	make_world_emitter(chips)
	light.omni_range *= _scale
	for p in [dust, sand, pebbles]:
		p.emitting = true


func _on_tick(_delta: float) -> void:
	dust.amount_ratio = clampf(0.3 + power * 0.5, 0.2, 1.0)
	sand.amount_ratio = clampf(0.4 + power * 0.5, 0.3, 1.0)
	light.light_energy = light_energy * (0.5 + 0.5 * power)


func _fill_row(at: Transform3D, _k: float, step: float) -> void:
	var per_row := maxi(ceili(_length * (blade_span.y - blade_span.x) / step), 1)
	for j in per_row:
		var s := lerpf(blade_span.x, blade_span.y, (j + randf()) / per_row)
		var pos := at * blade_point(s)
		emit_puff(trail_dust, pos, Vector3(randf_range(-0.15, 0.15), randf_range(-0.2, 0.1), randf_range(-0.15, 0.15)) * _scale)
		if randf() < chip_chance * clampf(power, 0.5, 1.5):
			_emit_chip(at, pos)


func _emit_chip(at: Transform3D, pos: Vector3) -> void:
	var axis_point := at * Vector3(0.0, 0.0, (at.affine_inverse() * pos).z)
	var out := pos - axis_point
	if out.length_squared() < 1e-6:
		out = Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1))
	var dir := (out.normalized() + Vector3(randf_range(-0.5, 0.5), randf_range(0.1, 0.6), randf_range(-0.5, 0.5))).normalized()
	var rot := Basis(Quaternion(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(), randf() * TAU))
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	chips.emit_particle(Transform3D(rot, pos), dir * randf_range(chip_speed.x, chip_speed.y) * _scale, Color.WHITE, Color(0.0, 0.0, randf(), randf_range(0.6, 1.0)), flags)
