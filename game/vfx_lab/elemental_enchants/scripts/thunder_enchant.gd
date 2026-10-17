extends "res://vfx_lab/elemental_enchants/scripts/enchant_base.gd"
## 雷元素附魔：刀身上电纹闪烁（材质覆盖层），小电弧不停在刀身上跳、偶尔跳到空中；
## 挥刀时沿刀扫过的扇面留下分叉的闪电残影，并甩出噼啪的电火花。

@export var strands: Node3D               ## lightning_strands.gd（世界坐标）
@export var aura: GPUParticles3D          ## 刀身周围淡淡的蓝紫电晕（世界坐标）
@export var trail_aura: GPUParticles3D    ## 挥动时补发的电晕
@export var sparks: GPUParticles3D        ## 噼啪电火花
@export var light: OmniLight3D
@export var light_energy := 1.6
## 刀身小电弧：每隔多久刷新一批、一批几条（随 power 增加）
@export var arc_interval := 0.04
@export var arcs_per_batch := Vector2(1.0, 4.0)
@export var arc_width := 0.01
## 挥动时每扫过多少米（剑尖）留一条闪电残影
@export var trail_bolt_spacing := 0.22
@export var trail_bolt_life := Vector2(0.1, 0.2)

var _arc_clock := 0.0
var _flash := 0.0


func _particles() -> Array[GPUParticles3D]:
	return [aura, trail_aura, sparks]


func _setup() -> void:
	use_blade_points(aura)
	use_blade_points(sparks)
	make_world_emitter(trail_aura)
	light.omni_range *= _scale
	aura.emitting = true
	sparks.emitting = true


func tick(delta: float) -> void:
	super.tick(delta)
	if delta > 0.0:
		strands.update(delta)


func _on_tick(delta: float) -> void:
	_arc_clock -= delta
	if _arc_clock <= 0.0:
		_arc_clock = arc_interval * randf_range(0.6, 1.4)
		_blade_arcs()
	sparks.amount_ratio = 1.0 if _fast else clampf(0.05 + power * 0.25, 0.05, 0.5)
	aura.amount_ratio = clampf(0.4 + power * 0.5, 0.3, 1.0)
	# 电光：底子随 power，偶尔一下强闪
	_flash = maxf(0.0, _flash - delta * 12.0)
	if randf() < delta * (3.0 + power * 6.0):
		_flash = randf_range(0.6, 1.2)
	light.light_energy = light_energy * (0.35 + 0.4 * power + _flash)


func _blade_arcs() -> void:
	var xf := global_transform
	var count := int(round(lerpf(arcs_per_batch.x, arcs_per_batch.y, clampf(power / 1.2, 0.0, 1.0))))
	for i in count:
		var s1 := random_s()
		var s2 := clampf(s1 + randf_range(-0.3, 0.3), blade_span.x, blade_span.y)
		var a := xf * blade_point(s1, 0.02)
		var b := xf * blade_point(s2, 0.02)
		strands.add_bolt(a, b, randf_range(0.04, 0.09), arc_width * _scale, 0.35, 0, 0.9)
	# 偶尔一条跳到空中的电弧
	if randf() < 0.25 + power * 0.3:
		var from := xf * blade_point(random_s(), 0.02)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		strands.add_bolt(from, from + dir * randf_range(0.12, 0.3) * _scale, randf_range(0.05, 0.1), arc_width * 0.8 * _scale, 0.3, 1, 0.8)


var _trail_travel := 0.0
var _trail_prev := Transform3D.IDENTITY
var _trail_has_prev := false


var _fast := false


func _on_motion(speed: float, valid: bool) -> void:
	_fast = valid and speed > 4.0


func _fill_row(at: Transform3D, _k: float, step: float) -> void:
	# 电晕：比火稀疏，一排只铺一半
	var per_row := maxi(ceili(_length * (blade_span.y - blade_span.x) / step * 0.5), 1)
	for j in per_row:
		var s := lerpf(blade_span.x, blade_span.y, (j + randf()) / per_row)
		emit_puff(trail_aura, at * blade_point(s), Vector3(randf_range(-0.1, 0.1), randf_range(0.0, 0.2), randf_range(-0.1, 0.1)) * _scale)
	# 闪电残影：剑尖每扫过一段，就在“上一段的位置”和“这里”之间连一条分叉闪电
	if not _trail_has_prev:
		_trail_prev = at
		_trail_has_prev = true
		return
	var tip := Vector3(0.0, 0.0, -_length * 0.5)
	_trail_travel += (_trail_prev * tip).distance_to(at * tip)
	if _trail_travel >= trail_bolt_spacing * _scale:
		_trail_travel = 0.0
		var s_a := randf_range(0.45, 1.0)
		var s_b := randf_range(0.45, 1.0)
		strands.add_bolt(_trail_prev * blade_point(s_a, 0.0), at * blade_point(s_b, 0.0),
			randf_range(trail_bolt_life.x, trail_bolt_life.y), arc_width * 1.4 * _scale, 0.28, randi_range(0, 2), 1.0)
		# 偶尔一条横跨刀身的
		if randf() < 0.4:
			strands.add_bolt(at * blade_point(0.2, 0.0), at * blade_point(1.0, 0.0), randf_range(0.06, 0.12), arc_width * _scale, 0.25, 1, 0.9)
		_trail_prev = at


func _fill_between(a: Transform3D, b: Transform3D, delta: float) -> void:
	if tip_travel(a, b) < 0.02 * _scale:
		_trail_has_prev = false     # 停下来了：下一次挥动重新起头
	super._fill_between(a, b, delta)
