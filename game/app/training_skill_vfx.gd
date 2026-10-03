extends Node
## Pure presentation rehearsal; no ability, damage, status, save or gameplay RNG access.
const Picker = preload("res://presentation/combat/skill_vfx_picker/skill_vfx_picker.gd")

var panel: Control
var active: Array[Node3D] = []
var selected_id: StringName
var _world: Node3D
var _player: Node3D
var _direction: Callable
var _allowed: Callable
var _style: Resource

func configure(world: Node3D, player: Node3D, direction: Callable, allowed: Callable, ui: Node, shared_theme: Theme, style: Resource) -> void:
	assert(world != null and player != null and direction.is_valid() and allowed.is_valid())
	assert(style != null and style.valid())
	_world = world
	_player = player
	_direction = direction
	_allowed = allowed
	_style = style
	panel = Picker.new()
	ui.add_child(panel)
	panel.configure(style, shared_theme)
	panel.effect_requested.connect(cast)
	panel.replay_requested.connect(replay)
	panel.clear_requested.connect(clear)
	refresh()

func cast(id: StringName) -> bool:
	if not _allowed.call() or not _style.effects.has(id): return false
	var forward: Vector3 = _direction.call()
	forward.y = 0.0
	if not forward.is_finite() or forward.is_zero_approx(): return false
	forward = forward.normalized()
	var effect: Node3D = _style.effects[id].instantiate() as Node3D
	if effect == null: return false
	for method in [&"set_time_running", &"finish", &"restart"]:
		if not effect.has_method(method):
			push_error("Training skill VFX is missing " + String(method) + ": " + String(id))
			effect.free()
			return false
	_prune()
	while active.size() >= _style.max_instances:
		_dispose(active.pop_front())
	var origin: Vector3 = _player.global_position + forward * _style.forward_offset_m + Vector3.UP * _style.ground_offset_m
	effect.transform = _world.global_transform.affine_inverse() * Transform3D(Basis.looking_at(forward, Vector3.UP), origin)
	_world.add_child(effect)
	effect.set_time_running(true)
	active.append(effect)
	selected_id = id
	panel.set_selected(id)
	return true

func replay() -> bool:
	if selected_id.is_empty(): return false
	return cast(selected_id)

func refresh() -> void:
	_prune()
	var running: bool = _allowed.call()
	for effect in active: effect.set_time_running(running)
	panel.set_available(running)

func set_time_running(running: bool) -> void:
	_prune()
	for effect in active: effect.set_time_running(running)
	panel.set_available(running and _allowed.call())

func clear() -> void:
	for effect in active: _dispose(effect)
	active.clear()

func _dispose(effect: Node3D) -> void:
	if not is_instance_valid(effect) or effect.is_queued_for_deletion(): return
	effect.finish()
	# Removal is deterministic even if an alternate visual implements a tail in finish().
	if is_instance_valid(effect) and not effect.is_queued_for_deletion(): effect.queue_free()

func _prune() -> void:
	for index in range(active.size() - 1, -1, -1):
		if not is_instance_valid(active[index]) or active[index].is_queued_for_deletion(): active.remove_at(index)

func refresh_text() -> void:
	panel.refresh_text()

func _exit_tree() -> void:
	clear()
