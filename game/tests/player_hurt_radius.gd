extends "res://tests/ranger_rules.gd"

func fire_at_offset(offset_m: float, radius: float, immune: bool = false, wall: bool = false) -> float:
	player.health.restore()
	player.set_damage_immunity(immune)
	player.position=Vector3(0,0,-6)
	runtime.target_radius=radius
	runtime.projectiles.clear()
	runtime.sweep_world=func(_a,_b,_r):return 1.0
	brain._start("fast");brain.tick(brain.windup_duration)
	player.position.x=offset_m
	if wall:runtime.sweep_world=func(_a,_b,_r):return .1
	runtime.after_motion(.5)
	return player.health.maximum-player.health.current

func run() -> void:
	combat=preload("res://content/combat/combat_loader.gd").new().load_catalog()
	catalog=preload("res://content/enemies/enemy_loader.gd").new().load_catalog(combat)
	player=make_actor("player",1);ranger=make_actor("elite_ranger",2)
	runtime=Runtime.new()
	runtime.configure(player,combat.player_hurt_radius(),func(a):return a.position+Vector3.UP,func(_a,_b,_r):return 1.0)
	brain=runtime.add(ranger,catalog.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_b):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_a,_c):return true,"seed":42})
	var body_radius: float=preload("res://presentation/combat/player_presentation.tres").body_shape.radius
	check(is_equal_approx(body_radius,.23),"movement capsule stays unchanged")
	check(is_equal_approx(combat.player_hurt_radius(),.3),"new hurt radius loads from validated JSON")
	check(is_zero_approx(fire_at_offset(.45,body_radius)),"previous radius misses the reproduced grazing arrow")
	check(fire_at_offset(.45,combat.player_hurt_radius())>0,"new radius accepts grazing arrow")
	check(fire_at_offset(-.45,combat.player_hurt_radius())>0,"grazing hit is symmetric")
	check(is_zero_approx(fire_at_offset(.5,combat.player_hurt_radius())),"outside expanded boundary still misses")
	check(is_zero_approx(fire_at_offset(.45,combat.player_hurt_radius(),true)),"damage immunity still protects player")
	check(is_zero_approx(fire_at_offset(.45,combat.player_hurt_radius(),false,true)),"wall cover still blocks arrows")
	check(load("res://app/combat_training.gd").can_instantiate() and load("res://app/run_room.gd").can_instantiate(),"both scene entry scripts compile")
	runtime.clear();player.free();ranger.free()
	print("PLAYER_HURT_RADIUS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
