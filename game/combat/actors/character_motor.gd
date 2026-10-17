extends RefCounted
## Sole movement writer: knockback overrides voluntary motion and uses body collision.
var body: CharacterBody3D
var _impulse := Vector3.ZERO
var _impulse_duration := 0.0
var impulse_left := 0.0
var _push := Vector3.ZERO
var _push_duration := 0.0
var push_left := 0.0
var blocked := false
var control_scale := 1.0
var control_locked := false
func _init(actor: CharacterBody3D) -> void: body = actor
func knockback(direction: Vector3, speed: float, duration: float) -> void:
	if speed <= 0.0 or duration <= 0.0: return
	_impulse = direction.normalized() * speed
	_impulse_duration = duration
	impulse_left = duration
func push(direction: Vector3, speed: float, duration: float) -> void:
	if speed <= 0.0 or duration <= 0.0: return
	_push = direction.normalized() * speed
	_push_duration = duration
	push_left = duration
func clear_impulse() -> void:
	_impulse = Vector3.ZERO
	impulse_left = 0.0
	_push = Vector3.ZERO
	push_left = 0.0

func travel(displacement: Vector3, delta: float) -> void:
	# Distance-driven committed dash: use a swept body collision, never teleport or slide.
	blocked = false
	if delta <= 0.0: return
	if control_locked:
		body.velocity = Vector3.ZERO
		return
	clear_impulse()
	var before := body.global_position
	blocked = body.move_and_collide(displacement) != null if not displacement.is_zero_approx() else false
	body.velocity = (body.global_position - before) / delta

func step(direction: Vector3, speed: float, delta: float, slide: bool = true) -> void:
	blocked = false
	if control_locked:
		clear_impulse()
		body.velocity = Vector3.ZERO
		return
	body.velocity = direction * speed * control_scale
	if impulse_left > 0.0 and delta > 0.0:
		# Average a linearly decaying impulse over this step, including its last fraction.
		var consumed := minf(delta, impulse_left)
		var remaining := impulse_left - consumed
		body.velocity = _impulse * ((impulse_left + remaining) / (2.0 * _impulse_duration)) * (consumed / delta)
		impulse_left = remaining
	if push_left > 0.0 and delta > 0.0:
		# 出招前冲：叠加在自主移动上，不夺走方向控制
		var used := minf(delta, push_left)
		body.velocity += _push * (push_left / _push_duration) * (used / delta)
		push_left -= used
	if slide:
		body.move_and_slide()
		blocked = body.get_slide_collision_count() > 0
	else:
		# Committed straight movement must stop at contact, never slide around cover.
		blocked = body.move_and_collide(body.velocity * delta) != null
