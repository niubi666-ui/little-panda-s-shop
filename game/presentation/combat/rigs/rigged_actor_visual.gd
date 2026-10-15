extends Node3D
## 通用骨骼角色表现适配器：只读取已确认的战斗状态，按进度采样动作，不参与任何判定。
## 主角和所有临时敌人共用；换模型只需要换 Model 子节点和 clip_set 资源。
## 约定见 docs/ART_PIPELINE.md 的“怎么替换一个角色”。
const ClipSet = preload("res://presentation/combat/rigs/actor_clip_set.gd")
const ToonSkin = preload("res://presentation/shared/toon/toon_skin.gd")
const Feedback = preload("res://presentation/combat/rigs/rig_feedback.gd")

## 以下都在各角色的 *_visual.tscn 里显式赋值。
@export var clip_set: ClipSet
## 转身、受击、尸体、前摇泛光等手感（rig_feedback_*.tres，同类角色共用）
@export var feedback: Feedback
## 角色材质（shared/pbr 或 shared/toon 的 character_material.tres）；每个实例会复制一份。
@export var material: ShaderMaterial
## 贴图模型（如 AI 生成的模型）保留各自贴图，只换光照模型
@export var keep_textures: bool
## 整体染色（乘在贴图上，仅 keep_textures 时生效）：同一个身体模型靠它区分不同兵种
@export var tint: Color

var brain
var animation: AnimationPlayer
var skeleton: Skeleton3D
var model: Node3D
var _materials: Array[ShaderMaterial] = []
var _clip := &""
var _clock := 0.0
var _death_age := 0.0
var _dead := false
var _blend_total := 0.0
var _blend_left := 0.0
var _from_position: PackedVector3Array = []
var _from_rotation: Array[Quaternion] = []
var _from_scale: PackedVector3Array = []
var _world_yaw := 0.0
var _yaw_ready := false
var _bound_actor
var _flash_left := 0.0
var _shake_left := 0.0
var _shake_direction := Vector3.ZERO
var _last_health := -1.0
var _model_rest := Vector3.ZERO

func _ready() -> void:
	model = get_node_or_null("Model")
	assert(model != null, "RiggedActorVisual needs a child named Model")
	_model_rest = model.position
	animation = find_child("AnimationPlayer", true, false)
	skeleton = find_child("Skeleton3D", true, false)
	if animation != null:
		# 每个实例独立一份动作库：同一 GLB 的多个实例互不影响。
		for library_name in animation.get_animation_library_list():
			var library: AnimationLibrary = animation.get_animation_library(library_name).duplicate(true)
			for clip in library.get_animation_list(): library.get_animation(clip).loop_mode = Animation.LOOP_NONE
			animation.remove_animation_library(library_name)
			animation.add_animation_library(library_name, library)
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_materials = ToonSkin.apply(self, material, keep_textures, tint)

func validate_assets() -> bool:
	if clip_set == null or feedback == null or find_child("AnimationPlayer", true, false) == null: return false
	var missing := clip_set.missing_cuts()
	if not missing.is_empty():
		push_error("%s: clip set %s has attack clips without attack_cuts: %s" % [name, clip_set.resource_path, missing])
		return false
	return true

func bind_brain(value) -> void:
	brain = value

func afterimage_source() -> Node3D:
	return model

func _has(clip: StringName) -> bool:
	return not clip.is_empty() and animation.has_animation(clip)

func _length(clip: StringName) -> float:
	return animation.get_animation(clip).length

