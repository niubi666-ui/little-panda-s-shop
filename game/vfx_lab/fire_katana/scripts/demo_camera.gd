extends Camera3D
## 演示镜头：几个预设机位（C 切换），右键拖动旋转，滚轮缩放；命中时震一下。

@export var focus := Vector3(-0.2, 1.2, 0.0)
## 每个预设：x = 水平角（度），y = 俯角（度），z = 距离
@export var presets: Array[Vector3] = [Vector3(-12.0, 12.0, 2.5), Vector3(-30.0, 52.0, 5.0), Vector3(35.0, 8.0, 1.8)]
@export var preset_names: PackedStringArray = ["展示视角", "游戏俯视角", "近景"]
@export var shake_decay := 3.5

var preset_index := 0
var _yaw := 0.0
var _pitch := 0.0
var _dist := 3.0
var _trauma := 0.0
var _t := 0.0


func _ready() -> void:
	apply_preset(0)


func apply_preset(i: int) -> void:
	preset_index = posmod(i, presets.size())
	var p := presets[preset_index]
	_yaw = p.x
	_pitch = p.y
	_dist = p.z


func preset_name() -> String:
	return preset_names[preset_index] if preset_index < preset_names.size() else str(preset_index)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_yaw -= event.relative.x * 0.3
		_pitch = clampf(_pitch + event.relative.y * 0.3, -10.0, 80.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(1.0, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(12.0, _dist * 1.1)


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	_t += real_dt
	_trauma = maxf(0.0, _trauma - shake_decay * _trauma * real_dt - 0.02 * real_dt)
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _dist
	var jitter := Vector3(sin(_t * 47.0), sin(_t * 59.0 + 1.3), sin(_t * 53.0 + 2.1)) * _trauma * 0.5
	look_at_from_position(focus + offset + jitter, focus + jitter * 0.5, Vector3.UP)
