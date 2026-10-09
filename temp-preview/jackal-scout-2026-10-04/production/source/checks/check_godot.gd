extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Provide an exported GLB path")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(arguments[0], state)
	if error != OK:
		push_error("GLB append failed: " + str(error))
		quit(1)
		return
	var instance := document.generate_scene(state)
	if instance == null:
		push_error("GLB did not generate a scene")
		quit(1)
		return
	root.add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var skeletons := instance.find_children("*", "Skeleton3D", true, false)
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if meshes.is_empty() or skeletons.is_empty() or players.is_empty():
		push_error("Missing imported mesh, skeleton, or AnimationPlayer")
		quit(1)
		return
	var player: AnimationPlayer = players[0]
	var clips := []
	for animation_name in player.get_animation_list():
		var animation := player.get_animation(animation_name)
		if animation_name == &"RESET":
			continue
		if animation.length <= 0 or animation.get_track_count() == 0:
			push_error("Empty animation: " + animation_name)
			quit(1)
			return
		player.play(animation_name)
		player.advance(animation.length * 0.4)
		await process_frame
		clips.append({"name": animation_name, "length": animation.length, "tracks": animation.get_track_count()})
	if clips.size() < 3:
		push_error("Fewer than three imported animation clips")
		quit(1)
		return
	print("JACKAL_GODOT_IMPORT ", JSON.stringify({"engine": Engine.get_version_info().string, "meshes": meshes.size(), "skeleton_bones": skeletons[0].get_bone_count(), "clips": clips, "result": "PASS"}))
	instance.queue_free()
	await process_frame
	quit(0)