func refresh_actor(actor, delta: float) -> void:
	if animation == null or clip_set == null: return
	if _bound_actor != actor:
		_bound_actor = actor
		_last_health = actor.health.current
	_react_to_damage(actor)
	_tick_feedback(delta)
	# 冻结：保持当前姿势，但不能压住已经确认的死亡。
	if actor.health.alive() and actor.control_locked: return
	var clip: StringName = clip_set.idle
	var time := 0.0
	var looping := false
	var rate := 1.0
	var blend: float = clip_set.blend_sec
	var glow := 0.0
	if not actor.health.alive():
		_dead = true
		_death_age += delta
		clip = clip_set.death
		if _has(clip): time = minf(_death_age, _length(clip))
	elif actor.stagger_left > 0.0 and _has(clip_set.hit):
		clip = clip_set.hit
		time = (1.0 - clampf(actor.stagger_left / maxf(actor.definition.stagger, 0.001), 0.0, 1.0)) * _length(clip)
		blend = clip_set.react_blend_sec
	elif actor.dodge_left > 0.0 and actor.dodge != null and _has(clip_set.dodge):
		clip = clip_set.dodge
		time = clampf(actor.dodge_age / actor.dodge.duration, 0.0, 1.0) * _length(clip)
		blend = clip_set.react_blend_sec
	elif actor.runner.busy():
		clip = _attack_clip(actor)
		var cuts: Vector2 = clip_set.attack_cuts[clip] if clip_set.attack_cuts.has(clip) else Vector2.ZERO
		var ability = actor.runner.ability
		var elapsed: float = actor.runner.elapsed
		if _has(clip):
			match actor.runner.phase():
				"windup":
					var progress := clampf(elapsed / maxf(ability.windup, 0.001), 0.0, 1.0)
					time = lerpf(0.0, cuts.x, progress)
					glow = progress
				"active": time = lerpf(cuts.x, cuts.y, clampf((elapsed - ability.windup) / maxf(ability.active, 0.001), 0.0, 1.0))
				"recovery": time = lerpf(cuts.y, _length(clip), clampf((elapsed - ability.windup - ability.active) / maxf(ability.recovery, 0.001), 0.0, 1.0))
		blend = clip_set.attack_blend_sec
	elif actor.charging_skill and _has(clip_set.charge):
		clip = clip_set.charge
		looping = true
	elif brain != null and _brain_clip(actor) != &"":
		clip = _brain_clip(actor)
		match brain.state:
			"windup":
				var progress: float = 1.0 - clampf(brain.time_left / maxf(brain.windup_duration, 0.001), 0.0, 1.0)
				time = progress * _length(clip)
				glow = progress
			"recovery":
				time = (1.0 - clampf(brain.time_left / maxf(brain.recovery_duration, 0.001), 0.0, 1.0)) * _length(clip)
			_: looping = true
	else:
		looping = true
		var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
		if speed > clip_set.move_min_speed and _has(clip_set.move):
			clip = clip_set.move
			rate = clampf(speed / maxf(clip_set.move_reference_speed, 0.01), clip_set.move_rate_min, clip_set.move_rate_max)
	if not _has(clip): clip = clip_set.idle
	if not _has(clip): return
	_sample(clip, time, looping, rate, blend, delta)
	_face(actor, delta)
	var fade := 0.0
	if _dead and not feedback.keep_corpse and _has(clip_set.death) and feedback.corpse_fade_sec > 0.0:
		fade = clampf((_death_age - _length(clip_set.death) - feedback.corpse_hold_sec) / feedback.corpse_fade_sec, 0.0, 1.0)
	for instance in _materials:
		instance.set_shader_parameter("glow", glow * feedback.telegraph_glow)
		instance.set_shader_parameter("glow_color", feedback.telegraph_color)
		instance.set_shader_parameter("dissolve", fade)
	# HitFeedback 会临时隐藏死亡模型；倒地到消散这一段由本适配器负责保留，之后收起。
	visible = actor.health.alive() or feedback.keep_corpse or has_presentation_tail()

func _attack_clip(actor) -> StringName:
	var id: String = actor.runner.ability.id
	if clip_set.attacks.has(id): return clip_set.attacks[id]
	var key: String = actor.runner.presentation_key
	if clip_set.attacks.has(key): return clip_set.attacks[key]
	if not clip_set.attack_fallback.is_empty():
		return clip_set.attack_fallback[posmod(actor.runner.cast_id - 1, clip_set.attack_fallback.size())]
	return clip_set.idle

func _brain_clip(actor) -> StringName:
	if not clip_set.states.has(brain.state): return &""
	var clip: StringName = clip_set.states[brain.state]
	return clip if _has(clip) else &""

