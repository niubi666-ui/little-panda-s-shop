extends SceneTree
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
const Planner = preload("res://rogue/encounters/encounter_planner.gd")
const Runtime = preload("res://combat/enemies/enemy_runtime.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Style = preload("res://presentation/combat/training_style.tres")
var failures: Array[String] = []
var world: Node3D
var combat
var enemies
var serial := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func actor(id: String, position: Vector3):
	var a := Actor.new()
	serial += 1
	var abilities: Array[Catalog.Ability] = []
	for ability_id in combat.actor(id).attacks: abilities.append(combat.ability(ability_id))
	a.configure(combat.actor(id), abilities, combat.dodge() if id == "player" else null, serial, 0 if id == "player" else 1)
	a.position = position
	a.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	shape.shape = Style.actor_presentations[id].body_shape
	shape.position.y = Style.actor_presentations[id].body_height
	a.add_child(shape)
	world.add_child(a)
	return a
func origin(a) -> Vector3: return a.global_position + Vector3.UP * Style.actor_presentations[a.definition.id].body_height
func sweep(from: Vector3, to: Vector3, radius: float) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = from
	query.motion = to - from
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.cast_motion(query)[0]
func runtime(player):
	var r := Runtime.new()
	r.configure(player, Style.actor_presentations.player.body_shape.radius, origin, sweep)
	return r
func add(r, a):return r.add(a, enemies.profile(a.definition.id), Callable(), func(_a,_b): return true, func(_a,_d): return true)
func reset() -> void:
	for child in world.get_children(): child.free()
func run() -> void:
	combat = CombatLoader.new().load_catalog()
	var loader := EnemyLoader.new()
	enemies = loader.load_catalog(combat)
	check(enemies != null, "enemy catalog validates")
	if enemies == null:
		print(loader.errors)
		quit(1)
		return
	check(enemies.profile("crossbow").config.is_read_only(), "behavior definitions deeply readonly")
	var seen: Dictionary = {}
	for depth in [1,3,6,10,15,30]:
		var band: Dictionary = Planner.band_for(depth, enemies)
		for seed_value in 60:
			var plan: Dictionary = Planner.new().generate(str(seed_value), depth, 3, enemies)
			check(plan == Planner.new().generate(str(seed_value), depth, 3, enemies), "deterministic teams and loot")
			check(JSON.parse_string(JSON.stringify(plan)).waves.size() == plan.waves.size(), "plan value roundtrip")
			for wave in plan.waves:
				var cost := 0
				for id in wave.enemy_ids:
					cost += int(enemies.profile(id).budget_cost)
					seen[id] = true
				check(cost <= band.budget and cost >= band.budget * enemies.encounters.minimum_budget_fraction, "bounded difficulty spend")
				check(wave.enemy_ids.size() <= 3 and wave.drops.size() == wave.enemy_ids.size(), "spawn capacity and locked per-enemy loot")
	check(seen.size() == enemies.profiles.size(), "all five enemy types appear")
	var roles_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/roles.json"))
	var enc_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/encounters.json"))
	var loot_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot/enemies.json"))
	loot_data.content_version = "changed-test-loot"
	var changed = preload("res://content/enemies/enemy_catalog.gd").new(roles_data,enc_data,loot_data)
	var before_loot_change: Dictionary = Planner.new().generate("42",6,3,enemies)
	var after_loot_change: Dictionary = Planner.new().generate("42",6,3,changed)
	check(before_loot_change.waves.map(func(w):return w.enemy_ids) == after_loot_change.waves.map(func(w):return w.enemy_ids), "loot stream changes cannot reroll encounter teams")
	check(Planner.legal(15, 1, enemies).is_empty(), "no arbitrary fallback for insufficient capacity")
	world = Node3D.new()
	root.add_child(world)
	var player = actor("player", Vector3.ZERO)
	var bow = actor("crossbow", Vector3(0,0,-6))
	var r = runtime(player)
	var brain = add(r,bow)
	brain.tick(0.01)
	check(brain.state == "windup", "medium range crossbow telegraph")
	var aim: Vector3 = brain.locked_direction
	player.position.x = 3
	brain.tick(enemies.profile("crossbow").config.windup_sec)
	check(r.projectiles.size() == 1 and r.projectiles[0].direction == aim, "shot locks at windup and cannot track sideways dodge")
	var hp: float = player.health.current
	r.after_motion(0.1)
	check(player.health.current == hp and r.projectiles.size() == 1, "projectile flight is not instant damage")
	r.after_motion(1.0)
	check(player.health.current == hp, "sideways movement avoids projectile")
	brain.cancel()
	player.position = Vector3(0,0,-5)
	brain.tick(0.01)
	check(brain.state == "retreating" and bow.movement.z < 0.0, "close player forces retreat; no melee attack")
	player.position = Vector3.ZERO
	brain.cooldown = 0.0
	brain.tick(0.01)
	bow.receive_hit(1)
	brain.tick(1.0)
	check(brain.state == "staggered", "damage interrupts ranged windup")
	r.clear()
	reset()
	player = actor("player", Vector3.ZERO)
	var brute = actor("brute", Vector3(0,0,-3))
	var flag = actor("banner", Vector3(1,0,-3))
	var flag2 = actor("banner", Vector3(-1,0,-3))
	r = runtime(player)
	add(r,brute);add(r,flag);add(r,flag2)
	r.update_auras()
	check(is_equal_approx(brute.enemy_attack_multiplier,1.3) and is_equal_approx(brute.enemy_move_multiplier,1.3), "banner bonuses do not stack")
	brute.request_attack()
	brute.step(0.01)
	check(is_equal_approx(brute.runner.elapsed,0.013), "heavy windup runs faster in aura")
	flag.receive_hit(flag.health.maximum)
	flag2.position.x = 30
	r.update_auras()
	check(brute.enemy_attack_multiplier == 1.0 and not brute.aura_active, "death and leaving radius remove aura")
	brute.runner.cancel();brute.runner.cooldown = 0.0
	brute.request_attack();brute.step(0.01)
	check(is_equal_approx(brute.runner.elapsed,0.01), "next attack resumes ordinary timing")
	r.clear();reset()
	# Actual moving body and swept contact: standing still is hit, a lateral dodge is safe.
	for sidestep in [false,true]:
		player = actor("player", Vector3.ZERO)
		var spear = actor("charger", Vector3(0,0,-6))
		r = runtime(player);brain = add(r,spear)
		await physics_frame
		brain.tick(0.01)
		check(brain.state == "windup", "charge has committed telegraph")
		if sidestep: player.position.x = 3
		brain.tick(enemies.profile("charger").config.windup_sec)
		hp = player.health.current
		for i in 60:
			brain.tick(1.0/60.0);spear.step(1.0/60.0);brain.after_motion(r.target_radius)
			if brain.state == "recovery": break
			await physics_frame
		check((player.health.current == hp) == sidestep, "charge: lateral dodge avoids damage; standing in lane is hit")
		check(brain.state == "recovery" and is_equal_approx(brain.time_left,1.0), "charge ends with full vulnerable recovery")
		var after_hp: float = player.health.current
		brain.after_motion(r.target_radius)
		check(player.health.current == after_hp, "charge cannot hit twice")
		r.clear();reset()
	# World cover stops both a projectile and a charge.
	player = actor("player", Vector3.ZERO)
	bow = actor("crossbow", Vector3(0,0,-6))
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var box := BoxShape3D.new();box.size = Vector3(5,3,0.5)
	var collider := CollisionShape3D.new();collider.shape = box;wall.add_child(collider)
	world.add_child(wall);wall.position = Vector3(0,1,-3)
	await physics_frame
	r = runtime(player);r._shoot(bow, Vector3.BACK, enemies.profile("crossbow").config)
	hp = player.health.current
	r.after_motion(1.0)
	check(r.projectiles.is_empty() and player.health.current == hp, "cover absorbs swept red projectile")
	bow.free()
	var spear = actor("charger", Vector3(0,0,-6))
	brain = add(r,spear)
	brain.tick(0.01);brain.tick(enemies.profile("charger").config.windup_sec)
	for i in 60:
		brain.tick(1.0/60.0);spear.step(1.0/60.0);brain.after_motion(r.target_radius)
		if brain.state == "recovery": break
		await physics_frame
	check(brain.state == "recovery" and spear.position.z < -3 and player.health.current == hp, "wall stops charge and starts recovery")
	r.clear();reset()
	# All enemy roles can cross another enemy, including a committed charge.
	for ally_id in ["scout", "brute", "crossbow", "charger", "banner"]:
		player = actor("player", Vector3.ZERO)
		spear = actor("charger", Vector3(0,0,-6))
		var ally = actor(ally_id, Vector3(0,0,-3))
		r = runtime(player);brain = add(r,spear)
		await physics_frame
		check(not spear.test_move(spear.global_transform, Vector3(0,0,4)), "charge lane ignores ally: " + ally_id)
		check(not ally.test_move(ally.global_transform, Vector3(0,0,-3)), "ally can move through charger: " + ally_id)
		check(player.test_move(player.global_transform, Vector3(0,0,-3)), "player still collides with enemy: " + ally_id)
		brain.tick(0.01);brain.tick(enemies.profile("charger").config.windup_sec)
		hp = player.health.current
		for frame in 60:
			brain.tick(1.0/60.0);spear.step(1.0/60.0);brain.after_motion(r.target_radius)
			if brain.state == "recovery": break
			await physics_frame
		check(spear.position.z > ally.position.z and player.health.current < hp, "charge passes ally and hits player: " + ally_id)
		r.clear();reset()
	world.free()
	print("ENEMY_ROLES ",JSON.stringify({"failures":failures,"plans":360,"types":seen.keys()}))
	quit(0 if failures.is_empty() else 1)
