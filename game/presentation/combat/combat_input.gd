extends RefCounted
var actor
var camera: Camera3D
var _blocked: Callable
func _init(player, view_camera: Camera3D, blocked: Callable = Callable()) -> void:
	actor = player
	camera = view_camera
	_blocked = blocked
func update() -> void:
	if _ui_blocked() or _focused_ui() != null:
		actor.movement = Vector3.ZERO
		actor.clear_intents()
		return
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := camera.global_basis.x
	var forward := camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	actor.movement = (right.normalized() * axes.x + forward.normalized() * axes.y).limit_length()
	var mouse := camera.get_viewport().get_mouse_position()
	var ray := camera.project_ray_normal(mouse)
	var origin := camera.project_ray_origin(mouse)
	var hit = Plane(Vector3.UP, actor.global_position.y).intersects_ray(origin, ray)
	if hit != null:
		var offset: Vector3 = hit - actor.global_position
		offset.y = 0.0
		if not offset.is_zero_approx(): actor.facing = offset.normalized()
func event(event: InputEvent) -> void:
	if _ui_blocked():
		actor.movement = Vector3.ZERO
		actor.clear_intents()
		return
	var focused := _focused_ui()
	if focused != null:
		actor.movement = Vector3.ZERO
		actor.clear_intents()
		# This receives unhandled arena clicks; the first click returns focus to play.
		if event is InputEventMouseButton and event.pressed: focused.release_focus()
		return
	if event.is_echo(): return
	if event.is_action_pressed("combat_dodge"): actor.request_dodge()
	if event.is_action_pressed("combat_special"): actor.request_action("special")
	if event.is_action_pressed("combat_attack"): actor.request_action("primary")
func _focused_ui() -> Control:
	var owner := camera.get_viewport().gui_get_focus_owner()
	return owner if owner != null and owner.is_visible_in_tree() else null
func _ui_blocked() -> bool:
	return _blocked.is_valid() and bool(_blocked.call())
