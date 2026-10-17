extends "res://presentation/combat/rigs/rigged_actor_visual.gd"
## 原生 Manny 动作：方向选择只影响姿势，位移仍由 CharacterMotor 执行。
const NodachiClips = preload("res://presentation/combat/rigs/nodachi_clip_set.gd")
var nodachi: NodachiClips
var _roll_active := false
var _roll_locomotion := false
var _roll_facing := Vector3.FORWARD
var _roll_clip: StringName
var _last_roll_age := -1.0
var _weapon_base: Node3D
var _weapon_tip: Node3D
var _roll_transition := false
var _upper_bones: Dictionary = {}

func _ready() -> void:
	super._ready()
	assert(clip_set is NodachiClips)
	nodachi = clip_set as NodachiClips
	_weapon_base = get_node(nodachi.weapon_base_path)
	_weapon_tip = get_node(nodachi.weapon_tip_path)
	var upper := skeleton.find_bone(nodachi.upper_body_root)
	assert(upper >= 0)
	for bone in skeleton.get_bone_count():
		var parent := bone
		while parent >= 0:
			if parent == upper:
				_upper_bones[bone] = true
				break
			parent = skeleton.get_bone_parent(parent)

func validate_assets() -> bool:
	if not super.validate_assets(): return false
	if nodachi.roll_locomotion_fraction <= 0.0 or nodachi.roll_locomotion_fraction > 1.0 or nodachi.roll_exit_blend_sec <= 0.0: return false
	for group in [nodachi.run_directions, nodachi.walk_directions, nodachi.roll_directions]:
		if group.size() != 8: return false
		for clip in group:
			if not _has(clip):
				push_error("Nodachi missing directional clip: " + clip)
				return false
	for clip in [clip_set.idle, clip_set.hit, clip_set.death, clip_set.charge] + clip_set.attacks.values():
		if not _has(clip): return false
	return _weapon_base != null and _weapon_tip != null

func refresh_actor(actor, delta: float) -> void:
	if actor.dodge_left <= 0.0 and not actor.roll_attack_finishing_roll():
		_roll_active = false
		_last_roll_age = -1.0
	super.refresh_actor(actor, delta)

func _attack_clip(actor) -> StringName:
	if actor.roll_attack_finishing_roll(): return _roll_clip
	return super._attack_clip(actor)

func _attack_sample_time(actor, clip_name: StringName, time: float) -> float:
	if not actor.is_roll_attack_cast(): return time
	if actor.roll_attack_finishing_roll():
		return actor.roll_attack_roll_age() / actor.dodge.duration * _length(clip_name)
	if actor.runner.phase() == "windup":
		var progress: float = clampf((actor.runner.elapsed - actor.roll_attack_link_duration) / actor.dodge.attack.windup, 0.0, 1.0)
		return clip_set.attack_cuts[clip_name].x * progress
	return time

func _transition_duration(previous: StringName, next: StringName, duration: float) -> float:
	_roll_transition = previous in nodachi.roll_directions and next == nodachi.roll_attack_clip
	if previous == nodachi.roll_attack_clip and (_locomotion(next) or next == clip_set.idle):
		return nodachi.roll_attack_exit_blend_sec
	if previous in nodachi.roll_directions and (_locomotion(next) or next == clip_set.idle):
		return nodachi.roll_exit_blend_sec
	return maxf(nodachi.roll_attack_lower_blend_sec, nodachi.roll_attack_upper_blend_sec) if _roll_transition else duration

func _transition_weight(bone: int, elapsed: float, duration: float) -> float:
	if _roll_transition:
		duration = nodachi.roll_attack_upper_blend_sec if _upper_bones.has(bone) else nodachi.roll_attack_lower_blend_sec
	return super._transition_weight(bone, elapsed, duration)

func _dodge_clip(actor) -> StringName:
	if not _roll_active or actor.dodge_age < _last_roll_age:
		_roll_active = true
		_roll_locomotion = false
		_roll_facing = actor.facing
		_roll_clip = nodachi.roll_directions[nodachi.direction_index(actor.dodge_direction, _roll_facing)]
	_last_roll_age = actor.dodge_age
	return _roll_clip

func _dodge_locomotion(actor) -> bool:
	# 落地后有移动输入就接步态；松键切待机，不重新播放剩余翻滚。
	if actor.dodge_age >= actor.dodge.duration * nodachi.roll_locomotion_fraction and not actor.movement.is_zero_approx():
		_roll_locomotion = true
	return _roll_locomotion

func _move_clip(actor) -> StringName:
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var group: Array = nodachi.walk_directions if speed < nodachi.walk_below_speed else nodachi.run_directions
	return group[nodachi.direction_index(actor.velocity, actor.facing)]

func _locomotion(clip: StringName) -> bool:
	return clip in nodachi.run_directions or clip in nodachi.walk_directions

func _move_rate(speed: float, selected_clip: StringName) -> float:
	var reference := nodachi.walk_reference_speed if selected_clip in nodachi.walk_directions else nodachi.move_reference_speed
	return clampf(speed / reference, nodachi.move_rate_min, nodachi.move_rate_max)

func _switch_clock(previous: StringName, next: StringName) -> float:
	# 换侧跑方向时保持步态相位，不反复从第一步开始。
	if _locomotion(previous) and _locomotion(next):
		return fmod(_clock, _length(previous)) / _length(previous) * _length(next)
	return 0.0

func _recovery_weight(progress: float) -> float:
	# 保留原始动画的缓入缓出；不再叠加旧版程序动作的 smoothstep。
	return progress

func _face(actor, _delta: float) -> void:
	# 翻滚期间锁定起始身体朝向，鼠标移动不能把侧滚变成原地旋转。
	var base: Vector3 = actor.runner.direction if actor.runner.busy() else actor.facing
	var facing: Vector3 = _roll_facing if _roll_active and _clip in nodachi.roll_directions else base
	model.rotation.y = wrapf(atan2(-facing.x, -facing.z) - atan2(-base.x, -base.z), -PI, PI)
	if actor.runner.busy() and actor.is_roll_attack_cast() and not actor.roll_attack_finishing_roll():
		var from := atan2(-_roll_facing.x, -_roll_facing.z)
		var target := atan2(-base.x, -base.z)
		var weight := smoothstep(0.0, 1.0, clampf((actor.runner.elapsed - actor.roll_attack_link_duration) / nodachi.roll_attack_turn_sec, 0.0, 1.0))
		model.rotation.y = wrapf(lerp_angle(from, target, weight) - target, -PI, PI)

func weapon_fx_surface() -> MeshInstance3D:
	return _weapon_base.get_parent() as MeshInstance3D

func weapon_fx_length() -> float:
	return _weapon_anchor(_weapon_base).origin.distance_to(_weapon_anchor(_weapon_tip).origin)

func _weapon_anchor(anchor: Node3D) -> Transform3D:
	var sword: Node3D = anchor.get_parent()
	var attachment: BoneAttachment3D = sword.get_parent()
	# BoneAttachment 的节点变换在渲染前才同步，物理帧中直接读已采样的骨骼，避免刀光落后一帧。
	return skeleton.global_transform * skeleton.get_bone_global_pose(attachment.get_bone_idx()) * sword.transform * anchor.transform

func weapon_fx_transform() -> Transform3D:
	skeleton.force_update_all_bone_transforms()
	var start := _weapon_anchor(_weapon_base).origin
	var end := _weapon_anchor(_weapon_tip).origin
	var z := (start - end).normalized()
	var x := _weapon_anchor(_weapon_base).basis.x.normalized()
	var y := z.cross(x).normalized()
	x = y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), (start + end) * 0.5)
