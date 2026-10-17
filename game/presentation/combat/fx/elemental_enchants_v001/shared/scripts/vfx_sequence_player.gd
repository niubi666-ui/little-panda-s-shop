extends Node3D
## Runtime layers share the combat presentation clock, including pause and hit stop.
@export var timeline: Resource
@export var autoplay := false
@export var ground_offset := 0.025
var _age := 0.0
var _fired: Dictionary = {}
var _layers: Array[Node] = []
var _particles: Array[GPUParticles3D] = []
var _materials: Array[ShaderMaterial] = []
var _positioned := false

func _ready() -> void:
	for node in find_children("*", "", true, false):
		if node is GPUParticles3D:
			_particles.append(node)
			node.speed_scale = 0.0
			if node.material_override is ShaderMaterial:
				node.material_override = node.material_override.duplicate()
				_materials.append(node.material_override)
		if node.has_method("tick"): _layers.append(node)

func effect_lifetime() -> float:
	return timeline.lifetime

func sync_effect(fact: Dictionary, delta: float) -> void:
	for node in _particles:
		node.speed_scale = 1.0 if delta > 0.0 else 0.0
	if delta <= 0.0: return
	if not _positioned:
		_positioned = true
		var y: Vector3 = fact.direction.normalized()
		if not y.is_zero_approx() and absf(y.dot(Vector3.UP)) < 0.99:
			var x := Vector3.UP.cross(y).normalized()
			global_basis = Basis(x, y, x.cross(y))
		for node in get_children():
			if node is Decal:
				node.global_basis = Basis.IDENTITY
				node.global_position = fact.ground_position + Vector3.UP * ground_offset
	_age += delta
	for layer_name in timeline.delays:
		if _fired.has(layer_name) or _age < float(timeline.delays[layer_name]): continue
		_fired[layer_name] = true
		var node := get_node(NodePath(layer_name))
		if node.has_method("play"): node.play()
		elif node is GPUParticles3D:
			node.restart()
			node.emitting = true
	for layer in _layers: layer.tick(delta)
	for material in _materials: material.set_shader_parameter("effect_time", _age)
