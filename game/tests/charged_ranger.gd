extends "res://tests/ranger_rules.gd"
func setup() -> void:
	runtime.projectiles.clear();runtime.charged_rifts.clear();runtime.rains.clear()
	player.health.restore();player.set_damage_immunity(false)
	ranger.health.restore();ranger.set_control(1.0,false)
	player.position=Vector3(0,0,-8);ranger.position=Vector3.ZERO
	runtime.sweep_world=func(_a,_b,_r):return 1.0
	brain.state="idle";brain.pending_steps.clear();brain._interrupt_recovery=false
func shoot() -> void:
	brain._start("charged");brain.tick(brain.windup_duration)
func run() -> void:
	combat=preload("res://content/combat/combat_loader.gd").new().load_catalog()
	catalog=preload("res://content/enemies/enemy_loader.gd").new().load_catalog(combat)
	check(catalog!=null,"validated injected catalog")
	player=make_actor("player",1);ranger=make_actor("elite_ranger",2)
	runtime=Runtime.new();runtime.configure(player,.4,func(a):return a.position+Vector3.UP,func(_a,_b,_r):return 1.0)
	brain=runtime.add(ranger,catalog.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_b):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_a,_b):return true,"seed":1})
	check(brain.config.charged_damage==50 and brain.config.charged_rift_damage==8 and brain.config.charged_rift_interval_sec==.5,"requested 50 / 8 / half-second config")
	setup();shoot()
	check(runtime.charged_rifts.items.size()==1,"release commits one area")
	var p: Dictionary=runtime.projectiles[0]
	check(is_equal_approx(p.life*p.config.projectile_speed_mps,brain.config.charged_range_m),"fixed range independent of shared arrow lifetime")
	runtime.after_motion(.1)
	check(player.health.current==player.health.maximum-50,"ultrafast arrow hits once")
	check(p.contact and runtime.projectiles.is_empty(),"contact recorded and arrow completes full range")
	check(is_equal_approx(runtime.charged_rifts.items[0].length,brain.config.charged_range_m),"arrow pierces player to lay complete path")
	runtime.after_motion(.399)
	check(player.health.current==player.health.maximum-50,"no immediate or early residual damage")
	runtime.after_motion(.001)
	check(player.health.current==player.health.maximum-58,"first tick at half second is eight")
	player.position.x=4;runtime.after_motion(.5)
	check(player.health.current==player.health.maximum-58,"outside path avoids pulse")
	player.position.x=0;runtime.after_motion(.5)
	check(player.health.current==player.health.maximum-66,"reentry uses existing clock")
	var age: float=runtime.charged_rifts.items[0].age
	runtime.after_motion(0.0)
	check(runtime.charged_rifts.items[0].age==age,"zero delta freezes hazard")
	setup();player.set_damage_immunity(true);shoot();runtime.after_motion(.1)
	check(player.health.current==player.health.maximum,"dodge immunity rejects direct damage")
	player.set_damage_immunity(false);runtime.after_motion(.4)
	check(player.health.current==player.health.maximum-8,"passing arrow never re-hits after immunity; residual still active")
	setup();shoot();player.position.x=1.0
	runtime.before_motion(.1);player.position.x=-1.0;runtime.after_motion(.1)
	check(player.health.current==player.health.maximum-50,"relative sweep catches a target crossing between off-axis endpoints")
	setup();shoot();runtime.sweep_world=func(a,b,_r):return .2 if a.distance_to(b)>1.0 else 1.0
	runtime.after_motion(.1)
	check(player.health.current==player.health.maximum and runtime.charged_rifts.items[0].length<brain.config.charged_range_m,"world stops fast arrow and residual path")
	runtime.after_motion(1.0)
	check(player.health.current==player.health.maximum,"area cannot damage beyond world endpoint")
	setup();shoot();runtime.after_motion(.1);player.position.x=1.0
	runtime.sweep_world=func(_a,_b,_r):return .5
	runtime.after_motion(.4)
	check(player.health.current==player.health.maximum-50,"residual cannot reach through lateral world cover")
	setup();brain._start("charged");ranger.set_control(1.0,true);brain.tick(3.0)
	check(runtime.charged_rifts.items.is_empty(),"freeze before release cancels area")
	setup();shoot();ranger.set_control(1.0,true);runtime.after_motion(.5)
	check(player.health.current==player.health.maximum-58,"freeze after release preserves committed arrow and area")
	setup();player.set_damage_immunity(true);shoot()
	var count:=0
	while not runtime.charged_rifts.items.is_empty() and count<700:
		runtime.after_motion(.01);count+=1
	check(count<=601 and runtime.charged_rifts.items.is_empty(),"finite six-second lifetime")
	setup();player.set_damage_immunity(true)
	for i in int(brain.config.charged_rift_max_areas):shoot()
	check(runtime.charged_rifts.items.size()==int(brain.config.charged_rift_max_areas),"bounded multiple areas")
	brain._start("charged");check(runtime.charged_rifts.items.size()==int(brain.config.charged_rift_max_areas) and brain.state=="recovery","full capacity skips additional charged step")
	runtime.remove_actor(ranger)
	check(runtime.charged_rifts.items.is_empty() and runtime.projectiles.is_empty(),"source removal clears paths and arrows")
	runtime.clear();player.free();ranger.free()
	print("CHARGED_RANGER ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
