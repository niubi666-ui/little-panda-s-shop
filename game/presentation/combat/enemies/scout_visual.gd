extends Node3D
## One-way adapter: reads confirmed actor state and manually samples skeletal clips.
@export var style: Resource
var animation: AnimationPlayer
var selected_clip := ""
var clip_clock := 0.0
var death_age := 0.0
var _dead := false

func validate_assets() -> bool:
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false)
	if player == null or style == null: return false
	if style.attack_clips.is_empty() or style.walk_reference_speed_mps <= 0.0 or style.run_reference_speed_mps <= 0.0: return false
	if style.movement_epsilon_mps < 0.0 or style.run_threshold_mps <= style.movement_epsilon_mps: return false
	for id in ["idle", "walk", "run", "hit", "death"]:
		if not style.clips.has(id) or not player.has_animation(style.clips[id]): return false
		if player.get_animation(style.clips[id]).length <= 0.0: return false
	for clip in style.attack_clips:
		if not player.has_animation(clip) or not style.attack_cuts_sec.has(clip): return false
		var cuts: Vector2 = style.attack_cuts_sec[clip]
		if cuts.x <= 0.0 or cuts.y <= cuts.x or cuts.y >= player.get_animation(clip).length: return false
	return true

func _initialize_animation() -> void:
	assert(validate_assets(), "Invalid jackal scout animation Resource or GLB")
	animation = find_child("AnimationPlayer", true, false)
	# ActorView already isolates libraries; isolate here too for standalone previews.
	for name in animation.get_animation_library_list():
		var library: AnimationLibrary = animation.get_animation_library(name).duplicate(true)
		for clip in library.get_animation_list(): library.get_animation(clip).loop_mode = Animation.LOOP_NONE
		animation.remove_animation_library(name)
		animation.add_animation_library(name, library)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func refresh_actor(actor, delta: float) -> void:
	if animation == null: _initialize_animation()
	# Freeze preserves the exact pose, but cannot suppress a confirmed death.
	if actor.health.alive() and actor.control_locked: return
	var clip: String = style.clips.idle
	var sample_time := 0.0
	var looping := false
	var playback_rate := 1.0
	if not actor.health.alive():
		_dead = true
		death_age += delta
		clip = style.clips.death
		sample_time = minf(death_age, animation.get_animation(clip).length)
	elif actor.stagger_left > 0.0:
		clip = style.clips.hit
		sample_time = (1.0 - clampf(actor.stagger_left / actor.definition.stagger, 0.0, 1.0)) * animation.get_animation(clip).length
	elif actor.runner.busy():
		clip = style.attack_clips[posmod(actor.runner.cast_id - 1, style.attack_clips.size())]
		var cuts: Vector2 = style.attack_cuts_sec[clip]
		var ability = actor.runner.ability
		var elapsed: float = actor.runner.elapsed
		match actor.runner.phase():
			"windup": sample_time = lerpf(0.0, cuts.x, clampf(elapsed / ability.windup, 0.0, 1.0))
			"active": sample_time = lerpf(cuts.x, cuts.y, clampf((elapsed - ability.windup) / ability.active, 0.0, 1.0))
			"recovery": sample_time = lerpf(cuts.y, animation.get_animation(clip).length, clampf((elapsed - ability.windup - ability.active) / ability.recovery, 0.0, 1.0))
	else:
		looping = true
		var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
		if speed > style.movement_epsilon_mps:
			var running: bool = speed >= style.run_threshold_mps
			clip = style.clips.run if running else style.clips.walk
			playback_rate = speed / (style.run_reference_speed_mps if running else style.walk_reference_speed_mps)
	if clip != selected_clip:
		selected_clip = clip
		clip_clock = 0.0
		animation.play(clip)
	if looping:
		clip_clock += delta * playback_rate
		sample_time = fmod(clip_clock, animation.get_animation(clip).length)
	animation.seek(sample_time, true)
	# HitFeedback temporarily hides dead meshes; this adapter owns the death pose.
	visible = true

func has_presentation_tail() -> bool:
	return _dead and animation != null and death_age < animation.get_animation(style.clips.death).length
