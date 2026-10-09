extends Node3D
## Standalone static art adapter; no room/encounter/gameplay dependency.
@export var wet_paving: ShaderMaterial
@export var water: Material
@export var paving_casts_shadow: bool
var floor_materials: Array[ShaderMaterial]=[]
var cut_surfaces: Array[String]=[]
func _ready() -> void:
	var replacements: Dictionary={}
	for visual in $Art.find_children("*","MeshInstance3D",true,false):
		for surface in visual.mesh.get_surface_count():
			var material: Material=visual.get_active_material(surface)
			if material==null: continue
			if material.resource_name=="Item2_paving_dry_and_wet_limestone" or visual.name.begins_with("Roundel_"):
				visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if paving_casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if not replacements.has(material):
					var replacement: ShaderMaterial=wet_paving.duplicate()
					replacement.set_shader_parameter("surface_color",material.albedo_texture)
					replacement.set_shader_parameter("use_texture",material.albedo_texture!=null)
					replacement.set_shader_parameter("base_tint",material.albedo_color)
					replacements[material]=replacement
					floor_materials.append(replacement)
				visual.set_surface_override_material(surface,replacements[material])
				cut_surfaces.append(str(visual.name))
			elif visual.name in ["Courtyard_foundation","Continuous_forest_valley_ground"]:
				var replacement:=_underlay(material,false)
				visual.set_surface_override_material(surface,replacement)
				cut_surfaces.append(str(visual.name))
			elif material.resource_name=="Rainwater_thin_Fresnel_film":
				visual.set_surface_override_material(surface,_underlay(water,true))
				cut_surfaces.append(str(visual.name))
		if visual.name.begins_with("Roundel_") and not paving_casts_shadow:
			visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _underlay(original: StandardMaterial3D, is_water: bool) -> ShaderMaterial:
	var replacement:=ShaderMaterial.new()
	replacement.shader=preload("res://fx/rift_water.gdshader") if is_water else preload("res://fx/rift_underlay.gdshader")
	replacement.set_shader_parameter("base_tint",original.albedo_color)
	replacement.set_shader_parameter("surface_color",original.albedo_texture)
	replacement.set_shader_parameter("use_texture",original.albedo_texture!=null)
	replacement.set_shader_parameter("roughness_value",original.roughness)
	replacement.set_shader_parameter("metallic_value",original.metallic)
	if is_water:
		replacement.set_shader_parameter("coat",original.clearcoat)
		replacement.set_shader_parameter("coat_roughness",original.clearcoat_roughness)
	floor_materials.append(replacement)
	return replacement

func set_rift_contour(contour: Texture2D, length_m: float) -> void:
	for material in floor_materials:
		material.set_shader_parameter("rift_contour",contour)
		material.set_shader_parameter("rift_length",length_m)

func set_rift(origin: Vector3, direction: Vector3, travelled_m: float, half_width_m: float, _art: Resource) -> void:
	for material in floor_materials:
		material.set_shader_parameter("rift_origin",Vector2(origin.x,origin.z))
		material.set_shader_parameter("rift_direction",Vector2(direction.x,direction.z))
		material.set_shader_parameter("rift_travel",travelled_m)
		material.set_shader_parameter("rift_half_width",half_width_m)
		material.set_shader_parameter("rift_active",half_width_m>0.0)
