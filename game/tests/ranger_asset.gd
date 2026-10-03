extends SceneTree
var failures: Array[String] = []
var checks := 0
var skeleton: Skeleton3D
var animation: AnimationPlayer
var bones: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func sample(clip: String, fraction: float) -> Dictionary:
	animation.play(clip)
	animation.seek(animation.get_animation(clip).length * fraction, true)
	skeleton.force_update_all_bone_transforms()
	var result: Dictionary = {}
	for name in bones: result[name] = skeleton.get_bone_global_pose(bones[name]).origin
	return result
func run() -> void:
	var model = load("res://presentation/combat/enemies/ranger_visual.tscn").instantiate()
	root.add_child(model)
	check(model.validate_assets(), "every Resource-mapped clip exists in final imported GLB")
	var skeletons = model.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == 1 and model.find_children("*", "MeshInstance3D", true, false).size() == 2, "single runtime actor, no source showcase duplicates")
	skeleton = skeletons[0]
	animation = model.find_child("AnimationPlayer", true, false)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in skeleton.get_bone_count():
		for suffix in ["LeftHand", "RightHand", "LeftFoot", "RightFoot", "Hips", "BowString_Draw"]:
			if skeleton.get_bone_name(i).ends_with(suffix): bones[suffix] = i
	check(bones.size() == 6, "hands feet hips and bowstring exported")
	var aim = sample("aim", 1.0)
	var rain = sample("rain", 1.0)
	check((aim.LeftHand - aim.RightHand).z > .3 and absf((aim.LeftHand - aim.RightHand).y) < .1, "flat shot aims along source forward")
	check((rain.LeftHand - rain.RightHand).y > .25, "rain lifts bow above draw hand")
	var release = sample("rain_release", 1.0)
	check((release.LeftHand - release.RightHand).y < .15, "rain recovery lowers the bow")
	var start = sample("roll", 0.0)
	var middle = sample("roll", .5)
	check(middle.Hips.y < start.Hips.y * .6 and middle.LeftFoot.y > middle.Hips.y, "roll visibly tucks and inverts rather than sidesteps")
	var fixed_root := true
	for i in 21:
		var pose = sample("roll", float(i) / 20)
		fixed_root = fixed_root and Vector2(pose.Hips.x, pose.Hips.z).distance_to(Vector2(start.Hips.x, start.Hips.z)) < .001
	check(fixed_root, "roll has no horizontal root motion that doubles Motor displacement")
	var string_draw: Vector3 = aim.BowString_Draw - aim.LeftHand
	var released = sample("release", 1.0)
	check(string_draw.distance_to(released.BowString_Draw - released.LeftHand) > .02, "bowstring deformation survives baking and export")
	model.free()
	print("RANGER_ASSET ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
