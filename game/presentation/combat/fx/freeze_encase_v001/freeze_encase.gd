extends Node3D
## 冰冻状态表现：贴合敌人体型的冰封（来自 vfx_lab/freeze_lab，用户认可）。只读模型和骨骼，不参与判定。
## 作为 mechanism_style.status_scenes["freeze"] 使用：敌人被冻住时 mechanism_view 生成本场景，
## configure_effect(snapshot) → 找到这个敌人的表现节点并冰封；每帧 sync_effect(snapshot, delta)（delta 为 0 = 暂停，全部停住）；
## 解冻或死亡时 finish() → 碎冰，has_tail() 为真期间 mechanism_view 继续 tail_tick(delta)，碎完再释放。
##
## 贴合体型（换新模型不用改代码，见 README.txt 里的模型要求）：
## - 冰壳：敌人自己的每个 MeshInstance3D 挂 material_overlay（ice_shell.gdshader），顶点沿法线外推，轮廓/武器/姿势一致。
## - 冰晶：在身体网格表面按三角形面积随机取点，挂到驱动该点的骨骼上；取样表按网格缓存，同种敌人只算一次。
## - 体型：有骨架时取当前姿势的骨骼范围，没有骨架时取网格包围盒。冰晶数量、冰刺圈、霜花、寒气都按身高和体宽缩放。

@export var shell_material: ShaderMaterial
@export var crystal_mesh: Mesh
@export var crystal_material: Material
@export var mist: GPUParticles3D
@export var glitter: GPUParticles3D
@export var shards: GPUParticles3D        ## 世界原点 + emit_particle：碎裂时的冰碴
@export var burst_mist: GPUParticles3D
@export var frost_decal: Decal
@export var freeze_time := 0.35
@export var shatter_time := 0.3
@export var tail_time := 1.6
@export var shell_thickness_ratio := 0.022
@export var crystal_density := 22.0
@export var crystal_count_range := Vector2i(6, 26)
@export var crystal_length_ratio := Vector2(0.1, 0.22)
@export var base_spike_count_per_m := 9.0
@export var base_height_ratio := Vector2(0.14, 0.32)
## 游戏里敌人的元素染色由 ActorView 每帧写入，这里默认不再叠加
@export var apply_tint := false
@export var tint := Color(0.6, 0.85, 1.0)

## 每个网格资源一份面积取样表：mesh instance id → {cdf, indices}
static var _sample_cache: Dictionary = {}

var state := "idle"
var _visual: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _old_overlays: Array = []
var _shell: ShaderMaterial
var _crystals: Array = []     # [mesh_instance, full_transform, height_frac, attachment]
var _base: Array = []
var _base_root: Node3D
var _t := 0.0
var _phase_t := 0.0
var _ground := Vector3.ZERO
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
	if glitter.material_override is ShaderMaterial:
		glitter.material_override = glitter.material_override.duplicate()


# ---------- mechanism_view 状态场景接口 ----------

func configure_effect(snapshot: Dictionary) -> void:
	var visual := _find_visual(int(snapshot.handle))
	if visual == null:
		return
	attach(visual)
	freeze()


func sync_effect(_snapshot: Dictionary, delta: float) -> void:
	# mechanism_view 每帧把节点摆到 snapshot.position + freeze_offset；冰封要贴着地面，摆回来
	if state != "idle":
		global_position = _ground
	tick(delta)


func finish(_reason: String) -> void:
	release()


func has_tail() -> bool:
	return state == "shattering"


func tail_tick(delta: float) -> void:
	tick(delta)


func _find_visual(handle: int) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "Node3D", true, false):
		if node.get("handle") == handle and node.get("health") != null:
			for child in node.get_children():
				var v = child.get("visual")
				if v is Node3D:
					return v
	return null


# ---------- 冰封 ----------

func attach(visual: Node3D) -> void:
	_visual = visual
	_skeleton = visual.find_child("Skeleton3D", true, false)
	_meshes.clear()
	for m in visual.find_children("*", "MeshInstance3D", true, false):
		if m.mesh != null and m.is_visible_in_tree():
			_meshes.append(m)


func is_frozen() -> bool:
	return state == "freezing" or state == "frozen"


