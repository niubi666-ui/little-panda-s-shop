extends Node3D
## 冰冻表现：贴合敌人体型的冰封。attach(visual) 绑定一个敌人表现节点（含 Skeleton3D 和蒙皮网格），
## freeze() 冰从脚往上封住全身，release() 冰壳碎掉。tick(delta) 每帧调用（delta 为 0 表示暂停，全部冻结）。
## 只读模型和骨骼，不参与判定。
##
## 贴合体型的做法：
## - 冰壳：给敌人自己的每个 MeshInstance3D 挂 material_overlay（ice_shell.gdshader），顶点沿法线外推，轮廓完全一致、跟着骨骼。
## - 冰晶：在身体网格表面按面积随机取点（只取朝上/朝外的点），每个点挂到驱动它的骨骼上（BoneAttachment3D），
##   冰晶数量和大小按身高、体宽缩放。
## - 脚下：一圈冰刺 + 地面霜花 + 往下沉的寒气，尺寸按体宽。体型取当前姿势下骨骼的包围范围。

@export var shell_material: ShaderMaterial
@export var crystal_mesh: Mesh
@export var crystal_material: Material
@export var mist: GPUParticles3D
@export var glitter: GPUParticles3D
@export var shards: GPUParticles3D        ## 世界原点 + emit_particle：碎裂时的冰碴
@export var burst_mist: GPUParticles3D    ## 碎裂时的一团寒雾
@export var frost_decal: Decal
@export var freeze_time := 0.35
@export var shatter_time := 0.3
@export var shell_thickness_ratio := 0.022    ## 冰壳厚度 = 身高 × 这个比例
@export var crystal_density := 22.0           ## 每平方米“身体侧面积”（身高 × 体宽）的冰晶数
@export var crystal_count_range := Vector2i(6, 26)
@export var crystal_length_ratio := Vector2(0.1, 0.22)   ## 冰晶长度 = 身高 × 区间
@export var base_spike_count_per_m := 9.0     ## 脚下冰刺：每米周长几根
@export var base_height_ratio := Vector2(0.14, 0.32)
@export var tint := Color(0.6, 0.85, 1.0)

var state := "idle"           ## idle / freezing / frozen / shattering
var _visual: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _old_overlays: Array = []
var _shell: ShaderMaterial
var _crystals: Array = []     # [mesh_instance, full_transform, height_frac, attachment]
var _base: Array = []         # [mesh_instance, full_transform]
var _base_root: Node3D
var _t := 0.0
var _phase_t := 0.0
var _ground_y := 0.0
var _height := 1.0
var _radius := 0.4
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	shards.top_level = true
	shards.global_transform = Transform3D.IDENTITY
	shards.visibility_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	shards.emitting = false
	mist.emitting = false
	glitter.emitting = false
	frost_decal.visible = false


func attach(visual: Node3D) -> void:
	_visual = visual
	_skeleton = visual.find_child("Skeleton3D", true, false)
	_meshes.clear()
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)


func is_frozen() -> bool:
	return state == "freezing" or state == "frozen"


