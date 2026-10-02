extends SceneTree
const Loader = preload("res://content/combat/combat_loader.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Runner = preload("res://combat/abilities/ability_runner.gd")
const Health = preload("res://combat/actors/health_runtime.gd")
const Resolver = preload("res://combat/effects/melee_resolver.gd")
const Encounter = preload("res://rogue/training_encounter.gd")
var failures: Array[String] = []
var deaths := 0
var cues := 0
var clears := 0
var waves := 0
var confirmed_hits := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loader := Loader.new()
	var catalog := loader.load_catalog()
	check(catalog != null, "valid catalog loads")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/prototype.json"))
	var schema = JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/combat_prototype.schema.json"))
	for defect in ["missing", "unknown", "reference", "duplicate", "fractional", "iframe", "knockback", "movement", "shape", "sector_width", "thrust_width", "thrust_angle", "old_version"]:
		var invalid: Dictionary = data.duplicate(true)
		match defect:
			"missing": invalid.abilities[0].erase("damage")
			"unknown": invalid.abilities[0].damge = 10
			"reference": invalid.actors[0].attack_ids = ["unknown"]
			"duplicate": invalid.abilities.append(invalid.abilities[0])
			"fractional": invalid.dodge.charges = 1.5
			"iframe": invalid.dodge.invulnerable_sec = 2.0
			"knockback": invalid.abilities[0].knockback_speed_mps = 5.0
			"movement": invalid.abilities[0].movement_speed_multiplier = -1.0
			"shape": invalid.abilities[0].hit_shape = "unknown"
			"sector_width": invalid.abilities[0].thrust_width_m = 1.0
			"thrust_width": invalid.abilities[2].thrust_width_m = 0.0
			"thrust_angle": invalid.abilities[2].angle_deg = 160.0
			"old_version": invalid.schema_version = 1
		var validator := Loader.new()
		check(validator.decode(invalid, schema, "test." + defect) == null and not validator.errors.is_empty(), "reject " + defect)
	check(catalog.player().attacks.is_read_only() and catalog.waves()[0].is_read_only(), "nested definitions are readonly")
	var health := Health.new(20)
	health.died.connect(func(): deaths += 1)
	check(health.apply(10, true) == 0 and health.current == 20, "invulnerable damage rejected")
	check(health.apply(0, false) == 0, "zero damage rejected")
	check(health.apply(30, false) == 20, "overkill clamped")
	health.apply(30, false)
	check(deaths == 1, "death exactly once")
	var runner := Runner.new()
	runner.cue_reached.connect(func(_cast, _id): cues += 1)
	var slash := catalog.ability("slash.1")
	check(runner.start(slash, Vector3.FORWARD), "first cast starts")
	check(not runner.start(slash, Vector3.FORWARD), "repeated cast rejected")
	runner.tick(slash.windup / 2)
	check(not runner.active_this_step, "no windup damage")
	runner.tick(2)
	check(runner.active_this_step and cues == 1, "large step crosses active exactly once")
	check(runner.claim_target(1) and not runner.claim_target(1), "per cast target dedup")
	runner.cancel()
	check(not runner.active_this_step, "cancel clears pending hit")
	check_player_attack_sectors(catalog)
	check_thrust_shape(catalog)
	var player := make_actor(catalog, "player", 0, 1)
	var enemy := make_actor(catalog, "scout", 1, 2)
	enemy.position = Vector3(0, 0, -1)
	player.runner.start(slash, Vector3.FORWARD)
	player.runner.tick(slash.windup)
	var resolver := Resolver.new()
	resolver.confirmed_hit.connect(func(source, target, cast_id, ability_id, damage):
		confirmed_hits += 1
		check(source == player and target == enemy and cast_id == player.runner.cast_id and ability_id == slash.id and damage == slash.damage, "confirmed hit contains committed result"))
	resolver.resolve(player, [player, enemy, enemy])
	resolver.resolve(player, [enemy])
	check(enemy.health.current == enemy.health.maximum - slash.damage, "same swing duplicate targets only once")
	check(confirmed_hits == 1, "same swing emits one confirmed hit")
	player.runner.cancel()
	player.runner.cooldown = 0
	player.runner.start(slash, Vector3.BACK)
	player.runner.tick(slash.windup)
	var hp := enemy.health.current
	resolver.resolve(player, [enemy])
	check(enemy.health.current == hp, "outside sector is safe")
	check(confirmed_hits == 1, "whiff emits no confirmed hit")
	player.runner.cancel()
	player.runner.cooldown = 0
	player.request_dodge()
	player.step(.01)
	check(player.charges == catalog.dodge().charges - 1 and player.invulnerable(), "dodge charge and iframe")
	check(player.receive_hit(10) == 0, "dodge prevents damage")
	var enemy_resolver := Resolver.new()
	enemy_resolver.confirmed_hit.connect(func(_source, _target, _cast, _id, _damage): confirmed_hits += 1)
	enemy.runner.start(catalog.ability("enemy.swipe"), Vector3.BACK)
	enemy.runner.tick(catalog.ability("enemy.swipe").windup)
	enemy_resolver.resolve(enemy, [player])
	check(confirmed_hits == 1, "invulnerable contact emits no confirmed hit")
	enemy.runner.cancel()
	enemy.runner.cooldown = 0.0
	player.step(catalog.dodge().duration)
	check(not player.invulnerable(), "iframe expires")
	player.step(catalog.dodge().recharge)
	check(player.charges == catalog.dodge().charges, "charge recharges")
	enemy.runner.start(catalog.ability("enemy.swipe"), Vector3.BACK)
	enemy.receive_hit(1)
	check(not enemy.runner.busy() and enemy.stagger_left > 0, "scout attack interrupted")
	var brute := make_actor(catalog, "brute", 1, 3)
	brute.runner.start(catalog.ability("enemy.slam"), Vector3.BACK)
	brute.receive_hit(1)
	check(brute.runner.busy(), "brute resists nonlethal interruption")
	brute.receive_hit(10000)
	check(not brute.runner.busy() and not brute.runner.active_this_step, "death always cancels")
	var encounter := Encounter.new([["scout"], ["brute"]], .5)
	var encounter_ref: WeakRef = weakref(encounter)
	encounter.wave_requested.connect(func(_ids):
		waves += 1
		encounter_ref.get_ref().register_enemy(waves))
	encounter.cleared.connect(func(): clears += 1)
	encounter.start()
	encounter.enemy_killed(1)
	check(clears == 0 and waves == 1, "wave gap does not clear room")
	encounter.tick(.6)
	encounter.enemy_killed(2)
	encounter.enemy_killed(2)
	check(clears == 1 and waves == 2, "final wave clears exactly once")
	var cancelled := Encounter.new([["scout"]], .5)
	var cancelled_ref: WeakRef = weakref(cancelled)
	cancelled.wave_requested.connect(func(_ids): cancelled_ref.get_ref().register_enemy(1))
	cancelled.cleared.connect(func(): clears += 1)
	cancelled.start()
	cancelled.cancel()
	cancelled.enemy_killed(1)
	check(clears == 1, "unload never awards victory")
	for actor in [player, enemy, brute]: actor.free()
	print("COMBAT_RULES ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func check_player_attack_sectors(catalog) -> void:
	var resolver := Resolver.new()
	# Exercise each real ability at a translated origin and non-cardinal facing.
	# The requested 160-degree sector means 80 degrees on each side of its aim.
	for ability_id in catalog.player().attacks:
		var ability: Catalog.Ability = catalog.ability(ability_id)
		if ability.hit_shape != "sector": continue
		check(is_equal_approx(rad_to_deg(ability.angle), 160.0), ability_id + " uses the requested 160-degree sector")
		var source := make_actor(catalog, "player", 0, 100)
		source.position = Vector3(3.0, 0.0, 4.0)
		var facing := Vector3.FORWARD.rotated(Vector3.UP, 0.37)
		var targets: Array = []
		for angle_deg in [-79.0, 79.0, -81.0, 81.0]:
			var target := make_actor(catalog, "brute", 1, 101 + targets.size())
			target.position = source.position + facing.rotated(Vector3.UP, deg_to_rad(angle_deg)) * ability.radius * 0.75
			targets.append(target)
		var outside_radius := make_actor(catalog, "brute", 1, 101 + targets.size())
		outside_radius.position = source.position + facing * ability.radius * 1.01
		targets.append(outside_radius)
		check(source.runner.start(ability, facing), ability_id + " sector test starts")
		source.runner.tick(ability.windup)
		resolver.resolve(source, targets + [targets[0], targets[1]])
		resolver.resolve(source, targets)
		for index in targets.size():
			var target: Actor = targets[index]
			var expected_damage := ability.damage if index < 2 else 0.0
			var label: String = ["-79 degrees hits once", "+79 degrees hits once", "-81 degrees misses", "+81 degrees misses", "outside radius misses"][index]
			check(is_equal_approx(target.health.current, target.health.maximum - expected_damage), ability_id + " " + label)
		for target in targets: target.free()
		source.free()
func check_thrust_shape(catalog) -> void:
	var ability: Catalog.Ability = catalog.ability("slash.3")
	check(ability.hit_shape == "thrust" and ability.angle == 0.0, "third combo is a thrust, not a sweep")
	var source := make_actor(catalog, "player", 0, 200)
	source.position = Vector3(3, 0, -4)
	var facing := Vector3.FORWARD.rotated(Vector3.UP, 0.37)
	var right := facing.cross(Vector3.UP)
	var samples := [
		Vector2(0.01, 0.0),
		Vector2(ability.radius - 0.01, 0.0),
		Vector2(ability.radius * 0.5, ability.thrust_width / 2.0 - 0.01),
		Vector2(ability.radius * 0.5, -ability.thrust_width / 2.0 + 0.01),
		Vector2(-0.01, 0.0),
		Vector2(ability.radius + 0.01, 0.0),
		Vector2(ability.radius * 0.5, ability.thrust_width / 2.0 + 0.01),
		Vector2(ability.radius * 0.5, -ability.thrust_width / 2.0 - 0.01)
	]
	var targets: Array = []
	for sample in samples:
		var target := make_actor(catalog, "brute", 1, 201 + targets.size())
		target.position = source.position + facing * sample.x + right * sample.y
		targets.append(target)
	source.runner.start(ability, facing)
	source.runner.tick(ability.windup)
	var resolver := Resolver.new()
	resolver.resolve(source, targets + targets)
	resolver.resolve(source, targets)
	for index in targets.size():
		var expected: float = ability.damage if index < 4 else 0.0
		check(is_equal_approx(targets[index].health.maximum - targets[index].health.current, expected), "rotated thrust boundary and dedup sample " + str(index))
	for target in targets: target.free()
	source.free()
func make_actor(catalog, id: String, faction: int, handle: int) -> Actor:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for ability_id in catalog.actor(id).attacks: abilities.append(catalog.ability(ability_id))
	actor.configure(catalog.actor(id), abilities, catalog.dodge() if faction == 0 else null, handle, faction)
	root.add_child(actor)
	return actor

