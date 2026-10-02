extends SceneTree
const BuildLoader = preload("res://content/builds/build_loader.gd")
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const CombatCatalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Runtime = preload("res://combat/builds/build_runtime.gd")

# A narrow injected catalog fixture exercises defensive limits independently of card balance.
class LimitedCatalog extends RefCounted:
	var base
	var limit_values: Dictionary
	func limits() -> Dictionary: return limit_values
	func projectile(id: String) -> Dictionary: return base.projectile(id)
	func test_attack(id: String) -> Dictionary: return base.test_attack(id)
	func stat_limits() -> Dictionary: return base.stat_limits()
	func has_upgrade(id: String) -> bool: return base.has_upgrade(id)
	func upgrade(id: String) -> Dictionary: return base.upgrade(id)
	func status(id: String) -> Dictionary: return base.status(id)
	func status_response(id: String) -> Dictionary: return base.status_response(id)
	func control_group(id: String) -> Dictionary: return base.control_group(id)

var failures: Array[String] = []
var _combat
var _builds
var _resolver := Resolver.new()
var _handle := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	_builds = BuildLoader.new().load_catalog()
	_combat = CombatLoader.new().load_catalog()
	check(_builds != null and _combat != null, "real validated build and combat catalogs load")
	if _builds == null or _combat == null:
		finish()
		return
	_resolver.configure(_builds)
	check_resolver()
	check_cast_snapshot_and_sweep()
	check_wall_and_cancel()
	check_chain_order_and_scope()
	check_split_and_budget()
	check_split_hits_and_projectile_chain()
	check_expired_split_and_reentrant_clear()
	check_death_and_clear()
	finish()

