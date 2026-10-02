extends Node
## Injected camera rig: never owns player movement or furniture interaction.
const Settings = preload("res://presentation/shop_preview/shop_camera_settings.gd")
var _camera: Camera3D
var _target: Node3D
var _settings: Settings
var _desired_size: float
var _focus: Vector3
var _offset: Vector3
var _decorating := false
var _decoration_focus: Vector3
var _previous_size: float
var _overview_size: float

func _init() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func configure(camera: Camera3D, target: Node3D, settings: Settings) -> Error:
	if _camera != null or camera == null or target == null or settings == null or not settings.is_valid():
		return ERR_INVALID_PARAMETER
	_camera = camera
	_target = target
	_settings = settings
	_desired_size = settings.initial_size
	_camera.size = _desired_size
	_offset = camera.global_basis.z * settings.camera_distance
	_focus = target_focus()
	_camera.global_position = _focus + _offset
	set_process(true)
	set_process_unhandled_input(true)
	return OK

func set_decoration_view(active: bool, focus: Vector3, overview_size: float) -> void:
	if active == _decorating: return
	_decorating = active
	if active:
		_previous_size = _desired_size
		_decoration_focus = focus
		_desired_size = overview_size
		_overview_size = overview_size
	else:
		_desired_size = _previous_size

func target_focus() -> Vector3:
	if _decorating: return _decoration_focus
	var position := _target.global_position
	var bounds := _settings.focus_bounds
	return Vector3(clampf(position.x, bounds.position.x, bounds.end.x), _settings.focus_height, clampf(position.z, bounds.position.y, bounds.end.y))

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	_focus = _focus.lerp(target_focus(), 1.0 - exp(-_settings.follow_response * delta))
	_camera.global_position = _focus + _offset
	_camera.size = lerpf(_camera.size, _desired_size, 1.0 - exp(-_settings.zoom_response * delta))

func _unhandled_input(event: InputEvent) -> void:
	var direction := 0.0
	if event.is_action_pressed("camera_zoom_in"):
		direction = -1.0
	elif event.is_action_pressed("camera_zoom_out"):
		direction = 1.0
	else:
		return
	_desired_size = clampf(_desired_size + direction * _settings.zoom_step, _settings.minimum_size, maxf(_settings.maximum_size, _overview_size) if _decorating else _settings.maximum_size)
	get_viewport().set_input_as_handled()
