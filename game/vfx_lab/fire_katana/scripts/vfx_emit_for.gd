extends GPUParticles3D
## 持续发射一段时间再停（余火这类“烧一会儿”的层）。play() 时把朝向摆正，交叉面片保持竖直。

@export var duration := 1.5


func play() -> void:
	global_basis = Basis()
	restart()
	emitting = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		emitting = false
