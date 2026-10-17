extends Node3D
## 按时间表依次触发子层：GPUParticles3D 重新发射，其它节点调用 play()。

@export var timeline: Resource
@export var autoplay := false


func _ready() -> void:
	if autoplay:
		play()


func play() -> void:
	assert(timeline != null)
	for layer_name in timeline.delays:
		var node := get_node_or_null(NodePath(layer_name))
		if node == null:
			push_warning("vfx layer missing: %s" % layer_name)
			continue
		_fire_after(node, float(timeline.delays[layer_name]))
	if timeline.lifetime > 0.0:
		get_tree().create_timer(timeline.lifetime).timeout.connect(queue_free)


func _fire_after(node: Node, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(node):
		return
	if node.has_method("play"):
		node.play()
	elif node is GPUParticles3D:
		node.restart()
		node.emitting = true
