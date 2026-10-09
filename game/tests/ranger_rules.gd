extends SceneTree
const Runtime = preload("res://combat/enemies/enemy_runtime.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
var failures: Array[String] = []
var checks := 0
var combat
var catalog
var runtime
var player
var ranger
var brain
var rolls := 0
var attack_starts := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func make_actor(id: String, handle: int):
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	actor.configure(combat.actor(id), abilities, combat.dodge() if id == "player" else null, handle, 0 if id == "player" else 1)
	root.add_child(actor)
	return actor
func run() -> void:
	combat = preload("res://content/combat/combat_loader.gd").new().load_catalog()
	catalog = preload("res://content/enemies/enemy_loader.gd").new().load_catalog(combat)
	check(catalog != null, "new enemy data validates")
	player = make_actor("player",1)
	ranger = make_actor("elite_ranger",2)
	player.position = Vector3(0,0,-6)
	runtime = Runtime.new()
	runtime.configure(player,0.35,func(a): return a.position + Vector3.UP,func(_a,_b,_r): return 1.0)
	brain = runtime.add(ranger,catalog.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_b):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_areas,_settings):return true,"seed":42})
	brain.action_started.connect(func(id,_cast):
		if id == "roll": rolls += 1
		else: attack_starts += 1)
	brain.tick(.01)
	check(brain.attack_id == "fast" and brain.state == "windup", "first committed attack is fast shot")
	brain.tick(brain.windup_duration)
	check(runtime.projectiles.size() == 1, "fast cue emits one arrow")
	check(is_zero_approx(runtime.projectiles[0].direction.y), "ranger arrows follow a horizontal telegraph plane")
	var hp: float = player.health.current
	runtime.after_motion(.5)
	check(player.health.current < hp, "fast swept arrow hits across large timestep")
	player.health.restore()
	runtime.sweep_world = func(_a,_b,_r): return .1
	brain._start("fast"); brain.tick(brain.windup_duration); runtime.after_motion(.5)
	check(player.health.current == player.health.maximum, "wall before player blocks fast arrow")
	runtime.sweep_world = func(_a,_b,_r):return 1.0
	player.position = Vector3(0,0,-.3)
	brain._start("volley"); brain.tick(brain.windup_duration)
	check(runtime.projectiles.size() == int(brain.config.volley_count), "volley emits configured count")
	# Includes the vertical distance from an enlarged ranger's raised bow.
	runtime.after_motion(.5)
	check(is_equal_approx(player.health.maximum-player.health.current,brain.config.volley_damage), "point blank volley damages once")
	player.health.restore();runtime.projectiles.clear()
	player.position = Vector3(0,0,-6)
	brain._start("fast");brain.tick(brain.windup_duration)
	player.position = Vector3(4,0,-6)
	var arrow_height: float = runtime.projectiles[0].position.y
	runtime.after_motion(.5)
	check(runtime.projectiles.size() == 1 and is_equal_approx(runtime.projectiles[0].position.y, arrow_height), "missed arrow flies past aim distance without diving into ground or homing")
	runtime.projectiles.clear()
	player.position = Vector3(0,0,-6)
	brain._start("rain")
	var locked: Vector3 = brain.target_point
	player.position.x += 5
	brain.tick(brain.windup_duration)
	check(runtime.rains.size() == 1 and runtime.rains[0].center == locked, "rain locks the original ground target")
	runtime.after_motion(brain.config.rain_delay_sec)
	check(player.health.current == player.health.maximum, "leaving telegraph avoids rain")
	runtime.rains.clear();player.position=locked
	brain._start("rain");brain.tick(brain.windup_duration)
	player.set_damage_immunity(true);runtime.after_motion(brain.config.rain_delay_sec)
	check(player.health.current==player.health.maximum, "rain respects shared damage immunity")
	player.set_damage_immunity(false);runtime.rains.clear()
	brain._start("rain");brain.tick(brain.windup_duration);runtime.after_motion(10.0)
	check(is_equal_approx(player.health.maximum-player.health.current,brain.config.rain_damage*brain.config.rain_pulses) and runtime.rains.is_empty(), "rain finite pulses do not multiply by visual arrows")
	brain._start("rain");ranger.set_control(1.0,true);brain.tick(2.0)
	check(runtime.rains.is_empty() and brain.state != "windup", "freeze before cue cancels rain")
	ranger.set_control(1.0,false);brain.tick(.01)
	check(brain.state == "recovery", "unfreeze enters interrupt recovery without old cue")
	player.position = Vector3(0,0,-1)
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain.threat_age=0
	brain.tick(.1);check(brain.state!="rolling", "roll cannot react instantly")
	brain.state="idle";brain.tick(.15)
	check(brain.state=="rolling" and rolls==1, "one delayed roll starts")
	check(is_equal_approx(brain.roll_distance,brain.config.roll_distance_m) and is_equal_approx(ranger.forced_velocity.length()*brain.roll_duration,brain.config.roll_distance_m),"open path uses full roll distance and matching speed")
	brain.tick(1.0);brain.roll_cooldown=0;brain.tick(.3)
	check(rolls==1 and brain.state=="windup", "roll token requires attack despite expired cooldown")
	brain.tick(brain.windup_duration);brain.tick(brain.recovery_duration+.01)
	check(brain.roll_ready,"completed counterattack rearms roll")
	brain.roll_path=func(_a,_b):return false
	brain.tick(.3)
	check(brain.state!="rolling", "invalid roll path cannot start movement")
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain._roll_retry_left=0;brain.threat_age=brain.config.roll_reaction_sec
	brain.roll_path=func(_a,motion):return motion.length()<=brain.config.roll_min_distance_m+.001
	brain.tick(.01)
	check(brain.state=="rolling" and is_equal_approx(brain.roll_distance,brain.config.roll_min_distance_m),"blocked long path can choose configured shorter safe roll")
	brain.roll_path=func(_a,_b):return true
	# Integrate commanded displacement with a timestep that does not divide duration.
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain._roll_retry_left=0;brain.threat_age=brain.config.roll_reaction_sec
	var travel := Vector3.ZERO
	brain.tick(.07)
	travel += ranger.forced_velocity * .07
	var planned: float = brain.roll_distance
	while brain.state == "rolling":
		brain.tick(.07)
		travel += ranger.forced_velocity * .07
	check(is_equal_approx(travel.length(), planned), "partial final roll step preserves full configured displacement")
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain._roll_retry_left=0;brain.threat_age=brain.config.roll_reaction_sec
	var midpoint: float = (brain.config.roll_min_distance_m + brain.config.roll_distance_m) / 2.0
	brain.roll_path=func(_a,motion):return motion.length()<=midpoint+.001
	brain.tick(.01)
	check(is_equal_approx(brain.roll_distance, midpoint), "intermediate safe distance can be selected")
	brain.roll_path=func(_a,_b):return true
	for i in 2000:
		brain.tick(.02)
		runtime.projectiles.clear();runtime.rains.clear()
	check(attack_starts>5 and rolls<attack_starts,"persistent close threat cannot starve attacks with rolls")
	for attack in ["fast", "volley", "rain"]:
		runtime.projectiles.clear();runtime.rains.clear()
		brain._start(attack)
		var old_hp: float = ranger.health.current
		ranger.receive_hit(1.0)
		ranger.apply_knockback(Vector3.RIGHT, 8.0, .25)
		check(ranger.health.current < old_hp and ranger.stagger_left == 0.0 and ranger.motor.impulse_left == 0.0, "ranger takes damage without normal hit stun or knockback")
		brain.tick(brain.windup_duration)
		check(brain.state in ["recovery", "sequence_gap"] and (not runtime.projectiles.is_empty() or not runtime.rains.is_empty()), "ordinary hit cannot cancel " + attack)
	# Pursuit at the player's real melee reach, including pressure accumulated mid-cast.
	player.health.restore();ranger.health.restore()
	player.position = Vector3(0,0,-3.2)
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain._roll_retry_left=0;brain.threat_age=0
	brain._start("fast")
	var old_rolls := rolls
	var old_attacks := attack_starts
	for frame in 450:
		if frame % 10 == 0: ranger.receive_hit(1.0)
		brain.tick(.02)
		runtime.projectiles.clear();runtime.rains.clear()
	check(rolls >= old_rolls + 2, "repeated melee pressure beyond old trigger range reliably causes multiple rolls")
	check(attack_starts >= old_attacks + 2, "pursuit still allows readable committed counterattacks")
	brain.state="idle";brain.roll_ready=true;brain.roll_cooldown=0;brain._roll_retry_left=0;brain.threat_age=brain.config.roll_reaction_sec
	brain.roll_path=func(_a,_motion):return false
	brain.tick(.01)
	check(brain.state != "rolling" and brain._roll_retry_left > 0.0, "blocked escape throttles path checks instead of teleporting")
	brain.roll_path=func(_a,_motion):return true
	brain._start("rain");brain.tick(brain.windup_duration)
	brain._start("fast");brain.tick(brain.windup_duration)
	runtime.remove_actor(ranger)
	check(runtime.rains.is_empty() and runtime.projectiles.is_empty() and runtime.brains.is_empty(),"refresh retirement clears arrows areas and brain")
	check(combat.ability("slash.3").thrust_width == 1.8,"latest thrust width preserved")
	runtime.clear();player.free();ranger.free()
	print("RANGER_RULES ",JSON.stringify({"checks":checks,"failures":failures,"attacks":attack_starts,"rolls":rolls}))
	quit(0 if failures.is_empty() else 1)
