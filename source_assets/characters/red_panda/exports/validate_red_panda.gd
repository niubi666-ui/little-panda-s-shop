extends SceneTree

const ASSET_PATH := "E:/ShopGame/game/assets/characters/red_panda/red_panda_v008.glb"
const REPORT_PATH := "E:/ShopGame/source_assets/characters/red_panda/exports/red_panda_v008_godot_validation.json"

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	var document := GLTFDocument.new()
	GLTFDocument.register_gltf_document_extension(GLTFDocumentExtensionConvertImporterMesh.new(), true)
	var state := GLTFState.new()
	var error := document.append_from_file(ASSET_PATH, state)
	if error != OK:
		push_error("GLB parse failed: %s" % error)
		quit(1)
		return
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var report := {"engine": Engine.get_version_info()["string"], "nodes": [], "skeletons": [], "meshes": [], "animations": {}}
	var players: Array[AnimationPlayer] = []
	_inspect(scene, report, players)
	if players.size() != 1:
		push_error("Expected one AnimationPlayer")
		quit(1)
		return
	var player := players[0]
	for action in [&"idle", &"run"]:
		if not player.has_animation(action):
			push_error("Missing animation: %s" % action)
			quit(1)
			return
		var animation := player.get_animation(action)
		report["animations"][action] = {"length": animation.length, "tracks": animation.get_track_count(), "loop_mode": animation.loop_mode}
		player.play(action)
		player.pause()
		var root_positions: Array[Vector3] = []
		for sample in [0.0, animation.length * 0.25, animation.length * 0.5, animation.length]:
			player.seek(sample, true)
			await process_frame
			for node in scene.find_children("*", "Skeleton3D", true, false):
				root_positions.append(node.get_bone_pose_position(node.find_bone("Root")))
				for bone in range(node.get_bone_count()):
					if not node.get_bone_global_pose(bone).is_finite():
						push_error("Nonfinite bone pose")
						quit(1)
						return
		report["animations"][action]["root_pose_samples"] = root_positions.map(func(value: Vector3): return [value.x, value.y, value.z])
		if action == &"run" and root_positions[0].is_equal_approx(root_positions[1]):
			push_error("Run pose did not change between sampled frames")
			quit(1)
			return
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit(0)

func _inspect(node: Node, report: Dictionary, players: Array[AnimationPlayer]) -> void:
	report["nodes"].append({"path": str(node.get_path()), "type": node.get_class()})
	if node is AnimationPlayer:
		players.append(node)
	if node is Skeleton3D:
		report["skeletons"].append({"path": str(node.get_path()), "bones": node.get_bone_count()})
	if node is MeshInstance3D:
		report["meshes"].append({"path": str(node.get_path()), "surfaces": node.mesh.get_surface_count(), "skin": node.skin != null, "skeleton": str(node.skeleton)})
	for child in node.get_children():
		_inspect(child, report, players)