func _sample(clip: StringName, time: float, looping: bool, rate: float, blend: float, delta: float) -> void:
	if clip != _clip:
		_snapshot()
		_blend_total = blend
		_blend_left = blend if not _clip.is_empty() else 0.0
		_clip = clip
		_clock = 0.0
		animation.play(clip)
	if looping:
		_clock += delta * rate
		time = fmod(_clock, _length(clip))
	animation.seek(time, true)
	if _blend_left > 0.0 and skeleton != null:
		_blend_left = maxf(0.0, _blend_left - delta)
		var weight := 1.0 - _blend_left / _blend_total
		weight = weight * weight * (3.0 - 2.0 * weight)
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_position(bone, _from_position[bone].lerp(skeleton.get_bone_pose_position(bone), weight))
			skeleton.set_bone_pose_rotation(bone, _from_rotation[bone].slerp(skeleton.get_bone_pose_rotation(bone), weight))
			skeleton.set_bone_pose_scale(bone, _from_scale[bone].lerp(skeleton.get_bone_pose_scale(bone), weight))

func _snapshot() -> void:
	if skeleton == null: return
	var count := skeleton.get_bone_count()
	_from_position.resize(count)
	_from_rotation.resize(count)
	_from_scale.resize(count)
	for bone in count:
		_from_position[bone] = skeleton.get_bone_pose_position(bone)
		_from_rotation[bone] = skeleton.get_bone_pose_rotation(bone)
		_from_scale[bone] = skeleton.get_bone_pose_scale(bone)

func _face(actor, delta: float) -> void:
	# ActorView 已经把本节点转到“出招方向/瞄准方向”；这里只在其上叠加身体的额外转向。
	var base: Vector3 = actor.runner.direction if actor.runner.busy() else actor.facing
	var base_yaw := atan2(-base.x, -base.z)
	var wanted := base_yaw
	if feedback.face_movement and actor.health.alive():
		if actor.dodge_left > 0.0 and not actor.dodge_direction.is_zero_approx():
			wanted = atan2(-actor.dodge_direction.x, -actor.dodge_direction.z)
		elif not actor.runner.busy() and not actor.charging_skill and actor.stagger_left <= 0.0:
			var planar := Vector2(actor.velocity.x, actor.velocity.z)
			if planar.length() > feedback.face_min_speed: wanted = atan2(-planar.x, -planar.y)
	if not _yaw_ready:
		_world_yaw = wanted
		_yaw_ready = true
	elif delta > 0.0:
		_world_yaw = lerp_angle(_world_yaw, wanted, 1.0 - exp(-feedback.turn_sharpness * delta))
	model.rotation.y = wrapf(_world_yaw - base_yaw, -PI, PI) if feedback.face_movement else 0.0

func _react_to_damage(actor) -> void:
	var now: float = actor.health.current
	if _last_health >= 0.0 and now < _last_health - 0.001:
		_flash_left = feedback.own_flash_sec
		_shake_left = feedback.hit_shake_sec
		_shake_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_last_health = now

func _tick_feedback(delta: float) -> void:
	# 顿帧期间战斗时间被压缩，但闪白和抖动要按真实时间走；暂停（delta 为 0）时冻结。
	delta = get_physics_process_delta_time() if delta > 0.0 else 0.0
	if _flash_left > 0.0 or feedback.own_flash_sec > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		var amount := _flash_left / feedback.own_flash_sec if feedback.own_flash_sec > 0.0 else 0.0
		for instance in _materials:
			instance.set_shader_parameter("flash", amount)
			instance.set_shader_parameter("flash_color", feedback.flash_color)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var falloff := _shake_left / feedback.hit_shake_sec
		model.position = _model_rest + _shake_direction * (sin(_shake_left * feedback.hit_shake_speed) * feedback.hit_shake_m * falloff)
	else:
		model.position = _model_rest

## 元素染色：color 为元素颜色，amount 0..1（0 为无）
func set_element_tint(color: Color, amount: float) -> void:
	for instance in _materials:
		instance.set_shader_parameter("element_color", color)
		instance.set_shader_parameter("element_amount", amount)

func has_presentation_tail() -> bool:
	return _dead and animation != null and _has(clip_set.death) and _death_age < _length(clip_set.death) + feedback.corpse_hold_sec + feedback.corpse_fade_sec
