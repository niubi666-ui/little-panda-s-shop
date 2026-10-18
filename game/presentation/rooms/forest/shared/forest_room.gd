extends "res://rogue/rooms/authored_room.gd"
## 森林系列场景的接入层（所有森林场景共用）。读取森林素材库（kit_dir/assets/<素材>.gltf，只加载本场景用到的）和本场景的摆放表，
## 生成植被、地面、溪水、碰撞、树影和灯光。不含任何战斗逻辑。
## 美术源：source_assets/environments/forest/（kit 素材库 + rooms/<场景>），导出用 tools/forest_export.py。
## 所有可调的画面参数都在各场景的 room.tscn 和材质 .tres 里赋值，本脚本不带内容默认值。

## Blender 导出物所在目录（layout.json、terrain/ 贴图）
@export_dir var asset_dir: String
## 森林素材库目录（每个素材一个 assets/<名字>.gltf）
@export_dir var kit_dir: String
@export var terrain: PackedScene
@export var ground_material: ShaderMaterial
@export var water_material: ShaderMaterial
## 瀑布水帘（地形里名字以 Waterfall 开头的网格）和潭面白沫（WaterfallFoam）；没有瀑布的场景留空
@export var waterfall_material: ShaderMaterial
@export var waterfall_foam_material: ShaderMaterial
## 石砌地面（地形里名字以 Platform 开头的网格：圣坛石台、石桥、台阶）；没有的场景留空
@export var platform_material: ShaderMaterial
## 植被材质模板：每种叶片/草/花的材质由它复制，再填入各自的贴图
@export var foliage_material: ShaderMaterial
## 指向太阳的方向：逆光，太阳在画面左上方的远处。与样板间的主光一致。
@export var to_sun: Vector3

@export_group("光")
## 主光束：沿太阳方向的一束窄光，落在 key_target（x、z 为地面位置）
@export var key_target: Vector3
@export var key_energy: float
## 灯离落点多远（沿太阳方向）；距离衰减按平方反比，能量按 Blender 瓦数 ÷ 38.6 换算
@export var key_distance: float
@export var key_range: float
@export var key_angle: float
## 光束边缘的衰减曲线（SpotLight3D.spot_angle_attenuation）
@export var key_angle_attenuation: float
@export var key_fog_energy: float
## 光束是否投影。开着更准，但整片森林要为这一盏灯多画一遍。
@export var key_shadow: bool
@export var lantern_color: Color
@export var lantern_energy: float
@export var lantern_range: float
## 灯笼光源在灯笼原点之上多高（米）
@export var lantern_height_m: float

@export_group("植被")
## 没有镂空贴图、但同样是薄片的植被材质：也按植被处理
@export var solid_foliage: PackedStringArray
## 带镂空但不是植被的材质（例如灯笼的火苗）：保持原样
@export var not_foliage: PackedStringArray
## 每种植被材质的着色参数，对应 Blender 里该材质的节点设置（饱和度、亮度、漫反射/透射比例……）。
## 键为材质名，值为 foliage.gdshader 的 uniform 名 → 数值。没列出的材质只用 foliage_material.tres 的默认值。
@export var foliage_grades: Dictionary
## 非植被材质按名染色（乘在原底色上）
@export var tints: Dictionary
## 风里顶端的摆幅，占植株高度的比例：矮的草花用 sway_small，高的树用 sway_tall，之间按高度过渡
@export var sway_small: float
@export var sway_tall: float
@export var sway_small_height: float
@export var sway_tall_height: float
## 高过这个高度（米）的植被当作树冠处理：越靠树冠内部、越靠下，环境光越暗
@export var crown_min_height: float
## 树冠最深处挡掉多少环境光（0..1）
@export var crown_occlusion: float

@export_group("性能")
## 实例数不超过此值且面数不低的资产逐个摆放（可被视锥裁剪并使用自动 LOD），其余合批绘制。
@export var solo_instance_limit: int
@export var solo_min_triangles: int
## 不投射阴影的资产：贴地的小东西，阴影看不出来却很费
@export var no_shadow: PackedStringArray

