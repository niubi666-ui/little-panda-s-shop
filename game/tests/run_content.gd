extends SceneTree
const Loader = preload("res://content/run/run_loader.gd")
const StrictJSON = preload("res://content/run/strict_json.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
const Planner = preload("res://rogue/run/run_planner.gd")
const Encounters = preload("res://rogue/encounters/encounter_planner.gd")
var failures: Array[String] = []
var checks := 0
var builds
var enemies
var base: Dictionary

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func reject(data: Variant, message: String) -> void:
	var loader := Loader.new()
	check(loader.decode(data, builds, enemies, ["graybox"]).is_empty() and not loader.errors.is_empty(), message)

func run() -> void:
	builds = BuildLoader.new().load_catalog()
	var combat = CombatLoader.new().load_catalog()
	enemies = EnemyLoader.new().load_catalog(combat) if combat != null else null
	check(builds != null and enemies != null, "injected catalogs load")
	if builds == null or enemies == null: finish(); return
	var loader := Loader.new()
	base = JSON.parse_string(FileAccess.get_file_as_string("res://data/run/route.json"))
	var route: Dictionary = loader.load_route(builds, enemies, ["graybox"])
	check(not route.is_empty(), "manifest route loads: " + str(loader.errors))
	if route.is_empty(): finish(); return
	check(route.is_read_only() and route.nodes.is_read_only() and route.nodes[0].is_read_only() and route.edges[0].is_read_only(), "route recursively readonly")
	var original_depth: int = route.nodes[0].depth
	var changed: Dictionary = base.duplicate(true)
	changed.nodes[0].depth = original_depth + 1
	check(route.nodes[0].depth == original_depth, "catalog owns isolated copy")
	check(route.nodes.size() == 7 and route.edges.size() == 8, "authored short branching route")
	check(route.nodes.all(func(node): return node.reward_id == "none"), "all current rewards explicitly none")
	check_json()
	check_invalid_routes()
	check_plans(route)
	finish()

func check_json() -> void:
	var strict := StrictJSON.new()
	for text in ["", " ", '{"id":1,"id":2}', '{"id":1,"\\u0069d":2}', '{"x":{"a":1,"a":2}}', '{"x":1,}', '[1,]', '{"x":01}', '{"x":NaN}', '{"x":1e999}', '{"x":"\\q"}', '{"x":true} false']:
		strict.parse(text)
		check(not strict.errors.is_empty(), "strict JSON rejects " + text)
	var valid: Variant = strict.parse('{"a":{"id":1},"b":{"id":2},"n":-1.25e2,"s":"quote\\\" slash\\\\"}')
	check(strict.errors.is_empty() and valid is Dictionary and valid.n == -125.0, "independent nested keys and escaped strings allowed")
	var loader := Loader.new()
	check(loader.decode_json(FileAccess.get_file_as_string("res://data/run/route.json"), builds, enemies, ["graybox"]).size() > 0, "strict JSON decode of actual route")

func check_invalid_routes() -> void:
	reject(null, "null document")
	reject({}, "missing required fields")
	var bad: Dictionary = base.duplicate(true)
	bad.schema_version = 2
	reject(bad, "unsupported route schema")
	bad = base.duplicate(true)
	bad.extra = true
	reject(bad, "unknown route field")
	bad = base.duplicate(true)
	bad.nodes.append(bad.nodes[0].duplicate(true))
	reject(bad, "duplicate node identity")
	bad = base.duplicate(true)
	bad.nodes[2].column = bad.nodes[1].column
	reject(bad, "duplicate map cell")
	bad = base.duplicate(true)
	bad.nodes[0].template_id = "missing"
	reject(bad, "unknown template")
	bad = base.duplicate(true)
	bad.starter_build_preset = "missing"
	reject(bad, "unknown starter build")
	bad = base.duplicate(true)
	bad.nodes[-1].depth = enemies.encounters.training_max_depth + 1
	reject(bad, "encounter depth cap")
	bad = base.duplicate(true)
	bad.nodes[0].depth = 1.5
	reject(bad, "fractional depth")
	bad = base.duplicate(true)
	bad.nodes[0].depth = NAN
	reject(bad, "non-finite decoded number")
	bad = base.duplicate(true)
	bad.nodes[0].kind = "boss"
	reject(bad, "unsupported node kind")
	bad = base.duplicate(true)
	bad.rewards[0].kind = "major_build"
	reject(bad, "unimplemented reward kind")
	bad = base.duplicate(true)
	bad.nodes[0].reward_id = "major_build"
	reject(bad, "unimplemented reward reference")
	bad = base.duplicate(true)
	bad.edges[0].to = "missing"
	reject(bad, "unknown edge target")
	bad = base.duplicate(true)
	bad.edges.append(bad.edges[0].duplicate(true))
	reject(bad, "duplicate edge")
	bad = base.duplicate(true)
	bad.edges.append({"from": "terminal", "to": "entry"})
	reject(bad, "backward edge/cycle")
	bad = base.duplicate(true)
	bad.edges[0].to = "junction"
	reject(bad, "skipped map layer")
	bad = base.duplicate(true)
	bad.nodes[-1].kind = "battle"
	reject(bad, "missing terminal")
	bad = base.duplicate(true)
	bad.nodes[1].kind = "terminal"
	reject(bad, "multiple terminals")
	bad = base.duplicate(true)
	bad.edges.remove_at(2)
	reject(bad, "branch cannot reach terminal")
	bad = base.duplicate(true)
	bad.edges.remove_at(0)
	reject(bad, "branch unreachable from declared starts")
	bad = base.duplicate(true)
	bad.start_node_ids = ["branch_left"]
	reject(bad, "nonroot start")
	bad = base.duplicate(true)
	bad.nodes[1].depth = bad.nodes[0].depth
	reject(bad, "depth must increase along route")
	var loader := Loader.new()
	check(loader.decode(base, builds, enemies, []).is_empty(), "no template registry rejected")
	bad = base.duplicate(true)
	bad.nodes.reverse()
	bad.edges.reverse()
	check(not loader.decode(bad, builds, enemies, ["graybox"]).is_empty(), "graph validation independent of array order")

func check_plans(route: Dictionary) -> void:
	var planner := Planner.new()
	var capacity := 6
	planner.configure(enemies, {"graybox": capacity})
	check(planner.errors.is_empty(), "planner accepts injected template capacity")
	var external_rng := RandomNumberGenerator.new()
	external_rng.seed = 842
	var before := external_rng.state
	var plans: Dictionary = {}
	for node in route.nodes:
		var plan: Dictionary = planner.plan(node, 123456)
		check(not plan.is_empty(), "legal node plan " + str(node.id))
		if plan.is_empty(): continue
		check(plan == planner.plan(node, 123456), "same run seed/node reproduces complete plan " + str(node.id))
		check(plan.is_read_only() and plan.encounter_plan.waves.is_read_only() and plan.encounter_plan.waves[0].drops.is_read_only(), "immutable locked plan " + str(node.id))
		check(Encounters.new().validate_plan(plan.encounter_plan, capacity, enemies), "existing encounter planner validates " + str(node.id))
		check(plan.depth == node.depth and plan.reward_id == "none" and plan.template_id == "graybox", "plan retains authored gameplay fields")
		plans[node.id] = plan
	check(external_rng.state == before, "planning does not consume unrelated RNG")
	check(plans.branch_left.encounter_plan.seed != plans.branch_right.encounter_plan.seed, "same-depth sibling node seeds have independent identities")
	check(planner.plan(route.nodes[0], 123457).encounter_plan.seed != plans.entry.encounter_plan.seed, "different run seed changes encounter identity")
	var reversed_nodes: Array = route.nodes.duplicate()
	reversed_nodes.reverse()
	for node in reversed_nodes:
		check(planner.plan(node, 123456) == plans[node.id], "visit order cannot advance node random stream")
	planner.configure(enemies, {"graybox": 1})
	check(planner.plan(route.nodes[0], 1).is_empty() and not planner.errors.is_empty(), "insufficient capacity fails explicitly without arbitrary enemies")
	planner.configure(enemies, {"graybox": 0})
	check(not planner.errors.is_empty() and planner.plan(route.nodes[0], 1).is_empty(), "bad capacity rejected")

func finish() -> void:
	print("RUN_CONTENT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
