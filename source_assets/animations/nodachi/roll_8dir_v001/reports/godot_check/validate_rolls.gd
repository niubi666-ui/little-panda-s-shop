extends SceneTree

const ASSET_ROOT = "E:/ShopGame/source_assets/animations/nodachi/roll_8dir_v001/"
const EXPECTED = ["roll_forward", "roll_forward_right", "roll_right", "roll_back_right", "roll_back", "roll_back_left", "roll_left", "roll_forward_left"]

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("check_import")

func check_import() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ASSET_ROOT + "godot/nodachi_roll_8dir.glb", state)
	if error != OK:
		fail("GLB import error: " + str(error))
		return
	var model := document.generate_scene(state)
	if model == null:
		fail("No scene generated")
		return
	root.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or skeletons.size() != 1:
		fail("Unexpected player / skeleton count")
		return
	var player: AnimationPlayer = players[0]
	var skeleton: Skeleton3D = skeletons[0]
	var names := player.get_animation_list()
	var results: Array = []
	for clip_name in EXPECTED:
		if not player.has_animation(clip_name):
			fail("Missing animation " + clip_name)
			return
		var animation: Animation = player.get_animation(clip_name)
		if animation.length <= 0.1 or animation.loop_mode != Animation.LOOP_NONE:
			fail("Invalid duration / loop flag: " + clip_name)
			return
		player.play(clip_name)
		player.advance(0)
		skeleton.force_update_all_bone_transforms()
		var head := skeleton.find_bone("head")
		var p0 := skeleton.get_bone_global_pose(head)
		player.advance(animation.length * 0.4)
		skeleton.force_update_all_bone_transforms()
		var p1 := skeleton.get_bone_global_pose(head)
		var rotation_delta := p0.basis.get_rotation_quaternion().angle_to(p1.basis.get_rotation_quaternion())
		var position_delta := p0.origin.distance_to(p1.origin)
		if rotation_delta < 0.01 and position_delta < 0.001:
			fail("Animation did not move skeleton: " + clip_name)
			return
		results.append({"name":clip_name,"seconds":animation.length,"tracks":animation.get_track_count(),
			"head_rotation_change_rad":rotation_delta,"head_position_change":position_delta,"loop":false})
	var output := {"ok":true,"godot_version":Engine.get_version_info(),"animations":results,
		"imported_animation_names":names,"bone_count":skeleton.get_bone_count(),"retargeted":false}
	var file := FileAccess.open(ASSET_ROOT + "reports/godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  "))
	file.close()
	print("ROLL_GODOT_VALIDATED: ", results.size(), " animations")
	model.queue_free()
	quit(0)
