extends Node3D
## Presentation only. Samples the blade midpoint and blade axis; no hit logic.
@export var ribbon_material: Material
@export var blade_span: float
@export var tail_lifetime_sec: float
@export var sample_distance: float
@export var fade_power: float
var _active := false
var _running := true
var _speed := 1.0
var _stroke := 0
var _centers: Array[Vector3] = []
var _axes: Array[Vector3] = []
var _ages: Array[float] = []
var _strokes: Array[int] = []
var _mesh := ImmediateMesh.new()
var _ribbon: MeshInstance3D

func _ready() -> void:
	assert(ribbon_material != null and blade_span > 0.0 and tail_lifetime_sec > 0.0 and sample_distance > 0.0 and fade_power > 0.0)
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _mesh
	_ribbon.top_level = true
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)
	_ribbon.global_transform = Transform3D.IDENTITY

func set_active(active: bool) -> void:
	if active and not _active: _stroke += 1
	_active = active
	$Particles.emitting = active

func set_time_running(running: bool) -> void:
	_running = running
	$Particles.speed_scale = _speed if running else 0.0

func set_playback_speed(speed: float) -> void:
	assert(speed > 0.0)
	_speed = speed
	$Particles.speed_scale = speed if _running else 0.0

func clear_tail() -> void:
	_active = false
	_centers.clear()
	_axes.clear()
	_ages.clear()
	_strokes.clear()
	_mesh.clear_surfaces()
	$Particles.restart()
	$Particles.emitting = false

func _process(delta: float) -> void:
	if not _running: return
	for i in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta * _speed
		if _ages[i] >= tail_lifetime_sec:
			_ages.remove_at(i)
			_centers.remove_at(i)
			_axes.remove_at(i)
			_strokes.remove_at(i)
	if _active and (_centers.is_empty() or _strokes.back() != _stroke or _centers.back().distance_to(global_position) >= sample_distance):
		_centers.append(global_position)
		_axes.append(global_basis.z.normalized() * blade_span / 2.0)
		_ages.append(0.0)
		_strokes.append(_stroke)
	_mesh.clear_surfaces()
	if _centers.size() < 2: return
	var has_segment := false
	for i in range(1, _strokes.size()):
		if _strokes[i - 1] == _strokes[i]: has_segment = true
	if not has_segment: return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, ribbon_material)
	for i in range(1, _centers.size()):
		if _strokes[i - 1] != _strokes[i]: continue
		var u0 := float(i - 1) / float(_centers.size() - 1)
		var u1 := float(i) / float(_centers.size() - 1)
		_vertex(i - 1, -1.0, Vector2(u0, 0.0))
		_vertex(i - 1, 1.0, Vector2(u0, 1.0))
		_vertex(i, 1.0, Vector2(u1, 1.0))
		_vertex(i - 1, -1.0, Vector2(u0, 0.0))
		_vertex(i, 1.0, Vector2(u1, 1.0))
		_vertex(i, -1.0, Vector2(u1, 0.0))
	_mesh.surface_end()

func _vertex(index: int, side: float, uv: Vector2) -> void:
	var fade := pow(clampf(1.0 - _ages[index] / tail_lifetime_sec, 0.0, 1.0), fade_power)
	_mesh.surface_set_color(Color(1, 1, 1, fade))
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(_centers[index] + _axes[index] * side)
