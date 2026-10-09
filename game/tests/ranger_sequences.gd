extends "res://tests/ranger_rules.gd"
var shots: Array[Dictionary] = []
var centers: Array[Vector3] = []
var peak_areas := 0

func advance(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(.01, remaining)
		brain.tick(step)
		var pending: int = 1 if brain.state == "windup" and brain.attack_id == "rain" else 0
		peak_areas = maxi(peak_areas, runtime.rains.size() + pending)
		runtime.after_motion(step)
		remaining -= step

func reset() -> void:
	runtime.projectiles.clear(); runtime.rains.clear()
	runtime.charged_rifts.clear()
	shots.clear(); centers.clear()
	brain.pending_steps.clear(); brain._interrupt_recovery = false
	brain.state = "idle"; brain.roll_cooldown = 100.0
	player.health.restore(); ranger.health.restore()
	player.set_damage_immunity(true)
	player.position = Vector3(0,0,-8)
	ranger.position = Vector3.ZERO
	brain.phase_two = false; brain._combo_since_single = false
	for id in brain.cooldowns: brain.cooldowns[id] = 0.0

func run() -> void:
	combat = preload("res://content/combat/combat_loader.gd").new().load_catalog()
	catalog = preload("res://content/enemies/enemy_loader.gd").new().load_catalog(combat)
	check(catalog != null, "sequence content passes online validation")
	if catalog == null: quit(1); return
	player = make_actor("player",1); ranger = make_actor("elite_ranger",2)
	runtime = Runtime.new()
	runtime.configure(player,.35,func(a):return a.position+Vector3.UP,func(_a,_b,_r):return 1.0)
	brain = runtime.add(ranger,catalog.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_b):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_a,_c):return true,"seed":19})
	brain.shot_requested.connect(func(_a,d,c): shots.append({"direction":d,"settings":c}))
	brain.rain_requested.connect(func(_a,p,_c): centers.append(p))
	reset()
	for distance in [3.0,8.0,12.0]:
		player.position=Vector3(0,0,-distance)
		brain._start("charged")
		brain.tick(brain.windup_duration-brain.config.charged_lock_sec)
		var locked: Vector3=brain.locked_direction
		player.position=Vector3(distance,0,0)
		brain.tick(brain.config.charged_lock_sec)
		check(shots.back().direction.is_equal_approx(locked), "charged final lock does not track sideways player at " + str(distance))
		check(shots.back().settings.projectile_speed_mps==brain.config.charged_speed_mps, "charged speed fixed independent of distance")
	check(brain.config.charged_damage>brain.config.fast_damage and brain.recovery_duration>brain.config.fast_recovery_sec, "charged damage and punishable recovery exceed normal")
	brain.roll_ready=true;brain.roll_cooldown=0;player.position=Vector3(0,0,-1)
	advance(.3)
	check(brain.state=="recovery", "close pressure cannot cancel charged recovery into roll")
	var recovery_left: float=brain.time_left
	ranger.set_control(1.0,true);advance(.2);ranger.set_control(1.0,false);brain.tick(.01)
	check(brain.state=="recovery" and brain.time_left>=recovery_left-.011,"freeze after release cannot shorten punishable recovery")
	reset();player.set_damage_immunity(false)
	brain._start("charged");brain.tick(brain.windup_duration)
	runtime.after_motion(.2)
	check(is_equal_approx(player.health.maximum-player.health.current,brain.config.charged_damage), "charged continuous sweep crosses player without tunneling")
	reset();player.set_damage_immunity(false)
	brain._start("charged");brain.tick(brain.windup_duration)
	runtime.sweep_world=func(_a,_b,_r):return .1
	runtime.after_motion(.5)
	check(player.health.current==player.health.maximum and runtime.projectiles.is_empty(), "charged wall before player blocks damage")
	runtime.sweep_world=func(_a,_b,_r):return 1.0
	reset();brain._start("charged");ranger.set_control(1.0,true)
	advance(2.0)
	check(shots.is_empty(), "freeze before charged release cancels shot")
	ranger.set_control(1.0,false)
	reset();brain._start("burst")
	while brain.state != "recovery": advance(.01)
	check(shots.size()==3, "burst emits exactly two fast arrows and a strong finisher")
	check(not shots[0].settings.charged and not shots[1].settings.charged and shots[2].settings.charged, "burst damage/speed use shared fast and charged definitions")
	check(shots[0].settings.volley_id!=shots[1].settings.volley_id and shots[1].settings.volley_id!=shots[2].settings.volley_id, "distinct burst shots do not share volley hit suppression")
	check(brain.recovery_duration==brain.config.burst_recovery_sec and brain.pending_steps.is_empty(), "burst ends with bounded longer recovery")
	reset();peak_areas=0;brain._start("rain")
	var initial: Vector3=brain.target_point
	brain.tick(brain.windup_duration)
	check(centers[0]==initial and brain.state=="sequence_gap", "first circle stays locked while sequence continues")
	player.position.x=4.0;brain.tick(brain.time_left)
	var second: Vector3=brain.target_point
	player.position.x=6.0;brain.tick(brain.windup_duration)
	check(centers[1]==second and second!=initial, "next circle baits current position then stays fixed")
	brain.tick(brain.time_left);brain.tick(brain.windup_duration)
	check(centers.size()==3 and runtime.rains.size()==3 and brain.state=="recovery", "three finite locked circles and no fourth wave")
	check(not brain.rain_admission.call(ranger,player.position,brain.config), "existing warnings and active circles consume shared capacity")
	check(brain._legal_actions(8.0).is_empty(), "no new volley or burst while own rain lingers")
	reset();peak_areas=0;brain._start("rain");advance(3.0)
	check(peak_areas==3, "real timeline reaches but does not exceed three warning/active circles")
	reset()
	var old_admission: Callable=brain.rain_admission
	brain._start("combo");brain.tick(brain.windup_duration)
	brain.rain_admission=func(_a,_p,_c):return false
	brain.tick(brain.time_left)
	check(brain.state=="recovery" and brain.pending_steps.is_empty() and shots.is_empty(), "blocked escape aborts remaining sequence including charged followup")
	brain.rain_admission=old_admission
	reset()
	check(not brain._legal_actions(8.0).has("combo"), "first half has no rain/charged combination")
	ranger.health.current=ranger.health.maximum*brain.config.phase_two_health_ratio
	brain.state="recovery";brain.time_left=1.0;brain.tick(.01)
	check(brain.phase_two and brain._legal_actions(8.0).has("combo"), "half health unlocks bounded combination")
	check(brain._legal_actions(8.0).has("fast") and brain._legal_actions(8.0).has("charged"), "phase two preserves separate attacks")
	brain._start("combo")
	while brain.state!="recovery":advance(.01)
	check(centers.size()==3 and shots.size()==1 and shots[0].settings.charged, "combo ends rain casting before one horizontal charged shot")
	check(brain.recovery_duration==brain.config.combo_recovery_sec, "combo ends in punishable recovery")
	runtime.rains.clear();brain.cooldowns.combo=0;brain.cooldowns.rain=0
	check(not brain._legal_actions(8.0).has("combo"), "cannot repeat combinations back to back even after cooldown")
	reset();brain._start("rain");brain.tick(brain.windup_duration)
	ranger.set_control(1.0,true);advance(1.0)
	check(centers.size()==1 and brain.pending_steps.is_empty() and not runtime.rains.is_empty(), "freeze during gap cancels future waves but keeps committed rain")
	ranger.set_control(1.0,false);runtime.remove_actor(ranger)
	check(runtime.rains.is_empty() and runtime.projectiles.is_empty(), "source removal clears sequence-owned attacks")
	runtime.clear();player.free();ranger.free()
	print("RANGER_SEQUENCES ",JSON.stringify({"checks":checks,"failures":failures,"peak_areas":peak_areas}))
	quit(0 if failures.is_empty() else 1)
