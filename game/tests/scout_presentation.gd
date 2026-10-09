extends SceneTree
## Exercises the imported asset through the real actor factory and logic timeline.
var failures: Array[String] = []
var checks := 0
var arena
var graphical := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func capture(label: String) -> void:
	if not graphical: return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/scout_"+label+".png")
func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	var forest := "--forest" in OS.get_cmdline_user_args()
	arena = load("res://app/combat_training.tscn" if forest else "res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await process_frame
	var a = arena._spawn(arena.catalog.actor("scout"), arena.player.position+Vector3(-1.6,0,-2), 1)
	var b = arena._spawn(arena.catalog.actor("scout"), arena.player.position+Vector3(1.6,0,-2), 1)
	var va = arena.views[arena.actors.find(a)]
	var vb = arena.views[arena.actors.find(b)]
	a.facing = Vector3.BACK; b.facing = Vector3.BACK
	va.refresh(.1); vb.refresh(.1)
	if graphical:
		arena.get_node("UIRoot").hide()
		var camera: Camera3D = arena.get_node("Camera")
		camera.size=7.5
		camera.position=arena.player.position+Vector3(3,5,7)
		camera.look_at(arena.player.position+Vector3(0,.5,-1.5))
	check(va.visual.validate_assets(), "all seven approved clips and timing cuts are valid")
	var anim: AnimationPlayer = va.visual.animation
	var other: AnimationPlayer = vb.visual.animation
	check(anim.get_animation_list().size() >= 7, "seven clips survived GLB import")
	var frame_counts := {"scout_idle":74,"scout_walk":34,"scout_run":22,"scout_attack_slash":42,"scout_attack_diagonal":46,"scout_hit_react":22,"scout_death":70}
	for clip in frame_counts:
		check(absf(anim.get_animation(clip).length-(frame_counts[clip]-1)/30.0)<.002, "zero-based authored clip duration: "+clip)
	check(anim.get_animation("scout_idle") != other.get_animation("scout_idle"), "per-instance animation resources isolated")
	var skeletons = va.visual.find_children("*", "Skeleton3D", true, false)
	var meshes = va.visual.find_children("*", "MeshInstance3D", true, false)
	check(skeletons.size() == 1 and meshes.size() == 2, "one rig, one body, one saber; no review props")
	var skeleton: Skeleton3D = skeletons[0]
	check(skeleton.get_bone_count() == 65, "65 skin bones imported")
	var hips := -1
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).ends_with("Hips"): hips=i
	check(hips>=0, "root bone exists")
	for clip in ["scout_walk", "scout_run", "scout_attack_slash", "scout_attack_diagonal"]:
		anim.play(clip)
		var start := Vector2.ZERO
		var drift := 0.0
		for step in 11:
			anim.seek(anim.get_animation(clip).length*step/10.0,true)
			skeleton.force_update_all_bone_transforms()
			var p: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(hips).origin
			if step==0: start=Vector2(p.x,p.z)
			drift=maxf(drift,start.distance_to(Vector2(p.x,p.z)))
		check(drift<.001, "no doubled root motion: "+clip)
	va.visual.selected_clip=""
	for mesh in meshes:
		check(mesh.skin != null and mesh.get_node(mesh.skeleton) == skeleton, "body and saber use same skeleton: "+mesh.name)
		check(mesh.get_active_material(0) != null, "textured material exists: "+mesh.name)
	check(va.blade.get_child_count() == 0 and not va.blade_pivot.visible, "no duplicate procedural sword")
	# Imported forward calibration: average toes should point along actor forward in walk.
	a.velocity = Vector3.BACK
	va.refresh(.1)
	check(va.visual.selected_clip == "scout_walk", "slow movement selects walk")
	skeleton.force_update_all_bone_transforms()
	var toe := Vector3.ZERO
	var foot := Vector3.ZERO
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if name.ends_with("ToeBase"): toe += skeleton.get_bone_global_pose(i).origin
		elif name.ends_with("Foot"): foot += skeleton.get_bone_global_pose(i).origin
	var forward: Vector3 = skeleton.global_basis * (toe-foot)
	forward.y = 0
	check(forward.normalized().dot(a.facing) > .7, "imported feet face movement direction")
	a.velocity = Vector3.BACK * a.definition.speed
	va.refresh(.15)
	check(va.visual.selected_clip == "scout_run", "normal chase speed selects run")
	var time := anim.current_animation_position
	va.refresh(0.0)
	check(is_equal_approx(time,anim.current_animation_position), "pause does not advance locomotion")
	await capture("run")
	var ability = a.attacks[0]
	check(va.visual.style.attack_clips==["scout_attack_diagonal"], "crouching slash removed from runtime attack selection")
	a.velocity = Vector3.ZERO
	var cuts: Vector2
	for iteration in 2:
		a.runner.cooldown = 0.0
		check(a.runner.start(ability,a.facing), "real scout attack starts")
		a.runner.tick(ability.windup*.75)
		va.refresh(.01)
		var clip: String = va.visual.style.attack_clips[iteration % va.visual.style.attack_clips.size()]
		cuts = va.visual.style.attack_cuts_sec[clip]
		check(va.visual.selected_clip==clip, "attack variants use approved clips")
		check(is_equal_approx(anim.current_animation_position,cuts.x*.75), "windup samples authored windup")
		check(va.sector.visible and not va.blade_pivot.visible, "existing telegraph retained with single embedded saber")
		await capture("windup_"+str(iteration))
		a.runner.tick(ability.windup*.25+ability.active*.5)
		va.refresh(.01)
		check(is_equal_approx(anim.current_animation_position,(cuts.x+cuts.y)*.5), "active sample aligned to gameplay active phase")
		await capture("strike_"+str(iteration))
		a.runner.tick(ability.active*.5+ability.recovery*.5)
		va.refresh(.01)
		check(is_equal_approx(anim.current_animation_position,lerpf(cuts.y,anim.get_animation(clip).length,.5)), "recovery samples authored recovery")
		a.runner.cancel()
		va.refresh(.01)
		check(va.visual.selected_clip=="scout_idle", "cancel ends attack presentation")
	a.runner.cooldown=0.0; a.runner.start(ability,a.facing); a.runner.tick(.2); va.refresh(.01)
	a.set_control(1.0,true)
	time = anim.current_animation_position
	var frozen_clip: String = va.visual.selected_clip
	va.refresh(.5)
	check(time==anim.current_animation_position and va.visual.selected_clip==frozen_clip and not a.runner.busy(), "freeze cancels gameplay attack and preserves pose")
	a.set_control(1.0,false)
	a.receive_hit(1.0); va.refresh(.01)
	check(va.visual.selected_clip=="scout_hit_react", "confirmed hit selects stagger clip")
	a.step(a.definition.stagger*.5); va.refresh(.01)
	await capture("hit")
	check(other.current_animation=="scout_idle", "one scout's combat does not change another's clip")
	a.receive_hit(a.health.maximum); va.refresh(.7)
	check(va.visual.selected_clip=="scout_death" and va.visible and va.visual.visible, "lethal hit plays death without instant disappearance")
	time=anim.current_animation_position
	va.refresh(0.0)
	check(time==anim.current_animation_position, "pause holds death")
	va.refresh(anim.get_animation("scout_death").length)
	check(is_equal_approx(anim.current_animation_position,anim.get_animation("scout_death").length), "death clamps at last pose")
	check(va.visible and not va.visual.has_presentation_tail(), "corpse retains final pose without endless tail")
	await capture("death")
	if graphical:
		# Actual scene camera, with the new enemy beside the existing player for scale.
		arena.get_node("UIRoot").hide()
		var camera: Camera3D = arena.get_node("Camera")
		camera.size=7.5
		camera.position=arena.player.position+Vector3(3,5,7)
		camera.look_at(arena.player.position+Vector3(0,.5,-1.5))
		b.runner.cooldown=0.0; b.runner.start(b.attacks[0],b.facing); b.runner.tick(b.attacks[0].windup*.8)
		vb.refresh(.01)
		await process_frame
		await capture("forest" if forest else "overview")
	# Let deferred UI layout tasks finish before destroying their owners.
	for i in 3: await process_frame
	arena.free()
	await process_frame
	print("SCOUT_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures,"forest":forest,"graphical":graphical}))
	quit(0 if failures.is_empty() else 1)
