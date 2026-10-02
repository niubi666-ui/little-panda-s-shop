extends Node3D
## Sword root/tip sweep in world space. Presentation only; never resolves hits.
@export var ribbon_material: Material
@export var root_inset_ratio: float
@export var tip_extension_ratio: float
@export var tail_lifetime_sec: float
@export var sample_distance: float
@export var max_segment_angle_deg: float
@export var fade_power: float
var _blade_length := 0.0
var _active := false
var _running := true
var _speed := 1.0
var _stroke := 0
var _start_pending := false
var _end_pending := false
var _have_previous := false
var _previous := Transform3D.IDENTITY
var _roots: Array[Vector3] = []
var _tips: Array[Vector3] = []
var _ages: Array[float] = []
var _strokes: Array[int] = []
var _mesh := ImmediateMesh.new()
var _ribbon: MeshInstance3D

func _ready() -> void:
	assert(ribbon_material != null and tail_lifetime_sec > 0.0 and sample_distance > 0.0 and max_segment_angle_deg > 0.0 and fade_power > 0.0)
	assert(root_inset_ratio >= 0.0 and root_inset_ratio < 1.0 and tip_extension_ratio >= 0.0)
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _mesh
	_ribbon.top_level = true
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)
	_ribbon.global_transform = Transform3D.IDENTITY

## Adapter injects real blade length; no independent sword length default.
func configure_blade(length: float) -> void:
	assert(length > 0.0)
	_blade_length = length
	$Particles.position.z = -length / 2.0

func set_active(active: bool) -> void:
	if active and not _active:
		_stroke += 1
		_start_pending = true
		_end_pending = false
	elif not active and _active:
		_end_pending = true
	_active = active
	$Particles.emitting = active

func set_time_running(running: bool) -> void:
	_running = running
	$Particles.speed_scale = _speed if running else 0.0

func set_playback_speed(speed: float) -> void:
	assert(speed > 0.0)
	_speed = speed
	$Particles.speed_scale = speed if _running else 0.0

func sample_current_pose() -> void:
	_process(0.0)

func finish_at_current_pose() -> void:
	if _active:
		set_active(false)
		sample_current_pose()

func clear_tail() -> void:
	_active = false
	_start_pending = false
	_end_pending = false
	_have_previous = false
	_roots.clear()
	_tips.clear()
	_ages.clear()
	_strokes.clear()
	_mesh.clear_surfaces()
	$Particles.restart()
	$Particles.emitting = false

func _process(delta: float) -> void:
	if not _running: return
	assert(_blade_length > 0.0, "configure_blade(length) must be called by the presentation adapter")
	for i in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta * _speed
		if _ages[i] >= tail_lifetime_sec:
			_ages.remove_at(i)
			_roots.remove_at(i)
			_tips.remove_at(i)
			_strokes.remove_at(i)
	var current := global_transform.orthonormalized()
	if _start_pending:
		_append(_previous if _have_previous else current, delta * _speed)
		_start_pending = false
	if _active or _end_pending:
		var tip := _tip(current)
		if _have_previous and not _tips.is_empty() and _strokes.back() == _stroke and (_tips.back().distance_to(tip) >= sample_distance or _end_pending):
			var from_rotation := _previous.basis.get_rotation_quaternion()
			var to_rotation := current.basis.get_rotation_quaternion()
			var steps := maxi(1, ceili(rad_to_deg(from_rotation.angle_to(to_rotation)) / max_segment_angle_deg))
			for step in range(1, steps + 1):
				var fraction := float(step) / float(steps)
				var transform := Transform3D(Basis(from_rotation.slerp(to_rotation, fraction)), _previous.origin.lerp(current.origin, fraction))
				_append(transform, delta * _speed * (1.0 - fraction))
		elif _tips.is_empty() or _strokes.back() != _stroke:
			_append(current, 0.0)
	_end_pending = false
	_previous = current
	_have_previous = true
	_rebuild()

func _tip(transform: Transform3D) -> Vector3:
	return transform * (Vector3.FORWARD * _blade_length * (0.5 + tip_extension_ratio))

func _append(transform: Transform3D, age: float) -> void:
	_roots.append(transform * (Vector3.BACK * _blade_length * (0.5 - root_inset_ratio)))
	_tips.append(_tip(transform))
	_ages.append(age)
	_strokes.append(_stroke)

func _rebuild() -> void:
	_mesh.clear_surfaces()
	var has_segment := false
	for i in range(1, _strokes.size()):
		if _strokes[i - 1] == _strokes[i]: has_segment = true
	if not has_segment: return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, ribbon_material)
	var first := 0
	while first < _strokes.size():
		var last := first
		while last + 1 < _strokes.size() and _strokes[last + 1] == _strokes[first]: last += 1
		for i in range(first + 1, last + 1):
			var u0 := float(i - 1 - first) / float(last - first)
			var u1 := float(i - first) / float(last - first)
			_vertex(i - 1, false, Vector2(u0, 0.0))
			_vertex(i - 1, true, Vector2(u0, 1.0))
			_vertex(i, true, Vector2(u1, 1.0))
			_vertex(i - 1, false, Vector2(u0, 0.0))
			_vertex(i, true, Vector2(u1, 1.0))
			_vertex(i, false, Vector2(u1, 0.0))
		first = last + 1
	_mesh.surface_end()

func _vertex(index: int, tip: bool, uv: Vector2) -> void:
	var fade := pow(clampf(1.0 - _ages[index] / tail_lifetime_sec, 0.0, 1.0), fade_power)
	_mesh.surface_set_color(Color(1, 1, 1, fade))
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(_tips[index] if tip else _roots[index])