@export_group("碰撞")
## 地板碰撞盒的边长与厚度（米）；顶面高度略低于出生点，角色胶囊底部不能与地板重叠
@export var floor_size_m: float
@export var floor_thickness_m: float
@export var floor_top_y: float
## 场地四周空气墙的厚度与高度（米）；位置由导出数据里的场地范围 play_half 决定
@export var wall_thickness_m: float
@export var wall_height_m: float

@export_group("活动范围")
## 角色能走的矩形（x 为左右、y 为前后，即世界 z）。四周空气墙围着它。size 为 0 时用导出数据里的 play_half。
@export var walk_area: Rect2
## 溪水面抬高多少米：地面碰撞是平的，抬高后角色走进溪里看起来是站在水面上，而不是悬在水上方
@export var water_raise_m: float
## 跟着水面一起抬高的资产（浮在水上的东西，例如睡莲）
@export var floating_assets: PackedStringArray

@export_group("障碍")
## 会挡住人的素材：素材名 → 最小缩放（缩放小于它的实例不挡，例如溪里低矮的垫脚石板）
@export var solid_assets: Dictionary
## 碰撞盒相对模型包围盒的大小（水平方向），略小一点，贴着石头走时不会被看不见的边挡住
@export var solid_shrink: float
## 碰撞盒最低多高（米）
@export var solid_min_height: float

@export_group("疏密")
## 按资产保留多少比例的摆放（0..1，没列出的全保留）。挑哪些保留由位置决定，每次进场一样。
## 草太密时远看是一片细碎的高频纹理，角色跑动时会“花”，疏一点、让地面露出来更安静。
@export var density_keep: Dictionary

@export_group("落花")
## 每棵花树树冠下飘落的樱花瓣。粒子的运动（下落速度、风、翻飞）在 petal_process 里，
## 花瓣外观在 petal_mesh 的材质（petal.gdshader）里；这里只管放在哪、放多少。
@export var petal_tree_asset: String
@export var petal_process: ParticleProcessMaterial
@export var petal_mesh: Mesh
@export var petals_per_tree: int
@export var petal_lifetime: float
## 花瓣从树冠哪个高度落下（米，按树的缩放）
@export var petal_crown_height_m: float

@export_group("树影")
## 用哪个资产的树冠来投影
@export var shade_asset: String
## 树影落点：x、z 为地面位置，y 为树冠缩放
@export var shade_spots: PackedVector3Array

var data: Dictionary
var play_half: Vector2
var _ground: MeshInstance3D
var _parts: Dictionary = {}
var _converted: Dictionary = {}
## 已读入的素材（路径 → PackedScene）。所有森林场景共用：同一局里换房间不再从硬盘重读。
## 场景要改材质（换植被材质、染色）时改的是自己的网格副本，不影响缓存里的原件和别的场景。
static var _kit_cache: Dictionary = {}

## 离开森林系列（换到别的系列场景）时可以调用，释放素材占用的内存
static func clear_kit_cache() -> void:
	_kit_cache.clear()

func rift_surfaces() -> Array:
	return [_ground]

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(asset_dir.path_join("layout.json")))
	assert(data != null, "forest_room: layout.json missing")
	play_half = Vector2(data.play_half[0], data.play_half[1])
	to_sun = to_sun.normalized()
	$Lights/Sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	_build_terrain()
	_build_instances()
	_build_canopy_shade()
	_build_collision()
	_build_lights()
	$LightShafts.build(to_sun)
	_build_petals()

# ---------------- 坐标换算：Blender（Z 向上）→ Godot（Y 向上） ----------------
static func _convert(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)

static func _transform(m: Array) -> Transform3D:
	# m 为 Blender 4x4 矩阵按行展开
	var col_x := Vector3(m[0], m[4], m[8])
	var col_y := Vector3(m[1], m[5], m[9])
	var col_z := Vector3(m[2], m[6], m[10])
	var origin := Vector3(m[3], m[7], m[11])
	return Transform3D(Basis(_convert(col_x), _convert(col_z), -_convert(col_y)), _convert(origin))

