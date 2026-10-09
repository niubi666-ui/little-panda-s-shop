extends SceneTree
## Separate-process art capture. Samples existing rule time; never edits the project.
var arena
var brain
var ranger
var view
var preview := "E:/ShopGame/source_assets/vfx/elite_ranger_v001/previews"
var frames := "E:/ShopGame/builds/ranger_vfx_capture_v001"
var report: Dictionary = {"method":"Actual Godot Forward+ frames; individually triggered skills with fixed-step rule/animation sampling", "fps":30,"skills":{}}
var movie := false
func _initialize() -> void:
	root.size=Vector2i(1280,800)
	movie=OS.get_cmdline_user_args().has("--movie")
	create_timer(90.0).timeout.connect(func():quit(1))
	call_deferred("run")
func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func step(delta: float) -> void:
	if brain.state in ["windup","recovery"]: brain.tick(delta)
	arena.enemy_runtime.after_motion(delta)
	for item in arena.views: item.refresh(delta)
	arena.enemy_presentation.refresh(delta)
	for i in arena.actors.size():
		arena.views[i].label.hide()
		if arena.views[i].hit_feedback!=null: arena.views[i].hit_feedback.bar.hide()
		if arena.actors[i]!=ranger and arena.actors[i]!=arena.player: arena.views[i].hide()
	await process_frame
func place() -> bool:
	# Select an open, valid lane for a clear review of all five physical projectiles.
	for x in [-3.0,0.0,3.0]:
		for z in [-3.0,0.0,3.0]:
			var start:=Vector3(x,0,z)
			if not arena._ranger_ground(start): continue
			for side in 16:
				var direction:=Vector3.FORWARD.rotated(Vector3.UP,float(side)*TAU/16.0)
				var end: Vector3=start+direction*7.5
				if not arena._ranger_ground(end): continue
				var clear:=true
				for spread in [-20.0,-10.0,0.0,10.0,20.0]:
					var p:=start+Vector3.UP
					if arena._enemy_sweep(p,p+direction.rotated(Vector3.UP,deg_to_rad(spread))*7.5,brain.config.arrow_radius_m)<1.0: clear=false
				if not clear: continue
				ranger.position=start
				arena.player.position=end
				return true
	return false
func run() -> void:
	DirAccess.make_dir_recursive_absolute(preview)
	arena=load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled=false
	root.add_child(arena);current_scene=arena
	arena.set_physics_process(false)
	arena.training_tools.set_player_invincible(true)
	for i in 4: await process_frame
	assert(arena._refresh_ranger())
	ranger=arena._managed_ranger
	brain=arena.enemy_runtime.brains.filter(func(b):return b.actor==ranger)[0]
	view=arena.views[arena.actors.find(ranger)]
	assert(place(),"Need an open review lane")
	arena.set_physics_process(false)
	await process_frame
	for i in arena.actors.size():
		if arena.actors[i]!=ranger and arena.actors[i]!=arena.player: arena.views[i].hide()
	arena.get_node("UIRoot").hide()
	var camera: Camera3D=arena.get_node("Camera")
	var center: Vector3=ranger.position.lerp(arena.player.position,.45)
	camera.size=13.5
	camera.position=center+Vector3(7,10,8)
	camera.look_at(center+Vector3.UP*1.1)
	report["ranger_position"]=ranger.position
	report["player_position"]=arena.player.position
	for id in ["fast","volley","rain"]:
		arena.enemy_runtime.projectiles.clear();arena.enemy_runtime.rains.clear()
		arena.enemy_presentation.ranger_vfx.clear()
		brain.aim();brain._start(id)
		var duration: float=brain.windup_duration+2.4 if id=="rain" else brain.windup_duration+1.35
		var count:=int(ceil(duration*30.0))
		var directory: String=frames.path_join(id)
		if movie: DirAccess.make_dir_recursive_absolute(directory)
		var hero_delay: float=.74 if id=="rain" else (.14 if id=="fast" else .18)
		var hero_frame:=int(round((brain.windup_duration+hero_delay)*30.0))
		var hit_frame:=int(round((brain.windup_duration+.5)*30.0))
		for index in count:
			await step(1.0/30.0)
			if movie: await save(directory.path_join("frame_%04d.png"%index))
			if index==hero_frame:
				await save(preview.path_join(id+"_hero.png"))
				var debug: Dictionary={"processing":arena.is_physics_processing(),"arrows":arena.enemy_presentation.ranger_vfx.live_arrows.size(),"bursts":arena.enemy_presentation.ranger_vfx.bursts.size(),"rains":arena.enemy_presentation.ranger_vfx.live_rains.size()}
				for item in arena.enemy_presentation.ranger_vfx.live_arrows.values():
					debug["arrow"]={"point":item.view.body.global_position,"history":item.view.history.size(),"age":item.view.clock,"tip_progress":item.view.flare.material_override.get_shader_parameter("progress"),"bounds":item.view.layers[1].node.get_aabb()}
				print("RANGER_FRAME_STATE ",id," ",JSON.stringify(debug))
			if index==hit_frame: await save(preview.path_join(id+"_impact.png"))
		report.skills[id]={"frames":count,"hero_frame":hero_frame,"impact_frame":hit_frame}
		print("RANGER_VFX_CAPTURE ",id," ",count)
	var file:=FileAccess.open(preview.path_join("capture_report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	arena._shutdown();arena.queue_free()
	await process_frame
	await process_frame
	quit(0)