func freeze() -> void:
	if _visual == null or is_frozen():
		return
	_clear_ice()
	_measure()
	global_position = _ground
	_shell = shell_material.duplicate()
	_shell.set_shader_parameter("ground_y", _ground.y)
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
	(mist.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(_radius, _height * 0.45, _radius)
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
	for c in _crystals:
		_burst_from(c[0], 4)
		c[3].queue_free()
	for b in _base:
		_burst_from(b[0], 3)
	_crystals.clear()
	if is_instance_valid(_base_root):
		_base_root.queue_free()
	_base.clear()
	(burst_mist.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(_radius, _height * 0.4, _radius)
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
	if glitter.material_override is ShaderMaterial:
		glitter.material_override.set_shader_parameter("effect_time", _t)
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
			frost_decal.modulate.a = 1.0 - clampf(_phase_t / tail_time, 0.0, 1.0)
			if k >= 1.0 and _phase_t > tail_time:
				_restore_overlays()
				frost_decal.visible = false
				state = "idle"
	_animate_ice()


# ---------- 体型 ----------

func _measure() -> void:
	var origin := _visual.global_position
	_ground = origin
	var top := origin.y + 0.5
	var r := 0.2
	if _skeleton != null and _skeleton.get_bone_count() > 0:
		top = origin.y
		for b in _skeleton.get_bone_count():
			var p := _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
			top = maxf(top, p.y)
			r = maxf(r, Vector2(p.x - origin.x, p.z - origin.z).length())
		_height = maxf(top - origin.y, 0.4) * 1.06     # 骨骼到头顶还差一点
		_radius = clampf(r * 0.85, 0.22, _height * 0.6)
	else:
		# 没有骨架：用网格包围盒
		var box := AABB()
		var first := true
		for m in _meshes:
			var a: AABB = m.global_transform * m.get_aabb()
			box = a if first else box.merge(a)
			first = false
		if not first:
			_ground.y = box.position.y
			_height = maxf(box.size.y, 0.4)
			var half := Vector2(box.size.x, box.size.z) * 0.5
			_radius = clampf(maxf(half.x, half.y) * 0.85, 0.22, _height * 0.6)


# ---------- 冰晶 ----------

func _body_mesh() -> MeshInstance3D:
	# 模型可以用 meta "freeze_body_mesh"（NodePath，相对表现节点）指定身体网格；否则取顶点最多的蒙皮网格
	if _visual.has_meta("freeze_body_mesh"):
		var chosen := _visual.get_node_or_null(_visual.get_meta("freeze_body_mesh"))
		if chosen is MeshInstance3D:
			return chosen
	var best: MeshInstance3D
	var most := 0
	for m in _meshes:
		if m.skin == null:
			continue
		var n: int = m.mesh.surface_get_array_len(0)
		if n > most:
			most = n
			best = m
	return best


func _samples(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if _sample_cache.has(key):
		return _sample_cache[key]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	var cdf := PackedFloat32Array()
	var total := 0.0
	for t in indices.size() / 3:
		var a := verts[indices[t * 3]]
		total += (verts[indices[t * 3 + 1]] - a).cross(verts[indices[t * 3 + 2]] - a).length() * 0.5
		cdf.append(total)
	var data := {"arrays": arrays, "indices": indices, "cdf": cdf, "total": total}
	_sample_cache[key] = data
	return data


func _grow_crystals() -> void:
	var body := _body_mesh()
	if body == null or body.skin == null or _skeleton == null:
		return
	var data := _samples(body.mesh)
	var arrays: Array = data.arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = data.indices
	var cdf: PackedFloat32Array = data.cdf
	if verts.is_empty() or bones == null or weights == null or cdf.is_empty():
		return
	var per := int(bones.size() / verts.size())
	var skin := body.skin
	var target := clampi(int(round(_height * _radius * 2.0 * crystal_density)), crystal_count_range.x, crystal_count_range.y)
	var min_dist := _height * 0.11
	var placed: PackedVector3Array = []
	var tries := 0
	while placed.size() < target and tries < target * 40:
		tries += 1
		# 按面积挑三角形，再在三角形里取随机点
		var t := cdf.bsearch(_rng.randf() * float(data.total))
		t = mini(t, cdf.size() - 1)
		var ia := indices[t * 3]
		var ib := indices[t * 3 + 1]
		var ic := indices[t * 3 + 2]
		var u := _rng.randf()
		var v := _rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var local_p := verts[ia] + (verts[ib] - verts[ia]) * u + (verts[ic] - verts[ia]) * v
		var local_n := (normals[ia] + normals[ib] + normals[ic]).normalized()
		# 主骨骼：离取样点最近的那个顶点上权重最大的骨骼
		var iv := ia if u + v < 0.34 else (ib if u > v else ic)
		var best_w := -1.0
		var bind := 0
		for j in per:
			if weights[iv * per + j] > best_w:
				best_w = weights[iv * per + j]
				bind = bones[iv * per + j]
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = _skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0:
			continue
		var w := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
		var p: Vector3 = w * local_p
		var n: Vector3 = (w.basis * local_n).normalized()
		var h := (p.y - _ground.y) / _height
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
	for k in _rng.randi_range(1, 3):
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
	_base_root.global_transform = Transform3D(Basis(), _ground)
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
	if not is_frozen():
		return
	var progress: float = _shell.get_shader_parameter("progress") if _shell != null else 1.0
	for c in _crystals:
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
	if apply_tint and _visual != null and _visual.has_method("set_element_tint"):
		_visual.set_element_tint(tint, 0.55 * v)


static func _ease_back(k: float) -> float:
	if k <= 0.0:
		return 0.001
	return 1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0)


static func _scaled(t: Transform3D, k: float) -> Transform3D:
	return Transform3D(t.basis * Basis.from_scale(Vector3(sqrt(maxf(k, 0.0)), maxf(k, 0.001), sqrt(maxf(k, 0.0)))), t.origin)


func _burst_from(mi: MeshInstance3D, count: int) -> void:
	if not is_instance_valid(mi):
		return
	var xf := mi.global_transform
	var axis := xf.basis.y
	var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM
	for i in count:
		var pos := xf.origin + axis * _rng.randf_range(0.2, 0.9)
		var out := pos - _ground
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
			if is_instance_valid(_meshes[i]) and _meshes[i].material_overlay == _shell:
				_meshes[i].material_overlay = _old_overlays[i]
	_old_overlays.clear()
	_shell = null
	_tint(0.0)


func _exit_tree() -> void:
	_clear_ice()