# ---------------- 地面与溪水 ----------------
func _build_terrain() -> void:
	var scene := terrain.instantiate()
	add_child(scene)
	# 小径、溪床的形状参数来自导出数据，不是画面调节项
	ground_material.set_shader_parameter("stream_half", data.stream_half)
	ground_material.set_shader_parameter("bridge_x", data.bridge_x)
	ground_material.set_shader_parameter("water_level", data.water_z + water_raise_m)
	water_material.set_shader_parameter("sun_direction", to_sun)
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh_name := String(mesh.name)
		if mesh_name.begins_with("Platform"):
			mesh.material_override = platform_material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif mesh_name.begins_with("WaterfallFoam"):
			mesh.material_override = waterfall_foam_material
			mesh.position.y += water_raise_m
		elif mesh_name.begins_with("Waterfall"):
			mesh.material_override = waterfall_material
		elif mesh_name.begins_with("Brook"):
			mesh.material_override = water_material
			mesh.position.y += water_raise_m
		else:
			_ground = mesh
			mesh.material_override = ground_material

# ---------------- 植被与摆件 ----------------
func _is_foliage(material: BaseMaterial3D) -> bool:
	var name := String(material.resource_name)
	if not_foliage.has(name): return false
	return name.begins_with("FOL_") or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or solid_foliage.has(name)

## 把模型自带的植被材质换成带风和透光的植被材质。top 为植株顶端高度、origin_height 为
## 网格原点离地高度（都按资产自身的尺寸，未乘摆放缩放）；mesh_bounds 为网格自身坐标下的包围盒，
## 高过 crown_min_height 的植被（树冠）据此估算内部遮挡。
func _foliage_for(source: BaseMaterial3D, top: float, origin_height: float, local_scale: float, mesh_bounds: AABB) -> ShaderMaterial:
	if _converted.has(source): return _converted[source]
	var name := String(source.resource_name)
	var made: ShaderMaterial = foliage_material.duplicate()
	made.resource_name = name
	made.set_shader_parameter("albedo_tex", source.albedo_texture)
	made.set_shader_parameter("tint", source.albedo_color)
	made.set_shader_parameter("roughness", maxf(source.roughness, 0.6))
	if source.normal_enabled and source.normal_texture != null:
		made.set_shader_parameter("normal_tex", source.normal_texture)
		made.set_shader_parameter("use_normal_tex", true)
	made.set_shader_parameter("plant_height", top)
	made.set_shader_parameter("origin_height", origin_height)
	made.set_shader_parameter("local_scale", local_scale)
	made.set_shader_parameter("sway", lerpf(sway_small, sway_tall, smoothstep(sway_small_height, sway_tall_height, top)))
	if top >= crown_min_height:
		made.set_shader_parameter("crown_centre", mesh_bounds.get_center())
		made.set_shader_parameter("crown_size", mesh_bounds.size)
		made.set_shader_parameter("crown_occlusion", crown_occlusion)
	var grade: Dictionary = foliage_grades.get(name, {})
	for parameter in grade:
		made.set_shader_parameter(parameter, grade[parameter])
	_converted[source] = made
	return made

## 要换植被材质或染色的网格，本场景用自己的副本；其余（石头、树桩……）直接共用缓存里的原件
func _needs_own_copy(mesh: Mesh) -> bool:
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		if material != null and (_is_foliage(material) or tints.has(String(material.resource_name))): return true
	return false

func _prepare_mesh(mesh: Mesh, local: Transform3D) -> int:
	var bounds: AABB = local * mesh.get_aabb()
	var triangles := 0
	for surface in mesh.get_surface_count():
		triangles += mesh.surface_get_array_index_len(surface) / 3
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null: continue
		if _is_foliage(material):
			mesh.surface_set_material(surface, _foliage_for(material, bounds.end.y, local.origin.y, local.basis.get_scale().y, mesh.get_aabb()))
		elif tints.has(String(material.resource_name)):
			# 染色只改本场景的副本
			if not _converted.has(material):
				var tinted: BaseMaterial3D = material.duplicate()
				tinted.albedo_color = tints[String(material.resource_name)]
				_converted[material] = tinted
			mesh.surface_set_material(surface, _converted[material])
	return triangles

