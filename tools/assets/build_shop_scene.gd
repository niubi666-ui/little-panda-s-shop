extends SceneTree
## Offline scene authoring: outputs native editable nodes/resources, never runtime generation.

const OUT := "res://shop/scenes/shop_interior.tscn"
var shop: Node3D

func _initialize() -> void:
	call_deferred("build")

func vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func convert_point(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])

func from_blender(m: Array) -> Transform3D:
	var c := Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP)
	var b := Basis(Vector3(m[0][0], m[1][0], m[2][0]), Vector3(m[0][1], m[1][1], m[2][1]), Vector3(m[0][2], m[1][2], m[2][2]))
	return Transform3D(c * b, c * Vector3(m[0][3], m[1][3], m[2][3]))

func attach(parent: Node, child: Node, label: String) -> void:
	child.name = label
	parent.add_child(child)
	child.owner = shop

func own_tree(node: Node) -> void:
	node.owner = shop
	for child in node.get_children():
		own_tree(child)

func box(parent: Node3D, label: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	attach(parent, body, label)
	body.position = center
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	attach(body, shape, "Shape")

func build() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("E:/ShopGame/builds/inspection/shop_export.json"))
	var geometry: Node3D = load("res://assets/environments/shop/shop_interior_v006.glb").instantiate()
	shop = Node3D.new()
	shop.name = "ShopInterior"
	root.add_child(shop)
	var architecture := Node3D.new()
	attach(shop, architecture, "Architecture")
	var furnishings := Node3D.new()
	attach(shop, furnishings, "Furnishings")
	var fixed := Node3D.new()
	attach(shop, fixed, "FixedFixtures")
	var collidable := ["Entrance door", "Apothecary cabinet", "Main sales counter", "Right provisions cabinet", "Window low cabinet", "Front herb bench", "Central merchandise island HD", "Corner relics bookcase", "Right herbal supplies bookcase", "Low window provisions", "Stock barrel", "Scroll barrel", "Right treasure chest", "Goods crate", "Delivery crate", "Right stock barrel", "Right stock crate", "Entrance dried flower vase"]
	var by_name: Dictionary = {}
	for entry: Dictionary in metadata.objects:
		by_name[entry.name] = entry
	var wrapper_by_source: Dictionary = {}
	for node: Node in geometry.get_children():
		if not node is Node3D or not by_name.has(str(node.name)):
			continue
		var info: Dictionary = by_name[str(node.name)]
		node.owner = null
		geometry.remove_child(node)
		if info.collection in ["Architecture", "Floor"]:
			architecture.add_child(node)
			own_tree(node)
			if node is GeometryInstance3D:
				node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		else:
			var item := Node3D.new()
			attach(furnishings, item, str(node.name))
			var a := convert_point(info.bounds[0])
			var b := convert_point(info.bounds[1])
			var bounds_min := a.min(b)
			var bounds_max := a.max(b)
			var pivot := Vector3((a.x+b.x)*0.5, bounds_min.y, (a.z+b.z)*0.5)
			item.position = pivot
			item.set_meta("instance_id", info.instance_id)
			item.set_meta("definition_id", "furniture." + info.name)
			item.set_meta("source_name", info.source_name)
			item.set_meta("placement_scope", "shop.interior")
			node.position -= pivot
			attach(item, node, "Visual")
			own_tree(node)
			if node is GeometryInstance3D:
				node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			wrapper_by_source[info.source_name] = item
			if info.source_name in collidable:
				box(item, "Body", (bounds_min+bounds_max)*0.5-pivot, bounds_max-bounds_min)
	geometry.free()
	# Preserve logical items: their component meshes remain individually editable.
	for part: String in ["Curio bench leg", "Curio bench leg.001", "Curio bench lower brace", "Ornate hourglass", "Crystal specimen"]:
		adopt(wrapper_by_source[part], wrapper_by_source["Curio bench plank"])
	for part: String in wrapper_by_source:
		if part.begins_with("Banner ") or part.begins_with("Botanical branch") or part.begins_with("Gold embroidered leaf") or part == "Embroidered botanical stem":
			adopt(wrapper_by_source[part], wrapper_by_source["Botanical banner backing"])
		if part.begins_with("Shield "):
			adopt(wrapper_by_source[part], wrapper_by_source["Round oak shield"])
		if part.begins_with("Relics crown support"):
			adopt(wrapper_by_source[part], wrapper_by_source["Relics crown shelf"])
		if part.begins_with("Jar stopper") or part.begins_with("Blank jar label"):
			var closest: Node3D
			var distance := INF
			for jar: String in wrapper_by_source:
				if jar.begins_with("Apothecary stock jar") or jar.begins_with("Upper stock jar"):
					var d: float = wrapper_by_source[jar].global_position.distance_squared_to(wrapper_by_source[part].global_position)
					if d < distance:
						distance = d
						closest = wrapper_by_source[jar]
			assert(closest != null)
			adopt(wrapper_by_source[part], closest)
	for i in range(165):
		adopt(wrapper_by_source[source_index("Ivy leaf",i)], wrapper_by_source[source_index("Trailing ivy stem",i/11)])
	for i in range(15):
		if i % 3 != 0:
			adopt(wrapper_by_source[source_index("Trailing ivy stem",i)],wrapper_by_source[source_index("Trailing ivy stem",(i/3)*3)])
	for i in range(6):
		adopt(wrapper_by_source[source_index("Lantern luminous core",i)],wrapper_by_source[source_index("Wall lantern",i)])
	var attachments := {
		"Corner relics bookcase": ["Relics crown shelf", "Cabinet ivy crown", "Relics cabinet fern", "Relics side broad leaves"],
		"Apothecary cabinet": ["Fern above apothecary", "Apothecary right trailing leaves"],
		"Right herbal supplies bookcase": ["Right herbal cabinet fern"],
		"Right provisions cabinet": ["Front cabinet hanging ivy"],
		"Front herb bench": ["Front bench trailing greenery"]
	}
	for parent_name: String in attachments:
		for part: String in attachments[parent_name]:
			adopt(wrapper_by_source[part],wrapper_by_source[parent_name])
	for part: String in wrapper_by_source:
		if part.begins_with("Forged beam nail") or part.begins_with("Wall lantern") or part == "Entrance door":
			var fixture: Node3D = wrapper_by_source[part]
			fixture.reparent(fixed,true)
			fixture.set_meta("placement_locked", true)
	# Room floor and boundary collision are authored proxies, not arbitrary mesh AABBs.
	box(architecture, "WalkableFloor", Vector3(0,-0.075,0), Vector3(10.0,0.25,9.0))
	box(architecture, "BackBoundary", Vector3(0,1.8,-4.5), Vector3(10.2,3.6,0.2))
	box(architecture, "LeftBoundary", Vector3(-5.0,1.8,0), Vector3(0.2,3.6,9.2))
	box(architecture, "FrontBoundary", Vector3(0,0.5,4.5), Vector3(10.2,1.0,0.2))
	box(architecture, "RightBoundary", Vector3(5.0,0.5,0), Vector3(0.2,1.0,9.2))
	box(wrapper_by_source["Curio bench plank"], "Body", Vector3(0,-0.25,0), Vector3(1.02,0.65,0.58))
	interaction(wrapper_by_source["Main sales counter"], Vector3(0.45,0.65,-2.02), "shop.station.counter.name", "shop.station.counter.action")
	interaction(wrapper_by_source["Central merchandise island HD"], Vector3(-0.1,0.65,1.56), "shop.station.potions.name", "shop.station.potions.action")
	for surface: Vector3 in [Vector3(-1.8,0.65,-2.02), Vector3(2.8,0.65,-2.02), Vector3(-1.8,0.65,-3.42), Vector3(0.45,0.65,-3.42), Vector3(2.8,0.65,-3.42)]:
		var point := Marker3D.new()
		var counter: Node3D = wrapper_by_source["Main sales counter"]
		attach(counter.get_node("InteractionPoint"), point, "Approach")
		point.global_position = surface
	var stations := {
		"Right treasure chest": [Vector3(3.50,0.65,3.3), "chest"],
		"Apothecary cabinet": [Vector3(-3.4,0.65,-3.55), "storage"],
		"Corner relics bookcase": [Vector3(4.0,0.65,-3.3), "shelf"],
		"Right herbal supplies bookcase": [Vector3(3.70,0.65,-0.3), "shelf"],
		"Right provisions cabinet": [Vector3(3.75,0.65,1.4), "storage"],
		"Window low cabinet": [Vector3(-4.05,0.65,-0.1), "storage"],
		"Low window provisions": [Vector3(-4.10,0.65,-2.3), "storage"]
	}
	for source: String in stations:
		interaction(wrapper_by_source[source], stations[source][0], "shop.station."+stations[source][1]+".name", "shop.station."+stations[source][1]+".action")
	var lighting := Node3D.new()
	attach(shop, lighting, "Lighting")
	for l: Dictionary in metadata.lights:
		var light: Light3D
		if l.type == "SUN":
			var sun := DirectionalLight3D.new()
			sun.light_energy = 3.4
			sun.directional_shadow_max_distance = 50
			sun.light_angular_distance = 1.1
			light = sun
		elif l.type == "AREA" and str(l.name).begins_with("Afternoon"):
			var spot := SpotLight3D.new()
			spot.spot_range = 18
			spot.spot_angle = 68
			spot.spot_attenuation = 1.2
			spot.light_energy = 5.5
			spot.light_size = 0.07
			light = spot
		elif l.type == "AREA":
			var fill := SpotLight3D.new()
			fill.spot_angle = 85
			fill.spot_range = 10
			fill.spot_attenuation = 0.7
			fill.light_energy = 1.2
			fill.light_size = 1.0
			light = fill
		else:
			var omni := OmniLight3D.new()
			omni.omni_range = 4.3 if l.type == "POINT" else 8.0
			omni.omni_attenuation = 1.3
			omni.light_energy = float(l.energy)/90.0
			omni.light_size = maxf(l.radius,0.1)
			light = omni
		attach(lighting, light, str(l.name).validate_node_name())
		light.transform = from_blender(l.matrix)
		# Blender light RGB is scene-linear; Godot's inspector color is sRGB.
		light.light_color = Color(l.color[0],l.color[1],l.color[2]).linear_to_srgb()
		light.shadow_enabled = true
		light.shadow_bias = 0.035
		light.shadow_normal_bias = 0.25
		light.light_volumetric_fog_energy = 2.0 if l.type == "SUN" else 0.65
		if l.name == "Till lantern glow":
			light.reparent(wrapper_by_source["Main sales counter"],true)
		elif l.name == "Display lantern glow":
			light.reparent(wrapper_by_source["Central merchandise island HD"],true)
		elif str(l.name).begins_with("Lantern warm pool"):
			light.reparent(wrapper_by_source[str(l.name).replace("Lantern warm pool","Wall lantern")],true)
	# Original roof is invisible to camera but blocks outdoor light in Cycles.
	var roof := MeshInstance3D.new()
	roof.mesh = BoxMesh.new()
	roof.mesh.size = Vector3(10.5,0.16,9.5)
	roof.position = Vector3(0,4.06,0)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	attach(lighting, roof, "RoofShadowOnly")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32,0.40,0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82,0.81,0.76)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.35
	env.ssao_enabled = true
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.25
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 64
	env.volumetric_fog_anisotropy = 0.25
	env.volumetric_fog_ambient_inject = 0.3
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	attach(lighting, world_env, "WorldEnvironment")
	var fog := FogVolume.new()
	fog.size = Vector3(10.1,3.9,9.1)
	fog.position = Vector3(0,1.95,0)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.019
	fog_mat.albedo = Color(0.65,0.61,0.52)
	fog.material = fog_mat
	attach(lighting, fog, "WindowAtmosphere")
	# Visible emitter faces reproduce the bright exterior of Cycles area lights.
	# They never block illumination or add gameplay collision.
	for window_z: float in [0.5,-2.4]:
		var pane := MeshInstance3D.new()
		pane.mesh = QuadMesh.new()
		pane.mesh.size = Vector2(1.75,1.82)
		pane.rotation.y = PI * 0.5
		pane.position = Vector3(-5.32,2.29,window_z)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0,0.9,0.73)
		mat.emission_enabled = true
		mat.emission = Color(1.0,0.84,0.63)
		mat.emission_energy_multiplier = 1.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		pane.material_override = mat
		attach(lighting, pane, "WindowExterior")
		var dust := FogVolume.new()
		dust.size = Vector3(1.7,1.5,4.7)
		var dust_material := ShaderMaterial.new()
		dust_material.shader = load("res://resources/shop/window_dust.gdshader")
		dust_material.set_shader_parameter("dust_color", Color(0.72,0.57,0.34))
		dust_material.set_shader_parameter("density", 0.012)
		dust_material.set_shader_parameter("emission_strength", 0.15)
		dust.material = dust_material
		attach(lighting,dust,"WindowDust")
		dust.look_at_from_position(Vector3(-3.0,1.65,window_z+0.65),Vector3(0.0,0.0,window_z+1.85))
	var camera := Camera3D.new()
	attach(shop, camera, "ShopCamera")
	camera.transform = from_blender(metadata.camera.matrix)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(metadata.camera.ortho_scale)/1.6
	camera.near = 0.1
	camera.far = 80
	camera.current = true
	# Author a deeper shell while preserving the size of every movable furniture item.
	# Expansion is anchored at the entrance/front edge; only the rear stock row moves back.
	architecture.scale.z = 1.14
	architecture.position.z = -0.63
	for fixture: Node3D in fixed.get_children():
		fixture.position.z = fixture.position.z * 1.14 - 0.63
	for item: Node3D in furnishings.get_children():
		if item.position.z < -3.4:
			item.position.z -= 1.26
		elif item.position.x < -4.0:
			item.position.z = item.position.z * 1.14 - 0.63
	wrapper_by_source["Main sales counter"].position.x -= 0.30
	wrapper_by_source["Counter side herbs"].position.x += 0.45
	for node: Node in lighting.get_children():
		if not node is Node3D:
			continue
		node.position.z = node.position.z * 1.14 - 0.63
		if node is FogVolume or node == roof or str(node.name).begins_with("WindowExterior"):
			node.scale.z *= 1.14
	camera.position.z -= 0.45
	camera.size *= 1.08
	# Stock clusters occupy only the wall strip; the counter service lane stays clear.
	clone_decoration(wrapper_by_source["Stock barrel"], furnishings, "rear_small_barrel", Vector3(-1.95,0.05,-5.18), 0.66, 0.15)
	clone_decoration(wrapper_by_source["Scroll barrel"], furnishings, "rear_scroll_bin", Vector3(-1.28,0.05,-5.22), 0.75, -0.2)
	var supplies := clone_decoration(wrapper_by_source["Right stock crate"], furnishings, "rear_supply_crate", Vector3(-0.49,0.05,-5.19), 0.75, 0.08)
	var jar := clone_decoration(wrapper_by_source["Apothecary stock jar"], furnishings, "rear_jar", Vector3(-0.55,0.56,-5.19), 1.35, 0.0)
	adopt(jar, supplies)
	clone_decoration(wrapper_by_source["Goods crate"], furnishings, "rear_goods_basket", Vector3(1.30,0.05,-5.20), 0.65, -0.12)
	clone_decoration(wrapper_by_source["Stock barrel"], furnishings, "rear_small_barrel_right", Vector3(2.10,0.05,-5.20), 0.58, -0.25)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(200,200)
	ground.position.y = -0.49
	var ground_material := ShaderMaterial.new()
	ground_material.shader = load("res://resources/shop/surrounding_ground.gdshader")
	ground_material.set_shader_parameter("stone_color", Color(0.09,0.085,0.065))
	ground_material.set_shader_parameter("joint_color", Color(0.035,0.032,0.025))
	ground_material.set_shader_parameter("tile_scale", 1.25)
	ground_material.set_shader_parameter("joint_width", 0.014)
	ground_material.set_shader_parameter("surface_roughness", 0.93)
	ground.material_override = ground_material
	attach(shop, ground, "SurroundingGround")
	var spawn := Marker3D.new()
	attach(shop, spawn, "PlayerSpawn")
	spawn.position = Vector3(-3.55,0.10,2.45)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shop/scenes"))
	var packed := PackedScene.new()
	assert(packed.pack(shop) == OK)
	assert(ResourceSaver.save(packed, OUT) == OK)
	print("SHOP_SCENE_BUILT ", OUT, " props=", furnishings.get_child_count())
	quit()

func source_index(base: String, index: int) -> String:
	return base if index == 0 else base + ".%03d" % index

func clone_decoration(source: Node3D, parent: Node3D, label: String, position: Vector3, size: float, yaw: float) -> Node3D:
	var item: Node3D = source.duplicate()
	attach(parent, item, label)
	own_tree(item)
	item.set_meta("instance_id", "shop.initial." + label)
	item.position = position
	item.scale = Vector3.ONE * size
	item.rotation.y = yaw
	return item

func adopt(part: Node3D, item: Node3D) -> void:
	part.reparent(item, true)
	part.set_meta("part_of", item.get_meta("instance_id"))
	part.remove_meta("instance_id")
	part.remove_meta("definition_id")

func interaction(item: Node3D, world_position: Vector3, name_key: String, action_key: String) -> void:
	var marker := Marker3D.new()
	attach(item, marker, "InteractionPoint")
	marker.position = world_position - item.position
	marker.set_meta("instance_id", item.get_meta("instance_id"))
	marker.set_meta("definition_id", item.get_meta("definition_id"))
	marker.set_meta("name_key", name_key)
	marker.set_meta("action_key", action_key)
	marker.add_to_group("shop_interaction_points", true)
