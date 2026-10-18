extends Node3D
## 土受击：一排岩刺沿刀的挥砍方向从地里依次顶出来（地刺课程的做法：实体 + 动画 + 裂纹 + 碎石 + 尘），
## 停一会儿再缩回地下。play() 时先把自己摆到命中点正下方的地面上（命中点往下 ground_drop 米）。
## 游戏版：由受击播放器（vfx_sequence_player）每帧调用 tick，跟战斗时钟走（暂停、顿帧一起停）；
## 播放器把根节点 Y 轴摆成攻击方向，所以岩刺默认沿 Y（攻击方向）往目标后方排开。
## 子节点里的 GPUParticles3D（地面尘圈、地面碎石）和带 play() 的节点（裂纹贴花）跟着一起触发。

@export var spike_mesh: Mesh
@export var spike_material: Material
@export var ground_drop := 0.75        ## 命中点比地面高多少（= build_effects_style.element_impact_height）
@export var line_along_y := true       ## true：沿根节点 Y（攻击方向）排；false：沿 X（演示里的挥砍方向）
@export var count := 6
@export var start_offset := 0.32       ## 第一根离命中点多远（米，沿挥砍方向），别插进目标里
@export var spacing := 0.3
@export var height_range := Vector2(0.55, 1.05)
@export var radius_range := Vector2(0.12, 0.19)
@export var stagger := 0.045           ## 一根接一根冒出的间隔
@export var rise_time := 0.09
@export var hold_time := 0.9
@export var sink_time := 0.35
## 挥砍方向在水平面上的分量小于这个值就改成围一圈
@export var ring_threshold := 0.5
@export var ring_radius := 0.38
@export var ring_center_offset := 0.11   ## 命中点在目标表面，圈心要往里挪到目标中心

var _spikes: Array = []   # [node, height, delay]
var _t := -1.0


func play() -> void:
	var at := global_position
	var forward := (global_basis.y if line_along_y else global_basis.x).normalized()
	var into := global_basis.y.normalized()     # 刀身方向（指向目标里面）
	forward.y = 0.0
	into.y = 0.0
	# 横向挥砍：岩刺沿挥砍方向排成一排；竖劈（挥砍方向几乎垂直）：围着目标冒一圈
	var ring := forward.length() < ring_threshold
	if ring:
		forward = into.normalized() if into.length_squared() > 1e-6 else Vector3.FORWARD
	else:
		forward = forward.normalized()
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), Vector3(at.x, at.y - ground_drop, at.z))
	for c in get_children():
		if c.has_method("play"):
			c.play()
		elif c is GPUParticles3D:
			c.restart()
			c.emitting = true
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = spike_mesh
		mi.material_override = spike_material
		add_child(mi)
		# 中间几根最高，两头矮；左右错开一点，向外倾
		var k := float(i) / maxf(count - 1, 1)
		var h := lerpf(height_range.x, height_range.y, sin(PI * (0.25 + 0.6 * k))) * randf_range(0.85, 1.15)
		var r := randf_range(radius_range.x, radius_range.y) * (0.8 + 0.4 * sin(PI * k))
		var side := randf_range(-0.12, 0.12)
		var tilt: Basis
		if ring:
			# 圈心在目标中心（命中点往里 ring_center_offset），岩刺向外倾
			var a := TAU * (float(i) + randf_range(-0.2, 0.2)) / count
			var out := Vector3(sin(a), 0.0, -cos(a))
			var center := Vector3(0.0, 0.0, -ring_center_offset)
			mi.position = center + out * ring_radius * randf_range(0.9, 1.15) + Vector3(0, -h, 0)
			tilt = Basis(out.cross(Vector3.UP).normalized(), -randf_range(0.25, 0.45)) * Basis(Vector3.UP, randf() * TAU)
		else:
			mi.position = Vector3(side, -h, -(start_offset + spacing * i))   # 本地 -Z = 挥砍方向
			tilt = Basis(Vector3.FORWARD, -side * 1.8) * Basis(Vector3.RIGHT, -randf_range(0.1, 0.35)) * Basis(Vector3.UP, randf() * TAU)
		mi.basis = tilt * Basis.from_scale(Vector3(r, h, r))
		_spikes.append([mi, h, stagger * i, mi.position])
	_t = 0.0


func tick(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var done := true
	for s in _spikes:
		var local_t: float = _t - s[2]
		var rise := clampf(local_t / rise_time, 0.0, 1.0)
		var e := 1.0 + 2.4 * pow(rise - 1.0, 3.0) + 1.4 * pow(rise - 1.0, 2.0)   # 冲出地面再回落一点
		var sink := clampf((local_t - rise_time - hold_time) / sink_time, 0.0, 1.0)
		var up: float = s[1] * (e - sink * sink)
		var p: Vector3 = s[3]
		s[0].position = Vector3(p.x, -s[1] + up, p.z)
		if sink < 1.0:
			done = false
	if done:
		for s in _spikes:
			s[0].queue_free()
		_spikes.clear()
		_t = -1.0
