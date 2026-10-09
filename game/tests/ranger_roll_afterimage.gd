extends "res://tests/ranger_charged_integration.gd"
func run() -> void:
	create_timer(180.0).timeout.connect(func():
		if not finished:check(false,"roll timeout");quit(1))
	change_scene_to_file("res://app/main.tscn")
	await ticks(4)
	while current_scene==null:await process_frame
	var event:=InputEventAction.new();event.action="combat_training";event.pressed=true
	Input.parse_input_event(event)
	while current_scene==null or not current_scene.scene_file_path.ends_with("combat_training.tscn"):await process_frame
	arena=current_scene;arena.set_physics_process(false)
	while paused:await process_frame
	while arena.builds.is_choosing():
		arena.builds.choice_panel.buttons.values()[0].pressed.emit();await process_frame
	check(arena._refresh_ranger(),"real training spawn")
	var ranger=arena._managed_ranger
	var brain=brain_for(ranger)
	var view=arena.views[arena.actors.find(ranger)]
	var fx=arena.enemy_presentation.entries.filter(func(e):return e.brain==brain)[0].afterimage
	ranger.position=Vector3(-3,0,0);ranger.facing=Vector3.RIGHT
	brain.state="rolling";brain.roll_duration=.65;brain.roll_left=.65;brain.roll_direction=Vector3.RIGHT
	view.refresh(.01);arena.enemy_presentation.refresh(.01)
	check(fx.emitted==1,"roll emits immediately")
	var first=fx.pool[0]
	var frozen: Transform3D=first.root.global_transform
	var pose: Quaternion=first.skeleton.get_bone_pose_rotation(20)
	for i in 20:
		ranger.position.x+=5.0/.65/60.0;brain.roll_left-=1.0/60.0
		view.refresh(1.0/60.0);arena.enemy_presentation.refresh(1.0/60.0)
	check(fx.emitted>=4,"moving roll produces spaced silhouettes")
	check(first.root.global_transform.is_equal_approx(frozen),"old ghost stays in world space")
	check(first.skeleton.get_bone_pose_rotation(20).is_equal_approx(pose),"snapshot pose does not follow animation")
	check(first.meshes.size()==2 and first.skeleton.get_bone_count()==78,"body bow and complete skeleton copied")
	check(first.root.find_children("*","CollisionObject3D",true,false).is_empty(),"ghosts have no gameplay collision")
	var age: float=first.age
	var count: int=fx.emitted
	arena.enemy_presentation.refresh(0.0)
	check(first.age==age and fx.emitted==count,"zero delta freezes ghosts")
	var camera=arena.get_node("Camera")
	camera.position=Vector3(6,9,12);camera.look_at(Vector3(0,1,0));camera.size=10
	arena.get_node("UIRoot").hide()
	await capture("roll_afterimage")
	for i in 25:
		ranger.position.x+=.14;brain.roll_left=maxf(0,brain.roll_left-1.0/60)
		view.refresh(1.0/60);arena.enemy_presentation.refresh(1.0/60)
	check(fx.pool.size()==fx.profile.max_images,"pool stays bounded")
	brain.state="idle";arena.enemy_presentation.refresh(fx.profile.lifetime_sec+.01)
	check(fx.pool.all(func(p):return not p.active),"normal roll end fades all ghosts")
	brain.state="rolling";arena.enemy_presentation.refresh(.01)
	fx.set_enabled(false)
	check(fx.pool.all(func(p):return not p.active),"disable clears ghosts")
	fx.set_enabled(true);arena.enemy_presentation.refresh(.01)
	fx.refresh(.01,true,false)
	check(fx.pool.all(func(p):return not p.active),"death clears ghosts")
	var old=weakref(fx)
	check(arena._refresh_ranger(),"replace ranger")
	await process_frame
	check(old.get_ref()==null,"replacement frees snapshot pool")
	arena._shutdown();current_scene=null;arena.queue_free();await process_frame;await process_frame
	finished=true
	print("RANGER_ROLL_AFTERIMAGE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