func freeze() -> void:
	if _visual == null or is_frozen():
		return
	_clear_ice()
	_measure()
	global_position = Vector3(_visual.global_position.x, _ground_y, _visual.global_position.z)
	_shell = shell_material.duplicate()
	_shell.set_shader_parameter("ground_y", _ground_y)
	_shell.set_shader_parameter("body_height", _height)
	_shell.set_shader_parameter("thickness", _height * shell_thickness_ratio)
	_shell.set_shader_parameter("progress", 0.0)
	_shell.set_shader_parameter("shatter", 0.0)
	_old_overlays.clear()
	for m in _meshes:
		_old_overlays.append(m.material_overlay)
		m.material_overlay = _shell
	_grow_crystals()
	_grow_base()
	# 寒气、闪光、霜花按体型摆
	var pm: ParticleProcessMaterial = mist.process_material
	pm.emission_box_extents = Vector3(_radius, _height * 0.45, _radius)
	mist.position = Vector3(0, _height * 0.5, 0)
	(glitter.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(_radius * 0.8, _height * 0.45, _radius * 0.8)
	glitter.position = mist.position
	mist.emitting = true
	glitter.emitting = true
	frost_decal.size = Vector3(_radius * 3.0, 1.0, _radius * 3.0)
	frost_decal.modulate.a = 0.0
	frost_decal.visible = true
	state = "freezing"
	_phase_t = 0.0


func release() -> void:
	if not is_frozen():
		return
	state = "shattering"
	_phase_t = 0.0
	# 冰晶、脚下冰刺碎成冰碴
	for c in _crystals:
		_burst_from(c[0], 4)
		c[3].queue_free()
	for b in _base:
		_burst_from(b[0], 3)
	_crystals.clear()
	if is_instance_valid(_base_root):
		_base_root.queue_free()
	_base.clear()
	var bm: ParticleProcessMaterial = burst_mist.process_material
	bm.emission_box_extents = Vector3(_radius, _height * 0.4, _radius)
	burst_mist.position = Vector3(0, _height * 0.45, 0)
	burst_mist.restart()
	burst_mist.emitting = true
	mist.emitting = false
	glitter.emitting = false


func tick(delta: float) -> void:
	var speed := 1.0 if delta > 0.0 else 0.0
	for p in [mist, glitter, shards, burst_mist]:
		p.speed_scale = speed
	if delta <= 0.0:
		return
	_t += delta
	_phase_t += delta
	match state:
		"freezing":
			var k := clampf(_phase_t / freeze_time, 0.0, 1.0)
			_set_progress(1.0 - pow(1.0 - k, 2.0))
			frost_decal.modulate.a = k
			if k >= 1.0:
				state = "frozen"
		"frozen":
			_set_progress(1.0)
		"shattering":
			var k := clampf(_phase_t / shatter_time, 0.0, 1.0)
			if _shell != null:
				_shell.set_shader_parameter("shatter", k)
			_tint(1.0 - k)
			frost_decal.modulate.a = 1.0 - clampf(_phase_t / 1.6, 0.0, 1.0)
			if k >= 1.0 and _phase_t > 1.6:
				_restore_overlays()
				frost_decal.visible = false
				state = "idle"
	_animate_ice()


# ---------- 体型 ----------

func _measure() -> void:
	_ground_y = _visual.global_position.y
	var top := _ground_y + 0.5
	var r := 0.2
	var origin := _visual.global_position
	if _skeleton != null:
		for b in _skeleton.get_bone_count():
			var p := _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
			top = maxf(top, p.y)
			r = maxf(r, Vector2(p.x - origin.x, p.z - origin.z).length())
	_height = maxf(top - _ground_y, 0.4) * 1.06     # 骨骼到头顶还差一点
	_radius = clampf(r * 0.85, 0.22, _height * 0.6)


# ---------- 冰晶 ----------

func _body_mesh() -> MeshInstance3D:
	var best: MeshInstance3D
	var most := 0
	for m in _meshes:
		if m.mesh == null or m.skin == null:
			continue
		var n: int = m.mesh.surface_get_array_len(0)
		if n > most:
			most = n
			best = m
	return best


func _grow_crystals() -> void:
	var body := _body_mesh()
	if body == null or _skeleton == null:
		return
	var arrays := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or bones == null or weights == null:
		return
	var per := int(bones.size() / verts.size())
	var skin := body.skin
	var target := clampi(int(round(_height * _radius * 2.0 * crystal_density)), crystal_count_range.x, crystal_count_range.y)
	var min_dist := _height * 0.11
	var placed: PackedVector3Array = []
	var tries := 0
	while placed.size() < target and tries < target * 60:
		tries += 1
		var i := _rng.randi_range(0, verts.size() - 1)
		# 主骨骼：权重最大的那根
		var best_w := -1.0
		var bind := 0
		for j in per:
			if weights[i * per + j] > best_w:
				best_w = weights[i * per + j]
				bind = bones[i * per + j]
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = _skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0:
			continue
		var w := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
		var p: Vector3 = w * verts[i]
		var n := (w.basis * normals[i]).normalized()
		var h := (p.y - _ground_y) / _height
		if n.y < -0.25 or h < 0.12 or h > 1.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < min_dist:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		_add_crystal_cluster(bone, p, n, h)


func _add_crystal_cluster(bone: int, p: Vector3, n: Vector3, h: float) -> void:
	var att := BoneAttachment3D.new()
	_skeleton.add_child(att)
	att.bone_idx = bone
	var att_world := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	var count := _rng.randi_range(1, 3)
	for k in count:
		var length := _height * _rng.randf_range(crystal_length_ratio.x, crystal_length_ratio.y) * (1.0 if k == 0 else 0.65)
		var radius := length * _rng.randf_range(0.22, 0.34)
		var dir := (n + Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.0, 0.5), _rng.randf_range(-0.45, 0.45))).normalized()
		var x := dir.cross(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))).normalized()
		var z := x.cross(dir)
		var world := Transform3D(Basis(x, dir, z) * Basis.from_scale(Vector3(radius, length, radius)), p - dir * length * 0.12)
		var mi := MeshInstance3D.new()
		mi.mesh = crystal_mesh
		mi.material_override = crystal_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)
		var local := att_world.affine_inverse() * world
		mi.transform = _scaled(local, 0.001)
		_crystals.append([mi, local, h, att])