func finish() -> void:
	print("BUILD_RUNTIME ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func make_actor(id: String, faction: int) -> Actor:
	_handle += 1
	var actor := Actor.new()
	var abilities: Array[CombatCatalog.Ability] = []
	for ability_id in _combat.actor(id).attacks: abilities.append(_combat.ability(ability_id))
	actor.configure(_combat.actor(id), abilities, _combat.dodge() if faction == 0 else null, _handle, faction)
	root.add_child(actor)
	return actor

func make_runtime(player, targets: Array, ranks: Dictionary, wall: Callable = Callable(), catalog = null) -> Runtime:
	var runtime := Runtime.new()
	runtime.configure(_builds if catalog == null else catalog, player, func() -> Array: return targets, wall)
	runtime.set_program(_resolver.resolve(ranks))
	player.runner.committed.connect(runtime.on_committed)
	player.runner.cue_reached.connect(runtime.on_cue)
	return runtime

func start_cast(player) -> void:
	check(player.runner.start(_combat.ability("slash.1"), Vector3.FORWARD), "test cast starts")

func release_wave(player, runtime) -> void:
	start_cast(player)
	player.runner.tick(_combat.ability("slash.1").windup)
	runtime.tick(0.001)

func cleanup(runtime, actors: Array) -> void:
	runtime.clear_room()
	for actor in actors: actor.free()

func check_resolver() -> void:
	var a := _resolver.resolve({"wave": 1, "power": 1, "chain": 1, "agility": 1})
	var b := _resolver.resolve({"agility": 1, "chain": 1, "power": 1, "wave": 1})
	check(a == b, "same selections compile identically regardless of selection order")
	check(a.is_read_only() and a.tags.is_read_only() and a.effects.is_read_only() and a.effects[0].params.is_read_only(), "program recursively readonly")
	var rank := mini(2, int(_builds.upgrade("power").max_rank))
	var upgraded := _resolver.resolve({"power": rank})
	var limits: Dictionary = _builds.stat_limits()
	var expected := clampf(1.0 + float(_builds.upgrade("power").ranks[rank - 1].bonus), float(limits.damage_scale_min), float(limits.damage_scale_max))
	check(is_equal_approx(float(upgraded.damage_scale), expected), "rank replaces previous rank rather than accumulating levels")
	var last_id := ""
	for effect in a.effects:
		check(last_id <= str(effect.upgrade_id), "effects stable sorted by upgrade ID")
		last_id = effect.upgrade_id
	var untouched := _resolver.resolve({})
	check(untouched.damage_scale == 1.0 and untouched.move_scale == 1.0, "empty build uses identity modifiers")

func check_cast_snapshot_and_sweep() -> void:
	var player := make_actor("player", 0)
	var enemy := make_actor("brute", 1)
	enemy.position = Vector3(0, 0, -3)
	var runtime := make_runtime(player, [enemy, enemy], {"power": 1, "wave": 1})
	var hits: Array = []
	runtime.damage_applied.connect(func(_source, target, amount, origin): hits.append([target.handle, amount, origin]))
	start_cast(player)
	var base: float = _combat.ability("slash.1").damage
	var original_program := _resolver.resolve({"power": 1, "wave": 1})
	var original_damage: float = base * float(original_program.damage_scale)
	runtime.set_program(_resolver.resolve({"power": mini(2, int(_builds.upgrade("power").max_rank)), "wave": mini(2, int(_builds.upgrade("wave").max_rank))}))
	check(is_equal_approx(runtime.melee_damage(player, base), original_damage), "current melee keeps cast snapshot after a selection")
	check(runtime.melee_damage(enemy, base) == base, "enemy melee is unaffected by player build")
	player.runner.tick(_combat.ability("slash.1").windup)
	var paused_before := runtime.diagnostics()
	runtime.tick(0.0)
	check(runtime.diagnostics() == paused_before and runtime.projectiles().is_empty(), "paused step processes no queued wave")
	runtime.tick(0.001)
	check(runtime.projectiles().size() == 1, "cue emits wave without a melee hit")
	var paused_projectiles := runtime.projectiles()
	check(paused_projectiles.is_read_only() and paused_projectiles[0].is_read_only(), "presentation snapshot recursively readonly")
	runtime.tick(0.0)
	check(runtime.projectiles() == paused_projectiles, "paused projectile position unchanged")
	var wave: Dictionary = wave_params()
	check(is_equal_approx(float(paused_projectiles[0].position.y), float(wave.height_m)), "projectile wall ray is above floor")
	player.cancel()
	runtime.tick(float(wave.lifetime_sec))
	var expected: float = original_damage * float(wave.damage_ratio)
	check(is_equal_approx(enemy.health.maximum - enemy.health.current, expected), "large-step swept wave hits once using old cast damage and wave rank")
	check(hits.size() == 1 and hits[0][2] == "secondary_projectile", "duplicate target list cannot duplicate projectile damage")
	check(runtime.diagnostics().roots == 0 and runtime.diagnostics().projectiles == 0, "expired cast root reclaimed after last projectile")
	cleanup(runtime, [player, enemy])

func check_wall_and_cancel() -> void:
	var player := make_actor("player", 0)
	var enemy := make_actor("brute", 1)
	enemy.position = Vector3(0, 0, -2)
	var wall := func(from: Vector3, to: Vector3) -> Variant:
		if from.z >= -1.0 and to.z <= -1.0:
			return from.lerp(to, (-1.0 - from.z) / (to.z - from.z))
		return null
	var runtime := make_runtime(player, [enemy], {"wave": 1}, wall)
	start_cast(player)
	player.cancel()
	runtime.on_cue(player.runner.cast_id, "slash.1")
	runtime.tick(1.0)
	check(runtime.projectiles().is_empty() and runtime.diagnostics().roots == 0, "cancelled windup cannot emit a projectile and releases root")
	player.runner.cooldown = 0.0
	release_wave(player, runtime)
	player.cancel()
	runtime.tick(1.0)
	check(enemy.health.current == enemy.health.maximum and runtime.projectiles().is_empty(), "wall clips swept segment before enemy damage")
	check(runtime.diagnostics().roots == 0, "wall-ended projectile releases root")
	cleanup(runtime, [player, enemy])

func check_chain_order_and_scope() -> void:
	var player := make_actor("player", 0)
	var initial := make_actor("brute", 1)
	var first := make_actor("brute", 1)
	var second := make_actor("brute", 1)
	initial.position = Vector3(0, 0, -1)
	first.position = Vector3(-1, 0, -1)
	second.position = Vector3(1, 0, -1)
	var runtime := make_runtime(player, [second, initial, first, second], {"power": 1, "chain": 1})
	var hits: Array = []
	runtime.damage_applied.connect(func(_source, target, amount, origin): hits.append([target.handle, amount, origin]))
	start_cast(player)
	var amount: float = initial.receive_hit(runtime.melee_damage(player, _combat.ability("slash.1").damage))
	runtime.on_melee_hit(player, initial, player.runner.cast_id, "slash.1", amount)
	runtime.on_melee_hit(player, second, player.runner.cast_id, "slash.1", amount)
	check(runtime.diagnostics().queued == 1, "chain trigger once per upgrade and root even with multiple direct hits")
	player.cancel()
	runtime.tick(1.0)
	var params: Dictionary = _builds.upgrade("chain").ranks[0]
	check(hits.size() == mini(int(params.jumps), 2), "chain has bounded unique target count")
	if not hits.is_empty():
		check(hits[0][0] == first.handle and hits[0][2] == "chain", "equal-distance chain tie chooses lower stable actor handle")
		check(is_equal_approx(float(hits[0][1]), amount * float(params.damage_ratio)), "chain ratio does not apply player damage scale twice")
	if hits.size() > 1:
		check(hits[1][0] == second.handle and is_equal_approx(float(hits[1][1]), float(hits[0][1]) * float(params.falloff)), "chain follows falloff and visited exclusion")
	check(runtime.diagnostics().roots == 0 and runtime.diagnostics().queued == 0, "chain never recursively triggers chain and final root is reclaimed")
	cleanup(runtime, [player, initial, first, second])

func check_split_and_budget() -> void:
	var player := make_actor("player", 0)
	var impact := make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	var runtime := make_runtime(player, [impact], {"wave": 1, "split": 1})
	release_wave(player, runtime)
	var wave: Dictionary = wave_params()
	var split: Dictionary = _builds.upgrade("split").ranks[0]
	runtime.tick(1.0 / float(wave.speed_mps))
	check(runtime.projectiles().size() == int(split.count), "projectile impact creates configured split child count")
	var after_impact: float = impact.health.current
	check(runtime.diagnostics().roots == 1, "children retain one shared root")
	check(int(runtime.diagnostics().budgets.values()[0]) == int(_builds.limits().root_effect_budget) - 1 - int(split.count), "wave and all children consume one shared root request budget")
	player.cancel()
	runtime.tick(float(wave.lifetime_sec))
	check(impact.health.current == after_impact, "children cannot rehit the parent impact target")
	check(runtime.diagnostics().roots == 0, "all child lifetimes eventually release shared root")
	cleanup(runtime, [player, impact])

	var bounded := LimitedCatalog.new()
	bounded.base = _builds
	bounded.limit_values = _builds.limits().duplicate(true)
	bounded.limit_values.root_effect_budget = 2
	bounded.limit_values.max_projectiles_per_root = 2
	bounded.limit_values.requests_per_step = 1
	bounded.limit_values.max_queue = 1
	bounded.limit_values.max_projectiles = 1
	player = make_actor("player", 0)
	impact = make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	runtime = make_runtime(player, [impact], {"wave": 1, "split": 1, "chain": 1}, Callable(), bounded)
	release_wave(player, runtime)
	runtime.tick(1.0 / float(wave.speed_mps))
	check(runtime.diagnostics().executed <= 2 and runtime.diagnostics().queued <= 1 and runtime.diagnostics().projectiles <= 1, "execution, queue and projectile caps remain bounded under combined procs")
	check(runtime.diagnostics().rejected > 0, "over-budget fanout is rejected explicitly")
	player.cancel()
	for step in range(4): runtime.tick(float(wave.lifetime_sec))
	check(runtime.diagnostics().roots == 0 and runtime.diagnostics().queued == 0, "budget exhaustion does not leak roots")
	cleanup(runtime, [player, impact])

func check_death_and_clear() -> void:
	for survive in [false, true]:
		var bounded := LimitedCatalog.new()
		bounded.base = _builds
		bounded.limit_values = _builds.limits().duplicate(true)
		bounded.limit_values.projectiles_survive_source_death = survive
		var player := make_actor("player", 0)
		var enemy := make_actor("brute", 1)
		enemy.position = Vector3(0, 0, -2)
		var runtime := make_runtime(player, [enemy], {"wave": 1}, Callable(), bounded)
		release_wave(player, runtime)
		var previous_id: int = runtime.projectiles()[0].id
		player.receive_hit(player.health.maximum)
		runtime.tick(float(wave_params().lifetime_sec))
		check((enemy.health.current < enemy.health.maximum) == survive, "source death follows explicit survival setting " + str(survive))
		runtime.clear_room()
		check(runtime.diagnostics().roots == 0 and runtime.diagnostics().queued == 0 and runtime.projectiles().is_empty(), "room clear drops every transient context")
		# Old cast/cue callbacks cannot resurrect a cleared root.
		runtime.on_cue(player.runner.cast_id, "slash.1")
		runtime.tick(1.0)
		check(runtime.projectiles().is_empty(), "stale cue after clear cannot create projectile " + str(previous_id))
		cleanup(runtime, [player, enemy])

func check_split_hits_and_projectile_chain() -> void:
	var player := make_actor("player", 0)
	var impact := make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	var wave: Dictionary = wave_params()
	var split: Dictionary = _builds.upgrade("split").ranks[0]
	var behind := make_actor("brute", 1)
	var child_direction := Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(float(split.spread_deg)) / 2.0)
	behind.position = Vector3.FORWARD * (1.0 - float(wave.radius_m)) + child_direction * 2.0
	var runtime := make_runtime(player, [impact, behind], {"wave": 1, "split": 1})
	var hits: Array = []
	runtime.damage_applied.connect(func(_source, target, amount, origin): hits.append([target.handle, amount, origin]))
	release_wave(player, runtime)
	runtime.tick(1.0 / float(wave.speed_mps))
	player.cancel()
	# Change future casts after children already exist: their damage and generation remain frozen.
	runtime.set_program(_resolver.resolve({"power": 3, "wave": 3, "split": 2}))
	runtime.tick(float(wave.lifetime_sec))
	var expected: float = _combat.ability("slash.1").damage * float(wave.damage_ratio) * float(split.damage_ratio)
	check(is_equal_approx(behind.health.maximum - behind.health.current, expected), "split child hits a different target with snapshotted parent ratio")
	check(hits.size() == 2 and runtime.projectiles().is_empty(), "configured first-generation split cannot split again after child hit")
	check(runtime.diagnostics().roots == 0, "completed split hit tree releases its root")
	cleanup(runtime, [player, impact, behind])

	player = make_actor("player", 0)
	impact = make_actor("brute", 1)
	behind = make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	behind.position = Vector3(1, 0, -1)
	runtime = make_runtime(player, [impact, behind], {"wave": 1, "chain": 1})
	hits = []
	runtime.damage_applied.connect(func(_source, target, amount, origin): hits.append([target.handle, amount, origin]))
	release_wave(player, runtime)
	player.cancel()
	runtime.tick(1.0)
	var chain: Dictionary = _builds.upgrade("chain").ranks[0]
	expected = _combat.ability("slash.1").damage * float(wave.damage_ratio) * float(chain.damage_ratio)
	check(is_equal_approx(behind.health.maximum - behind.health.current, expected), "confirmed projectile damage is an eligible one-time chain source")
	check(hits.size() == 2 and hits[0][2] == "secondary_projectile" and hits[1][2] == "chain", "projectile to chain produces exactly two committed effects without recursion")
	cleanup(runtime, [player, impact, behind])

