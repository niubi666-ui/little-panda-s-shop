extends "res://tests/ranger_integration.gd"
var records: Array=[]
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 8:
		await process_frame
		RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("E:/ShopGame/builds/charged_game_"+label+".png")
func advance_cast(brain, view, seconds: float) -> void:
	var left:=seconds
	while left>0.000001:
		var delta:=minf(left,1.0/60.0)
		if brain.state=="windup":brain.tick(delta)
		arena.enemy_runtime.after_motion(delta)
		view.refresh(delta);arena.enemy_presentation.refresh(delta)
		left-=delta
func run() -> void:
	create_timer(240.0).timeout.connect(func():
		if not finished:check(false,"charged integration timeout");quit(1))
	change_scene_to_file("res://app/main.tscn")
	await ticks(4)
	while current_scene==null:await process_frame
	check(current_scene.controller!=null,"actual shop entry boots")
	var event:=InputEventAction.new();event.action="combat_training";event.pressed=true
	Input.parse_input_event(event)
	while current_scene==null or not current_scene.scene_file_path.ends_with("combat_training.tscn"):await process_frame
	arena=current_scene;arena.set_physics_process(false)
	while paused:await process_frame
	while arena.builds.is_choosing():
		arena.builds.choice_panel.buttons.values()[0].pressed.emit();await process_frame
	check(arena._refresh_ranger(),"existing training refresh spawns upgraded elf")
	if not is_instance_valid(arena._managed_ranger):finished=true;quit(1);return
	var ranger=arena._managed_ranger
	var brain=brain_for(ranger)
	var view=arena.views[arena.actors.find(ranger)]
	var fx=arena.enemy_presentation.ranger_vfx.charged_fx
	check(fx.cuts.materials.size()>0,"actual courtyard injected for ground cutting")
	check(fx.camera==arena.get_node("Camera"),"actual game camera injected")
	var corridor:=false
	for z in [-2.0,0.0,2.0,4.0]:
		var start:=Vector3(-5.4,0,z)
		var end:=start+Vector3.RIGHT*8.2
		if arena._ranger_ground(start) and arena._ranger_ground(end) and arena._enemy_sweep(start+Vector3.UP,end+Vector3.UP,brain.config.arrow_radius_m)>=1.0:
			ranger.position=start;arena.player.position=end;corridor=true;break
	check(corridor,"real world contains unobstructed test corridor")
	if not corridor:finished=true;quit(1);return
	await ticks(2)
	var camera=arena.get_node("Camera")
	var focus: Vector3=ranger.position.lerp(arena.player.position,.5)
	camera.position=focus+Vector3(6,12,13);camera.look_at(focus);camera.size=15.3
	arena.get_node("UIRoot").hide()
	arena.player.health.restore();arena.training_tools.set_player_invincible(false)
	brain._start("charged")
	advance_cast(brain,view,brain.config.charged_windup_sec-.15)
	check(fx.casts.size()==1,"charge has approved layered renderer")
	await capture("charge")
	advance_cast(brain,view,.15+.10)
	check(arena.player.health.current==arena.player.health.maximum-50,"actual combat direct damage is 50")
	check(arena.enemy_runtime.charged_rifts.items.size()==1 and fx.cuts.entries.size()==1,"one authoritative rift and one ground cut")
	var area: Dictionary=arena.enemy_runtime.charged_rifts.items[0]
	check(area.length<=brain.config.charged_range_m+.001,"path bounded by real world/range")
	advance_cast(brain,view,.30)
	check(arena.player.health.current==arena.player.health.maximum-50,"no residual tick before half second")
	advance_cast(brain,view,.10)
	check(arena.player.health.current==arena.player.health.maximum-58,"actual combat residual tick is 8")
	arena.training_tools.set_player_invincible(true)
	advance_cast(brain,view,.6)
	await capture("rift")
	var cast=fx.casts.values()[0]
	var frozen: Array=[area.age,cast.state.clock,fx.cuts.origins.duplicate()]
	arena.paused=true;arena._physics_process(.5)
	check([area.age,cast.state.clock,fx.cuts.origins]==frozen,"game pause freezes rules and rift geometry")
	arena.paused=false
	# Multiple origins survive independently, including after one visual is disabled.
	brain._start("charged");advance_cast(brain,view,brain.config.charged_windup_sec+.1)
	check(arena.enemy_runtime.charged_rifts.items.size()==2 and fx.cuts.entries.size()==2,"two residual paths keep independent cuts")
	arena.enemy_presentation.ranger_vfx.set_enabled(false)
	check(fx.cuts.entries.is_empty() and arena.enemy_runtime.charged_rifts.items.size()==2,"disabling art restores ground without cancelling rules")
	arena.enemy_presentation.ranger_vfx.set_enabled(true);arena.enemy_presentation.refresh(.01)
	check(fx.cuts.entries.size()==2,"re-enabling restores both current paths")
	check(arena._refresh_ranger(),"existing button can replace source during active rifts")
	check(arena.enemy_runtime.charged_rifts.items.is_empty() and fx.casts.is_empty() and fx.cuts.entries.is_empty(),"refresh clears owned arrows rifts and floor holes immediately")
	ranger=arena._managed_ranger;brain=brain_for(ranger);view=arena.views[arena.actors.find(ranger)]
	brain._start("charged");advance_cast(brain,view,.4)
	ranger.set_control(1.0,true);arena.enemy_presentation.refresh(.01)
	check(fx.casts.is_empty() and arena.enemy_runtime.charged_rifts.items.is_empty(),"real control interruption cancels charging renderer")
	arena._shutdown();check(fx.casts.is_empty() and fx.cuts.entries.is_empty(),"exit clears pending charge and cut state")
	current_scene=null;arena.queue_free();await process_frame;await process_frame
	finished=true
	print("RANGER_CHARGED_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