func _grow_base() -> void:
	_base_root = Node3D.new()
	add_child(_base_root)
	_base_root.top_level = true
	_base_root.global_transform = Transform3D(Basis(), global_position)
	var count := maxi(5, int(round(TAU * _radius * base_spike_count_per_m)))
	for i in count:
		var a := TAU * (i + _rng.randf_range(-0.3, 0.3)) / count
		var out := Vector3(sin(a), 0.0, cos(a))
		var length := _height * _rng.randf_range(base_height_ratio.x, base_height_ratio.y)
		var radius := length * _rng.randf_range(0.25, 0.4)
		var dir := (Vector3.UP + out * _rng.randf_range(0.15, 0.6)).normalized()
		var x := dir.cross(out).normalized()
		var z := x.cross(dir)
		var full := Transform3D(Basis(x, dir, z) * Basis.from_scale(Vector3(radius, length, radius)), out * _radius * _rng.randf_range(0.55, 0.95))
		var mi := MeshInstance3D.new()
		mi.mesh = crystal_mesh
		mi.material_override = crystal_material
		_base_root.add_child(mi)
		mi.transform = _scaled(full, 0.001)
		_base.append([mi, full])


# ---------- 动画 ----------

func _animate_ice() -> void:
	if state != "freezing" and state != "frozen":
		return
	var progress: float = _shell.get_shader_parameter("progress") if _shell != null else 1.0
	for c in _crystals:
		# 冰爬到这个高度时，冰晶在 0.12 秒内长出来（略微冲过头再回落）
		var k := clampf((progress * 1.1 - c[2]) / 0.25, 0.0, 1.0)
		c[0].transform = _scaled(c[1], _ease_back(k))
	var base_k := clampf(_phase_t / (freeze_time * 0.6), 0.0, 1.0) if state == "freezing" else 1.0
	for b in _base:
		b[0].transform = _scaled(b[1], _ease_back(base_k))


func _set_progress(v: float) -> void:
	if _shell != null:
		_shell.set_shader_parameter("progress", v)
	_tint(v)


func _tint(v: float) -> void:
	if _visual != null and _visual.has_method("set_element_tint"):
		_visual.set_element_tint(tint, 0.55 * v)


static func _ease_back(k: float) -> float:
	if k <= 0.0:
		return 0.001
	return 1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0)


static func _scaled(t: Transform3D, k: float) -> Transform3D:
	# 沿冰晶自身轴缩放：长度方向按 k，粗细稍慢一点
	return Transform3D(t.basis * Basis.from_scale(Vector3(sqrt(maxf(k, 0.0)), maxf(k, 0.001), sqrt(maxf(k, 0.0)))), t.origin)


func _burst_from(mi: MeshInstance3D, count: int) -> void:
	if not is_instance_valid(mi):
		return
	var xf := mi.global_transform
	var axis := xf.basis.y
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	for i in count:
		var pos := xf.origin + axis * _rng.randf_range(0.2, 0.9)
		var out := (pos - global_position)
		out.y = 0.0
		var dir := (out.normalized() * 0.8 + axis.normalized() * 0.5 + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0.3, 0.9), _rng.randf_range(-0.4, 0.4))).normalized()
		var rot := Basis(Quaternion(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), _rng.randf() * TAU))
		shards.emit_particle(Transform3D(rot, pos), dir * _rng.randf_range(1.2, 3.2), Color.WHITE, Color(0.0, 0.0, _rng.randf(), _rng.randf_range(0.6, 1.0)), flags)


func _clear_ice() -> void:
	for c in _crystals:
		if is_instance_valid(c[3]):
			c[3].queue_free()
	_crystals.clear()
	if is_instance_valid(_base_root):
		_base_root.queue_free()
	_base.clear()
	_restore_overlays()


func _restore_overlays() -> void:
	if _old_overlays.size() == _meshes.size():
		for i in _meshes.size():
			if _meshes[i].material_overlay == _shell:
				_meshes[i].material_overlay = _old_overlays[i]
	_old_overlays.clear()
	_shell = null
	_tint(0.0)


func _exit_tree() -> void:
	_clear_ice()
