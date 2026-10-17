extends Node3D
## 木桩挨打：往受力方向晃一下再回弹（阻尼弹簧）。

@export var kick := 0.07
@export var stiffness := 260.0
@export var damping := 14.0

var _angle := 0.0
var _vel := 0.0
var _axis := Vector3.RIGHT


func hit(push_dir: Vector3, strength: float) -> void:
	var flat := Vector3(push_dir.x, 0.0, push_dir.z)
	if flat.length_squared() < 1e-6:
		return
	_axis = Vector3.UP.cross(flat.normalized()).normalized()
	_vel += kick * strength * 30.0


func _process(delta: float) -> void:
	var acc := -stiffness * _angle - damping * _vel
	_vel += acc * delta
	_angle += _vel * delta
	basis = Basis(_axis, _angle) if absf(_angle) > 1e-5 else Basis()
