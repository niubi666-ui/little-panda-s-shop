extends Node3D
## Logic samples exported animations; AnimationPlayer never advances combat.
@export var style: Resource
var brain
var animation: AnimationPlayer
var clock := 0.0
var death_age := 0.0
var selected_clip := ""

func validate_assets() -> bool:
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false)
	if player == null or style == null: return false
	for clip in style.clips.values():
		if not player.has_animation(clip): return false
	return true

func bind_brain(value) -> void:
	brain = value
	animation = find_child("AnimationPlayer", true, false)
	assert(animation != null)
	for clip in style.clips.values():
		assert(animation.has_animation(clip), "Missing ranger clip: " + clip)
		animation.get_animation(clip).loop_mode = Animation.LOOP_NONE
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func refresh_actor(actor, delta: float) -> void:
	if brain == null or animation == null: return
	if actor.health.alive() and actor.control_locked: return
	clock += delta
	var clip := "idle"
	var progress := 0.0
	if not actor.health.alive():
		death_age += delta
		clip = "death"
		progress = minf(1.0, death_age / style.death_duration_sec)
	elif actor.stagger_left > 0.0:
		clip = "hit"
		progress = 1.0 - actor.stagger_left / actor.definition.stagger
	elif brain.state == "windup":
		clip = "rain" if brain.attack_id == "rain" else "aim"
		progress = 1.0 - brain.time_left / brain.windup_duration
		if progress < style.draw_phase_fraction:
			clip = "draw"
			progress /= style.draw_phase_fraction
		else: progress = (progress - style.draw_phase_fraction) / (1.0 - style.draw_phase_fraction)
	elif brain.state == "recovery":
		clip = "rain_release" if brain.attack_id == "rain" else "release"
		progress = 1.0 - brain.time_left / brain.recovery_duration
	elif brain.state == "rolling":
		clip = "roll"
		progress = 1.0 - brain.roll_left / brain.roll_duration
	elif actor.velocity.length_squared() > 0.0: clip = "move"
	var name: String = style.clips[clip]
	var length := animation.get_animation(name).length
	if clip in ["idle", "move"]: progress = fmod(clock / length, 1.0)
	if name != selected_clip:
		selected_clip = name
		animation.play(name)
	animation.seek(clampf(progress, 0.0, 1.0) * length, true)
	$Model.rotation.y = actor.facing.signed_angle_to(brain.roll_direction, Vector3.UP) if brain.state == "rolling" else 0.0
	visible = actor.health.alive() or has_presentation_tail()

func has_presentation_tail() -> bool:
	return brain != null and not brain.actor.health.alive() and death_age < style.death_duration_sec
