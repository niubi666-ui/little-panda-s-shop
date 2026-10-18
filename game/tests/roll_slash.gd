extends SceneTree
## Real actor + build runtime + collision verification for the roll-cancel primary variant.
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const BuildResolver = preload("res://combat/builds/build_resolver.gd")
const Runtime = preload("res://combat/builds/build_runtime.gd")
const Melee = preload("res://combat/effects/melee_resolver.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
var combat
var builds
var resolver := BuildResolver.new()
var actors: Array = []
var failures: Array[String] = []
var checks := 0
var distances: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func actor(id: String, team: int, point: Vector3 = Vector3.ZERO):
	var result := Actor.new()
	var definition = combat.actor(id)
	var abilities: Array[Catalog.Ability] = []
	for ability_id in definition.attacks: abilities.append(combat.ability(ability_id))
	result.configure(definition, abilities, combat.dodge() if team == 0 else null, actors.size() + 1, team)
	root.add_child(result)
	result.position = point
	result.collision_mask = 0
	actors.append(result)
	return result
func setup(selections: Array = []) -> Dictionary:
	var p = actor("player", 0)
	var runtime := Runtime.new()
	runtime.configure(builds, p, func(): return actors, func(_a,_b): return null)
	p.runner.committed.connect(runtime.on_committed)
	p.runner.cue_reached.connect(runtime.on_cue)
	p.runner.finished.connect(runtime.on_finished)
	var melee := Melee.new()
	melee.set_damage_modifier(runtime.melee_damage)
	melee.set_direct_damage_executor(runtime.apply_melee_damage)
	melee.enemy_contact.connect(runtime.on_melee_contact)
	melee.confirmed_hit.connect(runtime.on_melee_hit)
	var program := resolver.resolve({"selections": selections, "revision": 1})
	check(not program.is_empty(), "valid primary fixture")
	check(runtime.set_program(program) and p.set_action_program(program.actions, combat), "inject matching primary plan")
	return {"p":p,"runtime":runtime,"melee":melee,"program":program}
func clean(f: Dictionary) -> void:
	f.runtime.clear_room()
	for a in actors: a.free()
	actors.clear()
func start_roll(f: Dictionary, age: float = .2, direction: Vector3 = Vector3.FORWARD) -> void:
	f.p.movement = direction
	f.p.request_dodge()
	f.p.step(1.0/60)
	while f.p.dodge_age < age: f.p.step(1.0/60)
	f.p.movement = Vector3.ZERO
func slash(f: Dictionary, delta: float = 1.0/60) -> Vector3:
	var start: Vector3 = f.p.position
	f.p.request_action("primary")
	f.p.step(delta)
	check(f.p.is_roll_attack_cast() and f.p.runner.busy(), "roll click starts configured attack")
	check(f.p.dodge_left == 0 and not f.p.invulnerable(), "roll and iframes stop on click")
	check(f.p.position.distance_to(start) > .01, "first click frame already moves: no stationary windup")
	return start
func finish(f: Dictionary, dt: float = 1.0/60) -> void:
	for i in 240:
		if not f.p.runner.busy(): break
		f.p.step(dt)
		f.melee.resolve(f.p, actors)
		f.runtime.tick(dt)

func run() -> void:
	combat = CombatLoader.new().load_catalog()
	builds = BuildLoader.new().load_catalog()
	check(combat != null and builds != null, "content loads")
	if combat == null or builds == null: quit(1); return
	resolver.configure(builds)
	await physics_frame
	for dt in [1.0/30, 1.0/60, 1.0/120]:
		for age in [.05,.28,.62]:
			var f := setup()
			start_roll(f, age)
			# Turn aim away from the roll; committed slash uses the newly aimed direction.
			f.p.facing = Vector3.RIGHT
			var start := slash(f, dt)
			var last: Vector3 = f.p.position
			while f.p.runner.elapsed + dt < f.p.runner.ability.windup + f.p.dodge.attack_duration:
				f.p.step(dt)
				check(f.p.position.distance_to(last) > .0001, "continuous travel through roll landing and slash")
				last = f.p.position
			finish(f, dt)
			var distance: float = f.p.position.distance_to(start)
			distances.append(distance)
			check(absf(distance - 6.0) < .001 and absf(f.p.position.z-start.z) < .001, "exact aimed 6m across timestep / roll phase")
			check(f.p.runner.action_id == "primary" and f.p.runner.cast_context == f.program.actions.primary, "primary snapshot retained")
			clean(f)
	await hit_build_case()
	await collision_case()
	exit_mobility_cases()
	primary_followup_cases()
	normal_roll_mobility_cases()
	interrupt_cases()
	var report := {"checks":checks,"failures":failures,"distances_m":distances}
	FileAccess.open("res://../builds/roll_slash_rules.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROLL_SLASH ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func hit_build_case() -> void:
	var f := setup([{"upgrade_id":"fire_core","action_id":"primary","rank":2}, {"upgrade_id":"primary_reach","action_id":"primary","rank":1}])
	start_roll(f)
	var start: Vector3 = f.p.position
	var near = actor("brute",1,start+Vector3(0,0,-3))
	var far = actor("brute",1,start+Vector3(0,0,-5.7))
	var side = actor("brute",1,start+Vector3(2.7,0,-3.5))
	var hits: Dictionary = {}
	var damages: Array = []
	var elements: Array = []
	f.melee.confirmed_hit.connect(func(_s,t,_c,_a,amount): hits[t.handle] = int(hits.get(t.handle,0))+1; damages.append(amount))
	f.runtime.element_presented.connect(func(fact): elements.append(fact))
	slash(f)
	while f.p.runner.elapsed + 1.0/60 < f.p.runner.ability.windup:
		f.p.step(1.0/60);f.melee.resolve(f.p,actors)
	check(hits.is_empty(), "remaining roll and landing carry do not deal early invisible hits")
	finish(f)
	check(hits.size() == 3 and hits.values().all(func(n):return n == 1), "swept slash hits near/far/range-buffed targets once each")
	var expected: float = combat.dodge().attack.damage * float(f.program.actions.primary.damage_scale)
	check(damages.size() == 3 and damages.all(func(d):return is_equal_approx(d,expected)), "same primary damage multiplier")
	check(elements.filter(func(e):return e.event == "applied" and e.element == "fire").size() == 3, "primary elemental effect applies to every direct target")
	check(f.p.reach_scale() == f.program.actions.primary.reach_scale, "primary range bonus retained")
	clean(f)

func collision_case() -> void:
	var f := setup()
	start_roll(f)
	var start: Vector3 = f.p.position
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.05
	shape.shape=capsule;shape.position.y=.525;f.p.add_child(shape)
	f.p.collision_mask=1
	var wall := StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var box := CollisionShape3D.new();var mesh := BoxShape3D.new();mesh.size=Vector3(5,3,.3);box.shape=mesh;wall.add_child(box)
	root.add_child(wall);wall.position=start+Vector3(0,1,-3)
	await physics_frame
	slash(f)
	finish(f)
	var distance: float = start.distance_to(f.p.position)
	check(distance > 2.5 and distance < 2.7, "swept capsule stops at wall without sliding or penetration")
	wall.free();clean(f)

func normal_roll_mobility_cases() -> void:
	for dir in 8:
		var f := setup()
		var direction := Vector3(sin(dir*TAU/8),0,-cos(dir*TAU/8))
		f.p.movement=direction;f.p.request_dodge()
		for i in 21: f.p.step(1.0/60)
		check(is_equal_approx(f.p.position.length(),3.4), "normal roll retains original forced distance")
		f.p.movement=direction.rotated(Vector3.UP,PI/2)
		f.p.step(1.0/60)
		check(f.p.velocity.is_equal_approx(f.p.movement*f.p.definition.speed), "roll tail immediately obeys new movement direction")
		check(f.p.dodge_left>0 and not f.p.invulnerable(), "tail retains counter window without extra invulnerability")
		var position: Vector3 = f.p.position
		var age: float = f.p.dodge_age
		f.p.step(0)
		check(f.p.position==position and f.p.dodge_age==age,"pause freezes mobile roll tail")
		f.p.movement=Vector3.ZERO;f.p.step(1.0/60)
		check(f.p.position.is_equal_approx(position) and f.p.velocity.is_zero_approx(), "released direction stops tail movement")
		f.p.movement=direction;f.p.set_build_movement_multiplier(1.5);f.p.set_control(.5,false)
		f.p.step(1.0/60)
		check(is_equal_approx(f.p.velocity.length(),f.p.definition.speed*.75),"tail movement respects build speed and slow")
		f.p.set_control(1,false);f.p.movement=Vector3.ZERO
		slash(f)
		check(f.p.runner.ability.id=="roll_slash","moving during stand-up still allows approved roll slash")
		clean(f)

func exit_mobility_cases() -> void:
	for age in [.05,.28,.62]:
		var f := setup()
		start_roll(f, age)
		var start := slash(f)
		# Hold movement throughout the attack: slash owns its distance only until its last hit frame.
		f.p.movement = Vector3.RIGHT
		while f.p.runner.busy(): f.p.step(1.0/60)
		check(f.p.runner.active_this_step, "zero recovery keeps the final active interval")
		check(is_equal_approx(start.distance_to(f.p.position),6.0), "held movement does not add distance during slash")
		var victim = actor("brute",1,f.p.position+Vector3.FORWARD)
		var hp: float = victim.health.current
		f.melee.resolve(f.p,actors)
		check(victim.health.current<hp, "last active frame still damages with zero recovery")
		var end: Vector3 = f.p.position
		f.p.step(1.0/60)
		check(is_zero_approx(f.p.runner.cooldown_for("primary")), "slash completion leaves no extra primary cooldown")
		check(f.p.position.x>end.x and is_equal_approx(f.p.velocity.x,f.p.definition.speed), "first post-slash frame moves at full speed")
		check(not f.p.runner.active_this_step, "free movement does not prolong melee hits")
		clean(f)

func primary_followup_cases() -> void:
	var camera := Camera3D.new(); root.add_child(camera)
	for dt in [1.0/30, 1.0/60, 1.0/120]:
		for age in [.05, .28, .62]:
			for timing in ["early", "active", "after"]:
				var f := setup()
				var input := InputAdapter.new(f.p, camera)
				start_roll(f, age)
				slash(f, dt)
				var roll_cast: int = f.p.runner.cast_id
				if timing == "active":
					while f.p.runner.phase() == "windup": f.p.step(dt)
				elif timing == "after": finish(f, dt)
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; input.event(click)
				click = InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT; click.pressed = false; input.event(click)
				finish(f, dt)
				var label := " %s age %.2f dt %.4f" % [timing, age, dt]
				check(f.p.runner.cast_id == roll_cast and f.p.runner.active_this_step, "followup preserves the complete dash and final hit" + label)
				# A target only entering on the final swept frame must still receive the dash hit.
				var victim = actor("brute", 1, f.p.position + Vector3.FORWARD)
				var hp: float = victim.health.current
				f.melee.resolve(f.p, actors)
				check(victim.health.current < hp, "queued primary does not discard the last dash hit" + label)
				check(is_zero_approx(f.p.runner.cooldown_for("primary")), "dash leaves no cooldown gap" + label)
				check(f.p.buffered_action_id == "primary", "one followup click survives through the dash" + label)
				f.p.step(dt); f.melee.resolve(f.p, actors)
				check(f.p.runner.cast_id == roll_cast + 1 and f.p.runner.ability.id == "slash.1", "first post-dash step begins normal combo" + label)
				check(f.p.combo_index == 1 and not f.p.is_roll_attack_cast(), "followup is first combo hit, not another dash" + label)
				var post_dash_hp: float = victim.health.current
				f.p.step(combat.ability("slash.1").windup); f.melee.resolve(f.p, actors)
				check(victim.health.current < post_dash_hp, "followup deals its own hit at the normal cue" + label)
				finish(f, dt)
				check(f.p.runner.cast_id == roll_cast + 1, "single followup click cannot auto-repeat" + label)
				clean(f)
	camera.free()

func interrupt_cases() -> void:
	var f := setup()
	f.p.request_action("primary");f.p.step(.01)
	check(f.p.runner.ability.id == "slash.1", "ordinary click stays normal combo")
	f.p.request_dodge();f.p.step(.01)
	check(f.p.runner.cooldown_for("primary") > 0, "roll cancelled prior slash with cooldown remaining")
	slash(f)
	check(f.p.runner.cooldown_for("primary") > 0, "roll counter replaces prior cooldown and owns primary cooldown")
	f.p.step(.2)
	var pos: Vector3 = f.p.position
	var elapsed: float = f.p.runner.elapsed
	for i in 5: f.p.step(0)
	check(f.p.position == pos and f.p.runner.elapsed == elapsed, "pause freezes dash and clock")
	f.p.receive_hit(1)
	f.p.step(.1)
	check(not f.p.runner.busy() and f.p.position == pos, "hit interruption stops remaining dash")
	clean(f)
	for reason in ["control","death","cancel"]:
		f=setup();start_roll(f);slash(f);f.p.step(.2)
		pos=f.p.position
		match reason:
			"control": f.p.set_control(0,true)
			"death": f.p.health.apply(10000,false)
			"cancel": f.p.cancel("room")
		f.p.step(.1)
		check(not f.p.runner.busy() and f.p.position == pos, reason+" stops dash")
		clean(f)
	f=setup()
	f.p.request_action("primary");f.p.request_dodge();f.p.step(.01)
	check(f.p.dodge_left > 0 and not f.p.runner.busy(), "pre-roll click does not silently become a roll attack")
	f.p.clear_intents();f.p.step(.1)
	check(f.p.dodge_left > 0, "no click keeps normal roll")
	clean(f)
