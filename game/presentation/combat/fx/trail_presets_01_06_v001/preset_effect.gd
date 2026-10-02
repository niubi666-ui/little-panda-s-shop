extends "res://presentation/combat/fx/slash_candidates_v002/ribbon_effect.gd"
@export var radial_subdivisions: int
@export var noise_frame_rate: float
var _visual_clock := 0.0
func _ready() -> void:
	assert(radial_subdivisions > 0 and noise_frame_rate >= 0.0)
	ribbon_material = ribbon_material.duplicate()
	super._ready()
func _process(delta: float) -> void:
	if _running: _visual_clock += delta * _speed
	ribbon_material.set_shader_parameter("frame_phase", _visual_clock * noise_frame_rate)
	super._process(delta)
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
			for row in radial_subdivisions:
				var v0 := float(row) / radial_subdivisions
				var v1 := float(row + 1) / radial_subdivisions
				_write(i-1,Vector2(u0,v0)); _write(i-1,Vector2(u0,v1)); _write(i,Vector2(u1,v1))
				_write(i-1,Vector2(u0,v0)); _write(i,Vector2(u1,v1)); _write(i,Vector2(u1,v0))
		first = last + 1
	_mesh.surface_end()
func _write(index: int, uv: Vector2) -> void:
	var fade := pow(clampf(1.0-_ages[index]/tail_lifetime_sec,0.0,1.0),fade_power)
	_mesh.surface_set_color(Color(1,1,1,fade))
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(_roots[index].lerp(_tips[index],uv.y))
