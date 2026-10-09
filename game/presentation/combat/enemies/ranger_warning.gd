extends Node3D
const Style = preload("res://presentation/combat/enemies/ranger_style.tres")
var brain
var geometry
var lines: Array[MeshInstance3D] = []
var ring: MeshInstance3D
var strips: Dictionary = {}
var glow: MeshInstance3D
var light: OmniLight3D
var charge_audio: AudioStreamPlayer3D
var lock_audio: AudioStreamPlayer3D
var _charge_cast := -1
var _lock_cast := -1
var external_charged_cue:=false

func configure(value, factory) -> void:
	brain = value
	geometry = factory
	for attack in ["fast", "volley", "charged"]:
		var length: float=brain.config.charged_range_m if attack=="charged" else brain.config[attack+"_speed_mps"]*brain.config.arrow_lifetime_sec
		var color: Color = Style.charged_warning_color if attack == "charged" else Style.warning_color
		strips[attack] = geometry.strip(length, brain.config.arrow_radius_m * 2.0, color)
		strips[attack + "_locked"] = geometry.strip(length, brain.config.arrow_radius_m * 2.0, Style.locked_warning_color if attack == "charged" else color)
	for i in int(brain.config.volley_count): lines.append(geometry.mesh_node(self))
	ring = geometry.mesh_node(self)
	ring.mesh = geometry.ring(brain.config.rain_radius_m, Style.line_width, Style.warning_color)
	glow = geometry.mesh_node(self)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * Style.charge_glow_size
	glow.mesh = quad
	glow.material_override = Style.skill_vfx_profile.tip_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light = OmniLight3D.new()
	light.light_color = Style.charged_warning_color
	light.omni_range = Style.charge_light_range
	light.shadow_enabled = false
	add_child(light)
	charge_audio = _audio(Style.charge_sound)
	lock_audio = _audio(Style.lock_sound)

func _audio(stream: AudioStream) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = Style.charge_volume_db
	audio.max_distance = Style.charge_audio_distance
	add_child(audio)
	return audio

func refresh(delta: float = 0.0) -> void:
	var active: bool = brain.actor.health.alive() and brain.state == "windup"
	ring.visible = active and brain.attack_id == "rain"
	if ring.visible: ring.global_position = brain.target_point + Vector3.UP * Style.ground_height
	var charged: bool = active and brain.attack_id == "charged" and not external_charged_cue
	glow.visible = charged
	light.visible = charged
	var audio_paused: bool = delta <= 0.0 or brain.actor.control_locked
	charge_audio.stream_paused = audio_paused
	lock_audio.stream_paused = audio_paused
	if charged:
		var progress: float = clampf(1.0 - brain.time_left / brain.windup_duration, 0.0, 1.0)
		var locked: bool = brain.time_left <= brain.config.charged_lock_sec
		glow.position = Vector3.UP * brain.config.arrow_height_m + brain.locked_direction * brain.config.arrow_spawn_forward_m
		glow.scale = Vector3.ONE * progress
		light.position = glow.position
		light.light_energy = progress * Style.charge_light_energy
		charge_audio.position = glow.position
		lock_audio.position = glow.position
		charge_audio.pitch_scale = lerpf(Style.charge_pitch_range.x, Style.charge_pitch_range.y, progress)
		if delta > 0.0 and _charge_cast != brain.cast_id:
			_charge_cast = brain.cast_id
			charge_audio.play()
		if delta > 0.0 and locked and _lock_cast != brain.cast_id:
			_lock_cast = brain.cast_id
			lock_audio.play()
	else:
		charge_audio.stop()
		lock_audio.stop()
	var count := int(brain.config.volley_count) if brain.attack_id == "volley" else 1
	for i in lines.size():
		lines[i].visible = active and brain.attack_id != "rain" and i < count and not (external_charged_cue and brain.attack_id=="charged")
		if not lines[i].visible: continue
		var suffix := "_locked" if brain.time_left <= brain.config[brain.attack_id + "_lock_sec"] else ""
		lines[i].mesh = strips[brain.attack_id + suffix]
		var spread := deg_to_rad(brain.config.volley_angle_deg) * (float(i) / (count - 1) - 0.5) if count > 1 else 0.0
		lines[i].rotation.y = atan2(-brain.locked_direction.x, -brain.locked_direction.z) + spread
