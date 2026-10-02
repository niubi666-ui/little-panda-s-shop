extends RefCounted
var actor
var camera: Camera3D
func _init(player, view_camera: Camera3D) -> void:
	actor = player
	camera = view_camera
func update() -> void:
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
	if event.is_action_pressed("combat_attack") and not event.is_echo(): actor.request_attack()
	if event.is_action_pressed("combat_dodge") and not event.is_echo(): actor.request_dodge()
