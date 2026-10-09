extends Node3D
## Injected render surfaces only. No room search, collisions or gameplay queries.
const CAPACITY:=16
const Wet=preload("res://presentation/combat/fx/charged_arrow_v001/wet_paving.gdshader")
const Solid=preload("res://presentation/combat/fx/charged_arrow_v001/rift_underlay.gdshader")
const Water=preload("res://presentation/combat/fx/charged_arrow_v001/rift_water.gdshader")
var materials: Array[ShaderMaterial]=[]
var originals: Array=[]
var entries: Dictionary={}
var origins: PackedVector4Array
var paths: PackedVector4Array
var pixels: Image
var atlas: ImageTexture
class Token extends Node3D:
	var manager
	var contour: Texture2D
	var length_m: float
	var slot: int=-1
	func set_rift_contour(texture: Texture2D, length: float) -> void:
		contour=texture;length_m=length
	func set_rift(point: Vector3, direction: Vector3, travelled: float, width: float, _art: Resource) -> void:
		if width<=0.0:
			if slot>=0:manager.release(slot);slot=-1
			return
		if slot<0:slot=manager.allocate(contour)
		manager.update_cut(slot,point,direction,travelled,width,length_m)
	func _exit_tree() -> void:
		if is_instance_valid(manager) and slot>=0:manager.release(slot)

func configure(surfaces: Array, samples: int) -> void:
	origins.resize(CAPACITY);paths.resize(CAPACITY)
	pixels=Image.create(samples,CAPACITY,false,Image.FORMAT_RGF)
	atlas=ImageTexture.create_from_image(pixels)
	for visual: MeshInstance3D in surfaces:
		for surface in visual.mesh.get_surface_count():
			var original: Material=visual.get_active_material(surface)
			var material:=ShaderMaterial.new()
			if original is ShaderMaterial:
				material.shader=Wet
				for field in original.shader.get_shader_uniform_list():
					material.set_shader_parameter(field.name,original.get_shader_parameter(field.name))
				material.set_shader_parameter("use_texture",true)
				material.set_shader_parameter("base_tint",Color.WHITE)
			elif original is StandardMaterial3D:
				var water: bool=original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
				material.shader=Water if water else Solid
				material.set_shader_parameter("base_tint",original.albedo_color)
				material.set_shader_parameter("surface_color",original.albedo_texture)
				material.set_shader_parameter("use_texture",original.albedo_texture!=null)
				material.set_shader_parameter("roughness_value",original.roughness)
				material.set_shader_parameter("metallic_value",original.metallic)
				if water:
					material.set_shader_parameter("coat",original.clearcoat)
					material.set_shader_parameter("coat_roughness",original.clearcoat_roughness)
			else:continue
			originals.append([visual,surface,visual.get_surface_override_material(surface)])
			visual.set_surface_override_material(surface,material)
			material.set_shader_parameter("rift_contours",atlas)
			materials.append(material)
	flush()

func token() -> Token:
	var result:=Token.new();result.manager=self;add_child(result);return result
func allocate(contour: Texture2D) -> int:
	for i in CAPACITY:
		if entries.has(i):continue
		entries[i]=true
		pixels.blit_rect(contour.get_image(),Rect2i(0,0,pixels.get_width(),1),Vector2i(0,i))
		atlas.update(pixels)
		return i
	assert(false,"Charged rift visual capacity exceeded")
	return -1
func update_cut(slot: int, point: Vector3, direction: Vector3, travelled: float, width: float, length: float) -> void:
	origins[slot]=Vector4(point.x,point.z,width,travelled)
	paths[slot]=Vector4(direction.x,direction.z,length,point.y)
func release(slot: int) -> void:
	entries.erase(slot);origins[slot]=Vector4.ZERO
	flush()
func flush() -> void:
	for material in materials:
		material.set_shader_parameter("rift_origins",origins)
		material.set_shader_parameter("rift_paths",paths)
func _exit_tree() -> void:
	for entry in originals:
		if is_instance_valid(entry[0]):entry[0].set_surface_override_material(entry[1],entry[2])