func _build_instances() -> void:
	# 素材只当“模具”用：取出网格后丢弃
	for asset in data.assets:
		var path: String = kit_dir.path_join("assets/%s.gltf" % asset)
		if not ResourceLoader.exists(path):
			push_warning("forest_room: asset missing in kit: " + asset)
			continue
		if not _kit_cache.has(path): _kit_cache[path] = load(path)
		var source: Node = _kit_cache[path].instantiate()
		var holder := source.find_child("A_" + asset, true, false)
		if holder == null:
			push_warning("forest_room: asset file has no A_ node: " + asset)
			source.free()
			continue
		var list: Array = []
		for mesh_node in holder.find_children("*", "MeshInstance3D", true, false):
			var local := Transform3D.IDENTITY
			var walker: Node = mesh_node
			while walker != holder and walker != null:
				if walker is Node3D: local = walker.transform * local
				walker = walker.get_parent()
			var mesh: Mesh = mesh_node.mesh.duplicate() if _needs_own_copy(mesh_node.mesh) else mesh_node.mesh
			list.append({"mesh": mesh, "local": local, "triangles": _prepare_mesh(mesh, local)})
		_parts[asset] = list
		source.free()
	var placed: Dictionary = {}
	for entry in data.instances:
		var xform := _transform(entry.m)
		if not _kept(entry.asset, xform.origin): continue
		if floating_assets.has(entry.asset): xform.origin.y += water_raise_m
		if not placed.has(entry.asset): placed[entry.asset] = []
		placed[entry.asset].append(xform)
	var holder_node := Node3D.new()
	holder_node.name = "Dressing"
	add_child(holder_node)
	for asset in placed:
		if not _parts.has(asset): continue
		var transforms: Array = placed[asset]
		var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if no_shadow.has(asset) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for part_index in _parts[asset].size():
			var part: Dictionary = _parts[asset][part_index]
			if transforms.size() <= solo_instance_limit and part.triangles >= solo_min_triangles:
				for index in transforms.size():
					var node := MeshInstance3D.new()
					node.name = "%s_%d_%d" % [asset, index, part_index]
					node.mesh = part.mesh
					node.transform = transforms[index] * part.local
					node.cast_shadow = shadow
					holder_node.add_child(node)
			else:
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.mesh = part.mesh
				multimesh.instance_count = transforms.size()
				for index in transforms.size():
					multimesh.set_instance_transform(index, transforms[index] * part.local)
				var node := MultiMeshInstance3D.new()
				node.name = "%s_part%d" % [asset, part_index]
				node.multimesh = multimesh
				node.cast_shadow = shadow
				holder_node.add_child(node)

func _kept(asset: String, at: Vector3) -> bool:
	if not density_keep.has(asset): return true
	var roll := fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)
	return roll < float(density_keep[asset])

# ---------------- 落花 ----------------
func _build_petals() -> void:
	if petals_per_tree <= 0 or petal_process == null or petal_mesh == null: return
	var holder := Node3D.new()
	holder.name = "FallingPetals"
	add_child(holder)
	var index := 0
	for entry in data.instances:
		if entry.asset != petal_tree_asset: continue
		var xform := _transform(entry.m)
		var tree_scale: float = xform.basis.get_scale().y
		var emitter := GPUParticles3D.new()
		emitter.name = "Petals%d" % index
		emitter.amount = petals_per_tree
		emitter.lifetime = petal_lifetime
		emitter.preprocess = petal_lifetime
		emitter.randomness = 1.0
		emitter.process_material = petal_process
		emitter.draw_pass_1 = petal_mesh
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 16, 24))
		holder.add_child(emitter)
		emitter.global_position = xform.origin + Vector3.UP * petal_crown_height_m * tree_scale
		index += 1

# ---------------- 树影 ----------------
func _build_canopy_shade() -> void:
	# 空地本身没有树，整片都是平光。在空地上方放几团“只投影、不显示”的树冠，
	# 让阳光变成斑驳的树影；体积雾里也因此出现一道道光柱。
	var leaves: Dictionary = {}
	for part in _parts.get(shade_asset, []):
		if leaves.is_empty() or part.triangles > leaves.triangles: leaves = part
	if leaves.is_empty(): return
	var holder := Node3D.new()
	holder.name = "CanopyShade"
	add_child(holder)
	var height: float = (leaves.local * leaves.mesh.get_aabb()).get_center().y
	for spot in shade_spots:
		var size: float = spot.y
		# 树冠中心离地 height * size；沿太阳方向反推树根位置，使影子正好落在 spot 上
		var reach: float = height * size / to_sun.y
		var base: Vector3 = Vector3(spot.x, 0.0, spot.z) + Vector3(to_sun.x, 0.0, to_sun.z) * reach
		var node := MeshInstance3D.new()
		node.mesh = leaves.mesh
		node.transform = Transform3D(Basis(Vector3.UP, spot.x * 1.7 + spot.z).scaled(Vector3.ONE * size), base) * leaves.local
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		holder.add_child(node)

