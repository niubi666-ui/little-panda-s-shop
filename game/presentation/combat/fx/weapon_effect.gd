extends Node3D
## Swappable presentation API. The trail follows the sword midpoint in world space.
@export var trail_material: Material
@export var trail_width: float
@export var trail_lifetime_sec: float
@export var trail_min_distance: float
var _active := false
var _running := true
var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _trail: MeshInstance3D
func _ready() -> void:
	_trail = MeshInstance3D.new()
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
func set_active(active: bool) -> void:
	_active = active
	$Particles.emitting = active
	$Core.visible = active
func set_time_running(running: bool) -> void:
	_running = running
	$Particles.speed_scale = 1.0 if running else 0.0
func _process(delta: float) -> void:
	if not _running: return
	for i in range(_ages.size() - 1, -1, -1):
		_ages[i] += delta
		if _ages[i] > trail_lifetime_sec:
			_ages.remove_at(i)
			_points.remove_at(i)
	if _active and (_points.is_empty() or _points.back().distance_to(global_position) >= trail_min_distance):
		_points.append(global_position)
		_ages.append(0.0)
	_trail.visible = _points.size() > 1
	if not _trail.visible: return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, trail_material)
	for i in range(1, _points.size()):
		var width := Vector3.UP * trail_width / 2.0
		var a := _points[i - 1]
		var b := _points[i]
		var color_a := Color(1, 1, 1, 1.0 - _ages[i - 1] / trail_lifetime_sec)
		var color_b := Color(1, 1, 1, 1.0 - _ages[i] / trail_lifetime_sec)
		for vertex in [a - width, a + width, b + width]:
			mesh.surface_set_color(color_b if vertex == b + width else color_a)
			mesh.surface_add_vertex(vertex)
		for vertex in [a - width, b + width, b - width]:
			mesh.surface_set_color(color_a if vertex == a - width else color_b)
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	_trail.mesh = mesh
