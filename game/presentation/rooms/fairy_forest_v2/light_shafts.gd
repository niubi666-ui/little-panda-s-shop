extends Node3D
## 光柱：按配置在若干落点各立一道发光片（见 light_shaft.gdshader）。
## 落点和粗细在场景里配；太阳方向由房间脚本传入，保证和真实阴影一致。

## 每道光柱一项：x、z 为地面落点，y 为这一道的粗细倍数
@export var beams: PackedVector3Array
## 每道光柱的强度倍数，与 beams 一一对应（数量不能少于 beams）
@export var beam_strengths: PackedFloat32Array
@export var material: ShaderMaterial

func build(to_sun: Vector3) -> void:
	for child in get_children(): child.queue_free()
	if material == null: return
	assert(beam_strengths.size() >= beams.size(), "LightShafts: beam_strengths shorter than beams")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	# 侧向任取一个与太阳方向垂直的轴；真正的朝向在着色器里按镜头位置算
	var side := to_sun.cross(Vector3.FORWARD).normalized()
	var basis := Basis(side, to_sun, side.cross(to_sun))
	for index in beams.size():
		var beam := beams[index]
		var node := MeshInstance3D.new()
		node.name = "Shaft%d" % index
		node.mesh = quad
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.transform = Transform3D(basis, Vector3(beam.x, 0.0, beam.z))
		# 网格只是一张单位片，实际位置在着色器里展开：把包围盒放大，避免被错误裁剪
		node.extra_cull_margin = 40.0
		node.set_instance_shader_parameter("seed", float(index) * 0.37)
		node.set_instance_shader_parameter("scale_width", beam.y)
		node.set_instance_shader_parameter("scale_strength", beam_strengths[index])
		add_child(node)
