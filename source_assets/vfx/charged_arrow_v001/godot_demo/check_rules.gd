extends SceneTree
const Rules = preload("res://rules.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func run_mode(mode: String, data: Dictionary):
	var r = Rules.new()
	r.configure(data,Vector3(0,1.95,0.825))
	r.reset(mode)
	for i in 360: r.step(1.0/30.0)
	return r
func _initialize() -> void:
	var data: Dictionary = Rules.load_config("res://data/demo_rules.json")
	check(data.is_read_only() and data.skill.is_read_only(),"Immutable validated definitions")
	check((data.skill.lock_sec+data.skill.range_m/data.skill.speed_mps)*data.target.walk_mps < data.skill.arrow_radius_m+data.target.radius_m,"Maximum-range lateral displacement after lock remains inside the swept hit radius")
	var stand = run_mode("stand",data)
	check(stand.arrow_count==1,"Standing target swept exactly once")
	check(stand.scar_count==11,"6 seconds, 0.5-second ticks, endpoint excluded")
	check(is_equal_approx(stand.health,2.0),"Configured arrow and scar damage")
	var ticks: Array = stand.events.filter(func(e):return e.kind=="scar")
	for i in ticks.size():
		check(is_equal_approx(ticks[i].time,stand.fire_time+(i+1)*data.skill.trail_tick_sec),"Exact scar tick "+str(i))
	check(not stand.scar_active(),"Scar expires")
	var walk = run_mode("walk",data)
	check(walk.arrow_count==1,"Walking after release is too slow at demonstration distance")
	check(walk.scar_count==0,"Walking out avoids residual pulses")
	var dodge = run_mode("dodge",data)
	check(dodge.arrow_count==0 and dodge.health==data.target.health,"Dodge avoids the arrow and scar")
	var entry = run_mode("trail",data)
	check(entry.arrow_count==0 and entry.scar_count>0,"Stepping into scar takes periodic damage")
	check(entry.events.filter(func(e):return e.kind=="scar")[0].time>=data.skill.charge_sec+data.target.trail_entry_delay_sec,"No damage before occupation")
	var pause = Rules.new()
	pause.configure(data,Vector3(0,1.95,0.825))
	pause.step(data.skill.charge_sec+data.skill.trail_tick_sec)
	var previous: Array = [pause.clock,pause.target,pause.health,pause.events.duplicate(true)]
	pause.step(0.0)
	check([pause.clock,pause.target,pause.health,pause.events]==previous,"Pause freezes simulation")
	var coarse = Rules.new()
	coarse.configure(data,Vector3(0,1.95,0.825))
	coarse.step(12.0)
	check(coarse.events==stand.events or (coarse.arrow_count==stand.arrow_count and coarse.scar_count==stand.scar_count),"Coarse steps preserve high-speed sweep and tick count")
	var before: int = coarse.events.size()
	coarse.step(20.0)
	check(coarse.events.size()==before,"No residual damage after expiration")
	var manual = Rules.new()
	manual.configure(data,Vector3(0,1.95,0.825))
	manual.reset("manual")
	manual.step(data.skill.charge_sec-data.skill.lock_sec)
	var direction: Vector3 = manual.direction
	manual.step(data.skill.lock_sec,Vector3.FORWARD)
	check(manual.direction.is_equal_approx(direction),"Locked direction does not track target")
	check(manual.dodge(Vector3.FORWARD),"Manual dodge permitted")
	check(not manual.dodge(Vector3.FORWARD),"Dodge cooldown")
	manual.step(0.0)
	check(manual.invulnerable(),"Dodge grants only configured test immunity")
	print("CHARGED_ARROW_RULES ",JSON.stringify({"checks":checks,"failures":failures,"stand_ticks":stand.scar_count,"walk_hits":walk.arrow_count,"dodge_hits":dodge.arrow_count}))
	quit(0 if failures.is_empty() else 1)
