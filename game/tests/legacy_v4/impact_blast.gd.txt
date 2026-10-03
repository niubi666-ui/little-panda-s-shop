extends "res://tests/build_runtime.gd"
const Area = preload("res://combat/effects/area_damage.gd")
const Melee = preload("res://combat/effects/melee_resolver.gd")
const Caps = preload("res://combat/builds/projectile_capabilities.gd")

func run() -> void:
	_builds = BuildLoader.new().load_catalog()
	_combat = CombatLoader.new().load_catalog()
	_resolver.configure(_builds)
	check_area()
	for mode in ["melee", "arrow", "wave"]: check_contact(mode)
	check_split_combination()
	check_budget_and_limits()
	check_invalid()
	print("IMPACT_BLAST ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check_area() -> void:
	var a := make_actor("brute", 1)
	var b := make_actor("brute", 1)
	var ally := make_actor("player", 0)
	a.position = Vector3(1,0,0)
	b.position = Vector3(-1,0,0)
	var p: Dictionary = _builds.upgrade("impact_blast").ranks[0].duplicate(true)
	var plan := Area.plan(Vector3.ZERO, 0, -1, 10.0, p, [b,a,a,ally], func(_from,_to):return null)
	check(plan.size() == 2 and plan[0].handle == a.handle, "area dedup, team filter and stable tie order")
	check(Area.plan(Vector3.ZERO, 0, a.handle, 10.0, p, [a,b], func(_from,_to):return null).size() == 1, "primary excluded")
	p.include_primary = true
	check(Area.plan(Vector3.ZERO, 0, a.handle, 10.0, p, [a], func(_from,_to):return null).size() == 1, "explicit primary inclusion supported")
	var wall := func(_from, to): return Vector3.ZERO if to.x < 0 else null
	check(Area.plan(Vector3.ZERO, 0, -1, 10.0, p, [a,b], wall).size() == 1, "world occlusion filters only blocked victim")
	p.max_targets = 1
	check(Area.plan(Vector3.ZERO, 0, -1, 10.0, p, [a,b], func(_from,_to):return null).size() == 1, "target cap")
	p.max_targets = 6
	a.position = Vector3(float(p.radius_m),0,0)
	plan = Area.plan(Vector3.ZERO, 0, -1, 10.0, p, [a], func(_from,_to):return null)
	check(is_equal_approx(plan[0].damage, 10.0 * float(p.edge_ratio)), "edge damage falloff")
	a.free(); b.free(); ally.free()

func check_contact(mode: String) -> void:
	for lethal in [false, true]:
		var player := make_actor("player", 0)
		var victim := make_actor("brute", 1)
		var nearby := make_actor("brute", 1)
		victim.position = Vector3(0,0,-1)
		nearby.position = Vector3(1.5,0,-1)
		if lethal: victim.health.current = 1.0
		else:
			victim.dodge = _combat.dodge()
			victim.dodge_left = victim.dodge.duration
			victim.dodge_age = 0.0
		var runtime := Runtime.new()
		runtime.configure(_builds, player, func(): return [victim,nearby,nearby], func(_from,_to):return null, ["test_arrow"])
		var ranks := {"impact_blast": 1, "power": 1}
		if mode == "wave": ranks.wave = 1
		if not lethal: ranks.chain = 1
		runtime.set_program(_resolver.resolve(ranks))
		player.runner.committed.connect(runtime.on_committed)
		player.runner.cue_reached.connect(runtime.on_cue)
		var events: Array = []
		runtime.damage_applied.connect(func(_s,t,d,o): events.append([t.handle,d,o]))
		var base: float
		if mode == "melee":
			var melee := Melee.new()
			melee.enemy_contact.connect(runtime.on_melee_contact)
			melee.set_damage_modifier(runtime.melee_damage)
			start_cast(player)
			player.runner.tick(_combat.ability("slash.1").windup)
			melee.resolve(player, [victim])
			base = _combat.ability("slash.1").damage
		else:
			if mode == "arrow":
				runtime.fire_attack("test_arrow", Vector3.FORWARD)
				base = _builds.test_attack("test_arrow").damage
			else:
				start_cast(player)
				player.runner.tick(_combat.ability("slash.1").windup)
				base = _combat.ability("slash.1").damage * _builds.upgrade("wave").ranks[0].damage_ratio
			runtime.tick(0.001)
			runtime.tick(0.1)
		runtime.tick(0.001)
		var params: Dictionary = _builds.upgrade("impact_blast").ranks[0]
		var expected: float = base * _resolver.resolve(ranks).damage_scale * params.damage_ratio * lerpf(1.0, params.edge_ratio, 1.5 / params.radius_m)
		check(is_equal_approx(nearby.health.maximum - nearby.health.current, expected), "%s zero/lethal contact preserves point and snapshotted area damage: %s" % [mode, lethal])
		if not lethal: check(events.all(func(e):return e[2] != "chain"), "zero direct damage cannot chain via explosion damage")
		check(victim.health.current == (0.0 if lethal else victim.health.maximum), "default blast never double-hits primary")
		check(events.filter(func(e): return e[2] == "explosion").size() == 1, "one explosion damage event per victim")
		cleanup(runtime, [player,victim,nearby])

func check_split_combination() -> void:
	var player := make_actor("player", 0)
	var first := make_actor("brute", 1)
	var second := make_actor("brute", 1)
	first.position = Vector3(0,0,-1)
	var params: Dictionary = _builds.upgrade("split").ranks[0]
	second.position = Vector3.FORWARD * (1.0 - float(_builds.projectile("test_arrow").radius_m)) + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-params.spread_deg/2.0)) * 2.0
	var runtime := Runtime.new()
	runtime.configure(_builds, player, func(): return [first,second], func(_from,_to):return null, ["test_arrow"])
	runtime.set_program(_resolver.resolve({"split":1,"impact_blast":1}))
	var areas: Array = []
	runtime.area_emitted.connect(func(p,r): areas.append([p,r]))
	runtime.fire_attack("test_arrow", Vector3.FORWARD)
	runtime.tick(0.001)
	runtime.tick(0.07)
	check(runtime.projectiles().size() == 2 and areas.size() == 1, "parent can split and explode through shared root")
	check(runtime.diagnostics().budgets.values()[0] == _builds.limits().root_effect_budget - 4, "one initial, two children and one blast debit same budget")
	runtime.tick(0.2)
	check(areas.size() == 2, "split child may explode; blast does not recursively explode")
	check(areas[0][1] == _builds.upgrade("impact_blast").ranks[0].radius_m, "visual radius fact is authoritative radius")
	cleanup(runtime,[player,first,second])

