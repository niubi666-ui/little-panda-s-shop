extends RefCounted
## 把角色材质套到一个模型的所有网格表面上，返回每个表面各自的材质实例。
## keep_textures：模型自带贴图（例如 AI 生成的模型）时保留贴图，只统一光照、轮廓光和受击闪白。
## 用的是“表面覆盖材质”，不占用 material_override，所以 HitFeedback 的闪白替换照常工作。
static func apply(root: Node, material: ShaderMaterial, keep_textures: bool, tint := Color.WHITE) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	if material == null: return result
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var instance: ShaderMaterial = material.duplicate()
			if keep_textures:
				var source: Material = mesh.mesh.surface_get_material(surface)
				if source is BaseMaterial3D:
					instance.set_shader_parameter("use_vertex_color", false)
					instance.set_shader_parameter("tint", Vector3(source.albedo_color.r * tint.r, source.albedo_color.g * tint.g, source.albedo_color.b * tint.b))
					if source.albedo_texture != null:
						instance.set_shader_parameter("albedo_tex", source.albedo_texture)
					# 以下参数只有写实材质（shared/pbr）才有；toon 材质会忽略
					# 没有贴图但带顶点色的表面（色块道具）：导入器不会自动打开“顶点色当底色”，这里按网格判断
					var painted: bool = source.albedo_texture == null and (mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
					instance.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo or painted)
					instance.set_shader_parameter("roughness", source.roughness)
					instance.set_shader_parameter("metallic", source.metallic)
					if source.normal_enabled and source.normal_texture != null:
						instance.set_shader_parameter("normal_tex", source.normal_texture)
						instance.set_shader_parameter("use_normal_tex", true)
			mesh.set_surface_override_material(surface, instance)
			result.append(instance)
	return result
