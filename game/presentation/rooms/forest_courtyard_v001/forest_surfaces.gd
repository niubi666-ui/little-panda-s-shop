extends "res://rogue/rooms/authored_room.gd"
## Blender-specific surface adapters only. Does not own encounters or room selection.
@export var wet_paving: ShaderMaterial
@export var water: Material
@export var paving_casts_shadow: bool
func rift_surfaces() -> Array:
	var result: Array=[]
	for visual in $Art.find_children("*","MeshInstance3D",true,false):
		if visual.name.begins_with("Courtyard_Item2_Paving_") or visual.name.begins_with("Roundel_") or visual.name.begins_with("Peripheral_reflecting_rain_pool_") or visual.name in ["Courtyard_foundation","Continuous_forest_valley_ground"]:result.append(visual)
	return result
func _ready() -> void:
	var replacements: Dictionary = {}
	for visual in $Art.find_children("*", "MeshInstance3D", true, false):
		for surface in visual.mesh.get_surface_count():
			var material: Material = visual.get_active_material(surface)
			if material == null: continue
			if material.resource_name == "Item2_paving_dry_and_wet_limestone":
				visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if paving_casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if not replacements.has(material):
					var replacement: ShaderMaterial = wet_paving.duplicate()
					replacement.set_shader_parameter("surface_color", material.albedo_texture)
					replacements[material] = replacement
				visual.set_surface_override_material(surface, replacements[material])
			elif material.resource_name == "Rainwater_thin_Fresnel_film":
				visual.set_surface_override_material(surface, water)
		if visual.name.begins_with("Roundel_") and not paving_casts_shadow:
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
