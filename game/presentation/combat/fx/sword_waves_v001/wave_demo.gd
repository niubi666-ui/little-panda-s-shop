extends Node3D
## Authored rehearsal path only. Actual projectiles are moved by combat snapshots.
const Profile = preload("res://presentation/combat/fx/sword_waves_v001/wave_profile.gd")
@export var profile: Profile
@export var wave_scene: PackedScene
@export var impact_scene: PackedScene
var _time := 0.0
var _running := true
var _speed := 1.0
var _wave: Node3D
var _impact: Node3D
var _launch: MeshInstance3D
var _launch_mat: ShaderMaterial

func _ready() -> void:
	_wave = wave_scene.instantiate()
	add_child(_wave)
	_wave.set_time_running(false)
	_impact = impact_scene.instantiate()
	add_child(_impact)
	_impact.set_time_running(false)
	_impact.position = Vector3(0.0,profile.flight_height,-profile.flight_distance)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*profile.impact_ring_radius*1.4
	_launch = MeshInstance3D.new()
	_launch.mesh = plane
	_launch_mat = profile.ring_material.duplicate() as ShaderMaterial
	_launch.material_override = _launch_mat
	_launch.position.y = 0.04
	_launch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_launch)
	seek_visual(0.0)

func _process(delta: float) -> void:
	if not _running: return
	seek_visual(_time+delta*_speed)
	if _time >= profile.duration_sec: queue_free()

func set_time_running(enabled: bool) -> void:
	_running = enabled

func set_playback_speed(speed: float) -> void:
	assert(is_finite(speed) and speed >= 0.0)
	_speed = speed

func restart() -> void:
	seek_visual(0.0)

func finish() -> void:
	_running = false
	hide()
	queue_free()

func seek_visual(time: float) -> void:
	if _wave == null: return
	_time = clampf(time,0.0,profile.duration_sec)
	var impact_at: float = profile.charge_sec + profile.flight_sec
	_wave.visible = _time < impact_at + profile.trail_exit_sec
	var travel: float = clampf((_time-profile.charge_sec)/profile.flight_sec,0.0,1.0)
	_wave.position = Vector3(0.0,profile.flight_height,-profile.flight_distance*travel)
	_wave.scale = Vector3.ONE*maxf(0.00001,profile.growth_curve.sample_baked(clampf(_time/profile.charge_sec,0.0,1.0)))
	_wave.set_exit_progress(clampf((_time-impact_at)/profile.trail_exit_sec,0.0,1.0))
	_wave.seek_visual(_time)
	_impact.visible = _time >= impact_at and _time < impact_at+profile.burst_duration
	_impact.seek_visual(maxf(0.0,_time-impact_at))
	_launch.visible = _time < profile.charge_sec+profile.impact_flash_duration
	_launch_mat.set_shader_parameter("progress",clampf(_time/(profile.charge_sec+profile.impact_flash_duration),0.0,1.0))