func check_expired_split_and_reentrant_clear() -> void:
	var player := make_actor("player", 0)
	var impact := make_actor("brute", 1)
	var spawned := make_actor("brute", 1)
	impact.position = Vector3(0, 0, -2)
	spawned.position = Vector3(0.5, 0, -1)
	var targets: Array = [impact]
	var runtime := make_runtime(player, targets, {"wave": 1, "split": 1})
	# Exact integer geometry makes the contact occur exactly at expiry, without epsilon assumptions.
	var program: Dictionary = _resolver.resolve({"wave": 1, "split": 1}).duplicate(true)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	fixture.projectiles[0].speed_mps = 1.0
	fixture.projectiles[0].radius_m = 1.0
	fixture.projectiles[0].lifetime_sec = 1.0
	runtime.configure(BuildLoader.new().decode(fixture), player, func(): return targets, Callable())
	runtime.set_program(program)
	runtime.damage_applied.connect(func(_source, _target, _amount, _origin): targets.append(spawned))
	release_wave(player, runtime)
	player.cancel()
	runtime.tick(1.0)
	check(impact.health.current < impact.health.maximum, "projectile endpoint contact applies its own damage")
	check(runtime.projectiles().is_empty() and runtime.diagnostics().queued == 0, "expired parent cannot generate zero-lifetime children")
	runtime.tick(1.0)
	check(spawned.health.current == spawned.health.maximum and runtime.diagnostics().roots == 0, "zero-lifetime split cannot damage a target newly overlapping impact")
	cleanup(runtime, [player, impact, spawned])

	player = make_actor("player", 0)
	impact = make_actor("brute", 1)
	var first := make_actor("brute", 1)
	var second := make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	first.position = Vector3(1, 0, -1)
	second.position = Vector3(2, 0, -1)
	runtime = make_runtime(player, [impact, first, second], {"chain": 1})
	var runtime_ref: WeakRef = weakref(runtime)
	runtime.chain_emitted.connect(func(_points): runtime_ref.get_ref().clear_room())
	start_cast(player)
	var applied: float = impact.receive_hit(_combat.ability("slash.1").damage)
	runtime.on_melee_hit(player, impact, player.runner.cast_id, "slash.1", applied)
	player.cancel()
	runtime.tick(1.0)
	check(first.health.current < first.health.maximum and second.health.current == second.health.maximum, "synchronous room clear during first chain segment cancels later jumps")
	check(runtime.diagnostics().roots == 0 and runtime.diagnostics().queued == 0 and runtime.projectiles().is_empty(), "old chain continuation cannot enqueue after its root and generation were cleared")
	check(runtime.diagnostics().rejected > 0, "stale chain branch is rejected at the shared queue boundary")
	cleanup(runtime, [player, impact, first, second])

func wave_params() -> Dictionary:
	var result: Dictionary = _builds.projectile("sword_wave").duplicate(true)
	result.merge(_builds.upgrade("wave").ranks[0])
	return result

