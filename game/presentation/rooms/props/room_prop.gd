extends StaticBody3D
## Adapter to melee's existing damage target protocol; not an enemy or Build proc target.
const Health = preload("res://combat/actors/health_runtime.gd")
const BreakEffect = preload("res://presentation/rooms/props/break_effect.tscn")
var entry: Dictionary
var definition: Dictionary
var health
var team := -1
var handle: int
var _commit_destroy: Callable
var _visual: Node3D
var searched := false
var bounds: Vector3
func configure(placement: Dictionary, prop_definition: Dictionary, visual: Resource, target_handle: int, commit_destroy: Callable) -> void:
	entry = placement
	definition = prop_definition
	bounds = visual.bounds
	handle = target_handle
	_commit_destroy = commit_destroy
	if definition.kind == "destructible": health = Health.new(definition.health)
	collision_layer = 1
	collision_mask = 0
	position = Vector3(entry.position[0], entry.position[1], entry.position[2])
	rotation.y = entry.yaw_radians
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds
	shape.shape = box
	shape.position.y = bounds.y / 2.0
	add_child(shape)
	_visual = visual.scene.instantiate()
	add_child(_visual)
func receive_hit(amount: float) -> float:
	if health == null or not health.alive() or amount <= 0.0: return 0.0
	if amount >= health.current and not _commit_destroy.call(entry.id): return 0.0
	var applied: float = health.apply(amount, false)
	if not health.alive():
		collision_layer = 0
		_visual.hide()
		var fragments := BreakEffect.instantiate()
		add_child(fragments)
		fragments.position.y = bounds.y / 2.0
		fragments.finished.connect(fragments.queue_free)
		fragments.emitting = true
	return applied
func apply_knockback(_direction: Vector3, _speed: float, _duration: float) -> void: pass
func mark_searched() -> void:
	searched = true
	# Keep the container and collision present after looting; no invented lid animation.
func surface_point(world_point: Vector3) -> Vector3:
	var local := to_local(world_point)
	return to_global(Vector3(clampf(local.x, -bounds.x / 2.0, bounds.x / 2.0), local.y, clampf(local.z, -bounds.z / 2.0, bounds.z / 2.0)))