func check_invalid() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	for entry in data.upgrades:
		if entry.effect_type == "explosion": entry.ranks[0].allowed_origins = ["explosion"]
	check(BuildLoader.new().decode(data) == null, "recursive blast origin rejected")
	check(not Caps.eligible(_builds.upgrade("impact_blast"), Caps.summarize(_builds,_resolver.resolve({}),[])), "no source cannot carry blast")
	check(Caps.eligible(_builds.upgrade("impact_blast"), Caps.summarize(_builds,_resolver.resolve({}),[],true)), "melee independently grants blast without self prerequisite")


func check_budget_and_limits() -> void:
	var player := make_actor("player",0)
	var victim := make_actor("brute",1)
	victim.position = Vector3(0,0,-1)
	var limited := LimitedCatalog.new()
	limited.base = _builds
	limited.limit_values = _builds.limits().duplicate(true)
	limited.limit_values.root_effect_budget = 2
	var runtime := Runtime.new()
	runtime.configure(limited,player,func():return [victim],func(_f,_t):return null,["test_arrow"])
	runtime.set_program(_resolver.resolve({"impact_blast":1,"split":1}))
	var areas: Array = []
	runtime.area_emitted.connect(func(p,r):areas.append([p,r]))
	runtime.fire_attack("test_arrow",Vector3.FORWARD)
	runtime.tick(0.001);runtime.tick(0.1)
	check(areas.size() == 1 and runtime.projectiles().is_empty() and runtime.diagnostics().rejected >= 2, "blast and child spawns cannot acquire a new root budget")
	cleanup(runtime,[player,victim])
	var Impact = preload("res://combat/builds/impact_effects.gd")
	var context := {"program":_resolver.resolve({"impact_blast":1}),"impact_counts":{}}
	var fact := {"origin":"direct_projectile","parent_id":"one","position":Vector3.ZERO,"target_handle":1,"damage":10.0}
	check(Impact.requests(context,fact).size() == 1 and Impact.requests(context,fact).is_empty(), "blast per-parent cap")
	for index in 8:
		fact.parent_id = str(index)
		var requests: Array = Impact.requests(context,fact)
		check(requests.size() == (1 if index < 3 else 0), "blast explicit per-root cap")
	var program: Dictionary = _resolver.resolve({"impact_blast":1}).duplicate(true)
	program.effects[0].params.allowed_origins = ["split_projectile"]
	context = {"program":program,"impact_counts":{}}
	check(Impact.requests(context,fact).is_empty(), "origin filter blocks initial projectile")
	fact.origin = "split_projectile"
	check(Impact.requests(context,fact).size() == 1, "origin filter explicitly enables split child")
