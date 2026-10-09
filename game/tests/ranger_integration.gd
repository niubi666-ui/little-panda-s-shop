extends SceneTree
var failures: Array[String] = []
var checks := 0
var arena
var finished := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/ranger_" + label + ".png")
func click(node: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = node.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate(); event.pressed = false
	root.push_input(event, true)
	await process_frame
func brain_for(actor):
	return arena.enemy_runtime.brains.filter(func(b):return b.actor==actor)[0]
func run() -> void:
	create_timer(90.0).timeout.connect(func():
		if not finished: check(false,"integration timeout");quit(1))
	change_scene_to_file("res://app/main.tscn")
	await ticks(4)
	while current_scene == null: await process_frame
	check(current_scene.controller != null,"actual shop boots")
	var f6 := InputEventAction.new();f6.action="combat_training";f6.pressed=true
	Input.parse_input_event(f6)
	while current_scene == null or not current_scene.scene_file_path.ends_with("combat_training.tscn"): await process_frame
	arena=current_scene
	arena.set_physics_process(false)
	await create_timer(0.6).timeout
	check(not arena._refresh_ranger(),"modal blocks direct spawn command")
	while arena.builds.is_choosing():
		arena.builds.choice_panel.buttons.values()[0].pressed.emit()
		await process_frame
	arena.training_tools.refresh()
	await ticks(3)
	await capture("before_toolbar")
	await click(arena.training_tools.panel.find_child("TrainingToolsToggle",true,false))
	await ticks(2)
	await capture("opened_toolbar")
	var button=arena.training_tools.panel.find_child("TrainingRefreshRanger",true,false)
	check(button.is_visible_in_tree() and not button.disabled,"ranger button visible in existing training tools")
	var hp: float=arena.player.health.current
	var build: Dictionary=arena.builds.session.snapshot()
	var plan: Dictionary=arena.encounter_plan.duplicate(true)
	var alive: int=arena.encounter.remaining()
	await click(button)
	check(is_instance_valid(arena._managed_ranger),"real pointer click spawns ranger")
	if not is_instance_valid(arena._managed_ranger): quit(1);return
	var old=arena._managed_ranger
	var meshes=arena.views.back().visual.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==2,"only one body and one bow exported")
	check(arena.views.back().visual.validate_assets(),"all required exported clips available")
	check(arena.player.health.current==hp and arena.builds.session.snapshot()==build and arena.encounter_plan==plan and arena.encounter.remaining()==alive,"spawn preserves HP Build encounter and required kill count")
	var anchors: Array[Vector3]=arena._enemy_spawns.duplicate()
	arena._enemy_spawns.clear()
	check(not arena._refresh_ranger() and arena._managed_ranger==old,"bad spawn preserves old instance")
	arena._enemy_spawns=anchors
	var model: PackedScene=arena.Style.actor_presentations.elite_ranger.visual_scene
	arena.Style.actor_presentations.elite_ranger.visual_scene=null
	check(not arena._refresh_ranger() and arena._managed_ranger==old,"bad resource preserves old instance")
	arena.Style.actor_presentations.elite_ranger.visual_scene=model
	var b=brain_for(old)
	b._start("fast");b.tick(b.windup_duration)
	b._start("rain");b.tick(b.windup_duration)
	check(not arena.enemy_runtime.projectiles.is_empty() and not arena.enemy_runtime.rains.is_empty(),"live effects exist before replacement")
	var blockers: Array = []
	var sequence: int = arena._ranger_sequence
	for i in int(arena.enemy_catalog.encounters.training_tools.max_alive_enemies):
		blockers.append(arena._spawn(arena.catalog.actor("scout"), Vector3(100+i,0,100), 1))
	check(not arena._refresh_ranger() and arena._managed_ranger==old and arena._ranger_sequence==sequence and not arena.enemy_runtime.rains.is_empty() and not arena.enemy_runtime.projectiles.is_empty(),"population limit preserves actor effects and random sequence")
	for actor in blockers:
		var index: int = arena.actors.find(actor)
		arena.actors.remove_at(index);arena.views.remove_at(index);actor.free()
	arena.training_tools.set_enemies_invincible(true)
	check(arena._refresh_ranger(),"repeat spawn replaces managed ranger")
	check(arena.enemy_runtime.projectiles.is_empty() and arena.enemy_runtime.rains.is_empty(),"replacement retires old owned effects")
	check(arena._managed_ranger.invulnerable(),"replacement inherits enemy immunity")
	await process_frame
	check(not is_instance_valid(old),"old actor disposed")
	check(arena.actors.filter(func(a):return a.definition.id=="elite_ranger").size()==1,"repeat refresh cannot accumulate rangers")
	for locale in ["en","zh_CN"]:
		TranslationServer.set_locale(locale);arena.training_tools.refresh_text();await ticks(2)
		check(button.text==tr("training.tools.ranger"),"bilingual ranger button "+locale)
		await capture("toolbar_"+locale)
	arena.training_tools.set_enemies_invincible(false)
	arena.training_tools.set_player_invincible(true)
	# Show the imported poses in the real room, with gameplay paused for evidence capture.
	arena.get_node("UIRoot").hide()
	var ranger=arena._managed_ranger
	b=brain_for(ranger)
	var view=arena.views[arena.actors.find(ranger)]
	var clear_motion := Vector3.ZERO
	for distance_m in [b.config.roll_distance_m,b.config.roll_min_distance_m]:
		for i in 8:
			var motion: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, i*TAU/8)*distance_m
			if arena._ranger_roll_path(ranger,motion): clear_motion=motion;break
		if clear_motion!=Vector3.ZERO: break
	check(clear_motion!=Vector3.ZERO,"real room has a legal roll corridor")
	if clear_motion!=Vector3.ZERO:
		var wall := StaticBody3D.new();wall.collision_layer=arena.Actor.BodyLayer.WORLD
		var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3.ONE
		shape.shape=box;wall.add_child(shape);arena.add_child(wall)
		wall.global_position=arena._actor_query_origin(ranger)+clear_motion*.5
		await ticks(2)
		check(not arena._ranger_roll_path(ranger,clear_motion),"real swept body rejects a wall in roll corridor")
		wall.free();await ticks(2)
		var start: Vector3 = ranger.position
		b.state="rolling";b.roll_direction=clear_motion.normalized()
		b.roll_distance=clear_motion.length();b.roll_duration=b.config.roll_duration_sec;b.roll_left=b.roll_duration
		while b.state == "rolling":
			await physics_frame
			var delta := 1.0 / float(Engine.physics_ticks_per_second)
			b.tick(delta);ranger.step(delta)
		var traveled: float = ranger.position.distance_to(start)
		check(absf(traveled-clear_motion.length())<.05,"physical motor reaches selected 3-5m roll endpoint")
		print("RANGER_ROLL_DISTANCE ",traveled)
		ranger.position=start;b.cancel();await ticks(2)
	arena.get_node("Camera").size=12.0
	arena.get_node("Camera").position=ranger.position+Vector3(5,5,7)
	arena.get_node("Camera").look_at(ranger.position+Vector3.UP*2.5)
	for id in ["fast","volley","rain"]:
		b.aim();b._start(id);b.time_left=b.windup_duration*.2
		view.refresh(.01);arena.enemy_presentation.refresh();await ticks(8);await capture(id)
		b.tick(b.time_left+.001)
		arena.enemy_runtime.after_motion(.15 if id!="rain" else .35)
		view.refresh(.01);arena.enemy_presentation.refresh();await ticks(8);await capture(id+"_released")
		arena.enemy_runtime.projectiles.clear();arena.enemy_runtime.rains.clear()
	b.state="rolling";b.roll_duration=b.config.roll_duration_sec;b.roll_left=b.roll_duration*.5;b.roll_direction=ranger.facing
	view.refresh(.01);arena.enemy_presentation.refresh();await ticks(8);await capture("roll")
	var animation: AnimationPlayer=view.visual.animation
	var pose_time: float=animation.current_animation_position
	ranger.set_control(1.0,true);view.refresh(.5)
	check(animation.current_animation_position==pose_time,"frozen imported animation holds its pose")
	ranger.set_control(1.0,false)
	await challenge_checks(ranger, b, view)
	# Run the real physics loop after sampled poses; no forced attack selection.
	var natural_actions: Dictionary = {}
	b.action_started.connect(func(id,_cast): natural_actions[id]=int(natural_actions.get(id,0))+1)
	b.cancel()
	arena.get_node("Camera").size=12.0
	arena.set_physics_process(true)
	for frame in 960:
		if frame in [0,480]:
			var distance := 6.0 if frame==0 else 1.8
			for side in 8:
				var point: Vector3=ranger.position+Vector3.FORWARD.rotated(Vector3.UP,side*TAU/8)*distance
				if arena._ranger_ground(point): arena.player.position=point;break
		await physics_frame
		if frame==420 or frame==900: await capture("natural_"+str(frame))
	arena.set_physics_process(false)
	check(int(natural_actions.get("fast",0))+int(natural_actions.get("volley",0))>1,"live physics produces repeated committed ranged attacks")
	print("RANGER_NATURAL ",JSON.stringify(natural_actions))
	# Natural decisions in place: pause and death must not leave projectiles/areas.
	b.cancel();arena.paused=true
	var before: float=b.roll_cooldown
	arena._physics_process(.5)
	check(b.roll_cooldown==before,"pause freezes ranger clock")
	arena.paused=false
	for wave in arena._waves.size():
		for actor in arena.actors.duplicate():
			if actor.team != 0 and actor != ranger and actor.health.alive(): actor.receive_hit(actor.health.maximum)
		arena.encounter.tick(arena.catalog.wave_delay()+.1)
		arena.builds.flush_offers()
		while arena.builds.is_choosing():
			arena.builds.choice_panel.buttons.values()[0].pressed.emit()
			await process_frame
	check(arena.state!="victory", "ordinary clear does not freeze living ranger")
	ranger.receive_hit(ranger.health.maximum)
	check(arena.state=="victory", "managed death permits victory after ordinary clear")
	view.refresh(view.visual.style.death_duration_sec * .5)
	check(view.visible and view.visual.visible and view.visual.has_presentation_tail(), "slower death still playing at midpoint")
	await capture("death_mid")
	view.refresh(view.visual.style.death_duration_sec)
	check(view.visible and view.visual.visible and not view.visual.has_presentation_tail(), "corpse holds final pose after death animation")
	await capture("corpse")
	check(ranger.collision_layer == 0 and ranger.collision_mask == 0, "corpse cannot block player or shots")
	check(arena._refresh_ranger() and arena.state=="fighting", "ranger can be fought after victory")
	await process_frame
	check(is_instance_valid(ranger) and arena.actors.has(ranger) and view.visible, "refresh retains previous dead elite")
	arena._append_training_wave([], [])
	check(is_instance_valid(ranger) and arena.actors.has(ranger), "additional practice wave retains elite corpse")
	b=brain_for(arena._managed_ranger);b._start("fast");b.tick(b.windup_duration)
	arena.training_tools.set_player_invincible(false)
	arena.player.receive_hit(arena.player.health.maximum)
	check(arena.enemy_runtime.projectiles.is_empty() and arena.enemy_runtime.rains.is_empty() and not arena._refresh_ranger(),"player death cleans effects and rejects refresh")
	arena._shutdown()
	current_scene=null
	arena.queue_free()
	await process_frame
	await process_frame
	finished=true
	print("RANGER_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func challenge_checks(ranger, b, view) -> void:
	var start: Vector3 = arena.player.position
	var selected := false
	for point in arena._enemy_spawns:
		if not arena._ranger_ground(point): continue
		arena.player.position=point
		if arena._ranger_rain_escape([{"center":point,"radius":b.config.rain_radius_m,"active":false}], b.config):
			selected=true;break
	check(selected,"real room admits a rain circle with full-body escape route")
	if not selected:
		arena.player.position=start;return
	var point: Vector3=arena.player.position
	var walls: Array[Node3D]=[]
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var wall:=StaticBody3D.new();wall.collision_layer=arena.Actor.BodyLayer.WORLD
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(.4,4,5) if side.x!=0 else Vector3(5,4,.4)
		shape.shape=box;wall.add_child(shape);arena.add_child(wall)
		wall.position=point+side*1.7+Vector3.UP*1.5;walls.append(wall)
	await ticks(2)
	check(not arena._ranger_rain_escape([{"center":point,"radius":b.config.rain_radius_m,"active":false}], b.config),"real physics rejects rain when walls remove every escape route")
	for wall in walls:wall.free()
	await ticks(2)
	# Scripted state sampling in the actual room, never a concept render.
	arena.enemy_runtime.projectiles.clear();arena.enemy_runtime.rains.clear()
	b._start("rain")
	var started:=0
	while b.state!="recovery" and started<800:
		b.tick(.01);arena.enemy_runtime.after_motion(.01)
		view.refresh(.01);arena.enemy_presentation.refresh(.01)
		if b.state=="sequence_gap":
			for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
				var next: Vector3=point+direction*float(arena.enemy_runtime.rains.size())
				if arena._ranger_ground(next):arena.player.position=next;break
		started+=1
	check(arena.enemy_runtime.rains.size()==3,"real room plays three bounded baitable rain circles")
	arena.get_node("Camera").size=15.0
	var focus: Vector3=point.lerp(ranger.position,.5)
	arena.get_node("Camera").position=focus+Vector3(5,10,9)
	arena.get_node("Camera").look_at(focus)
	await ticks(3);await capture("challenge_rain")
	arena.enemy_runtime.rains.clear();arena.enemy_presentation.refresh(.01)
	b._start("charged");b.time_left=b.config.charged_lock_sec
	view.refresh(.01);arena.enemy_presentation.refresh(.01)
	await ticks(3);await capture("challenge_charge")
	var direction: Vector3=b.locked_direction
	arena.player.position+=Vector3.RIGHT*2.0
	b.tick(b.time_left);arena.enemy_runtime.after_motion(.06)
	view.refresh(.01);arena.enemy_presentation.refresh(.06)
	check(b.state=="recovery" and b.locked_direction==direction,"actual scene charged shot honors lock and recovery")
	await ticks(3);await capture("challenge_arrow")
	arena.enemy_runtime.projectiles.clear();arena.enemy_runtime.rains.clear()
	b.cancel();arena.player.position=start