# ---------------- 碰撞 ----------------
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# 地板顶面略低于出生点：角色胶囊底部不能与地板重叠，否则空位检查会失败。
	_add_box(body, Vector3(floor_size_m, floor_thickness_m, floor_size_m), Vector3(0, floor_top_y - floor_thickness_m / 2.0, 0))
	var thickness := wall_thickness_m
	var height := wall_height_m
	var area := walk_area if walk_area.size.x > 0.0 else Rect2(-play_half, play_half * 2.0)
	var centre := area.get_center()
	_add_box(body, Vector3(thickness, height, area.size.y + thickness * 2.0), Vector3(area.end.x + thickness / 2.0, height / 2.0, centre.y))
	_add_box(body, Vector3(thickness, height, area.size.y + thickness * 2.0), Vector3(area.position.x - thickness / 2.0, height / 2.0, centre.y))
	_add_box(body, Vector3(area.size.x, height, thickness), Vector3(centre.x, height / 2.0, area.end.y + thickness / 2.0))
	_add_box(body, Vector3(area.size.x, height, thickness), Vector3(centre.x, height / 2.0, area.position.y - thickness / 2.0))
	# 场地里的大石头、树桩：按模型包围盒立一个碰撞盒
	for entry in data.instances:
		if not solid_assets.has(entry.asset) or not _parts.has(entry.asset): continue
		var xform := _transform(entry.m)
		if not _kept(entry.asset, xform.origin): continue
		var scale := xform.basis.get_scale().x
		if scale < float(solid_assets[entry.asset]): continue
		if not area.grow(1.0).has_point(Vector2(xform.origin.x, xform.origin.z)): continue
		var bounds := AABB()
		for index in _parts[entry.asset].size():
			var part: Dictionary = _parts[entry.asset][index]
			var piece: AABB = part.local * part.mesh.get_aabb()
			bounds = piece if index == 0 else bounds.merge(piece)
		# 高度至少 solid_min_height：矮石头的碰撞盒太矮，角色胶囊的圆底会顺着边滑上去
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var tall := maxf(bounds.size.y * scale, solid_min_height)
		box.size = Vector3(bounds.size.x * solid_shrink * scale, tall, bounds.size.z * solid_shrink * scale)
		shape.shape = box
		var middle := xform * bounds.get_center()
		var upright := Basis(Vector3.UP, xform.basis.get_euler().y)
		shape.transform = Transform3D(upright, Vector3(middle.x, floor_top_y + tall / 2.0, middle.z))
		body.add_child(shape)

func _add_box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

# ---------------- 灯光 ----------------
func _build_lights() -> void:
	# 主光束：像树冠缺口漏下来的一束阳光，落在场地后方的遗迹上
	var key := SpotLight3D.new()
	key.name = "KeyShaft"
	key.light_color = $Lights/Sun.light_color
	key.light_energy = key_energy
	key.spot_range = key_range
	key.spot_angle = key_angle
	key.spot_angle_attenuation = key_angle_attenuation
	key.spot_attenuation = 2.0          # 平方反比，和 Blender 一致
	key.shadow_enabled = key_shadow
	key.light_volumetric_fog_energy = key_fog_energy
	$Lights.add_child(key)
	key.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), key_target + to_sun * key_distance)
	for entry in data.instances:
		if entry.asset != "lantern": continue
		var lamp := OmniLight3D.new()
		lamp.light_color = lantern_color
		lamp.light_energy = lantern_energy
		lamp.omni_range = lantern_range
		lamp.omni_attenuation = 2.0     # 平方反比，和 Blender 一致
		lamp.shadow_enabled = false
		$Lights.add_child(lamp)
		lamp.global_position = _transform(entry.m).origin + Vector3.UP * lantern_height_m
