extends SceneTree
## The same schema and semantic checks used by EnemyLoader, without mutating content files.
const Reader = preload("res://content/combat/combat_loader.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
var failures: Array[String] = []
var checks := 0
var base: Dictionary
var schema: Dictionary

func _initialize() -> void:
	base = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/encounters.json"))
	schema = JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/encounters.schema.json"))
	check(accepted(base), "current training configuration accepted")
	var reader := Reader.new()
	var combat = reader.load_catalog()
	var loader := EnemyLoader.new()
	var catalog = loader.load_catalog(combat)
	check(catalog != null, "real enemy catalog loads: " + str(loader.errors))
	if catalog != null:
		check(catalog.encounters.training_tools.is_read_only(), "training config deeply readonly")
		check(catalog.encounters.training_tools == base.training_tools, "catalog publishes configured tools without fallback")
	var data := base.duplicate(true)
	data.erase("training_tools")
	check(not accepted(data), "missing tools rejected")
	for key in base.training_tools:
		data = base.duplicate(true)
		data.training_tools.erase(key)
		check(not accepted(data), "missing " + key + " rejected")
	data = base.duplicate(true)
	data.training_tools.hidden_default = 4
	check(not accepted(data), "unknown field rejected")
	for version in [1, 3]:
		data = base.duplicate(true)
		data.schema_version = version
		check(not accepted(data), "unsupported version rejected")
	for value in [0, -1, 2, 18.5, 61, "18", true, INF, NAN]:
		data = base.duplicate(true)
		data.training_tools.max_alive_enemies = value
		check(not accepted(data), "invalid live cap rejected: " + str(value))
	for key in ["spawn_search_radius_m", "spawn_step_m"]:
		for value in [0, -1, 21, "1.5", true, INF, NAN]:
			data = base.duplicate(true)
			data.training_tools[key] = value
			check(not accepted(data), "invalid " + key + " rejected: " + str(value))
	data = base.duplicate(true)
	data.training_tools.spawn_step_m = data.training_tools.spawn_search_radius_m + 1.0
	check(not accepted(data), "step exceeding radius rejected")
	data = base.duplicate(true)
	data.training_tools.spawn_step_m = data.training_tools.spawn_search_radius_m / 9.0
	check(not accepted(data), "unbounded search grid rejected")
	data = base.duplicate(true)
	data.training_tools.spawn_step_m = data.training_tools.spawn_search_radius_m / 8.0
	check(accepted(data), "search grid boundary accepted")
	data = base.duplicate(true)
	data.training_tools.max_alive_enemies = 3
	check(accepted(data), "live cap equal to band cap accepted")
	data = base.duplicate(true)
	data.depth_bands[-1].max_enemies = data.training_tools.max_alive_enemies + 1
	check(not accepted(data), "every depth band must fit live cap")
	print("training tools content: ", checks, " checks, failures=", failures)
	quit(0 if failures.is_empty() else 1)

func accepted(data: Dictionary) -> bool:
	var reader := Reader.new()
	reader._check(data, schema, "encounters")
	if not reader.errors.is_empty(): return false
	var loader := EnemyLoader.new()
	loader._validate_training_tools(data)
	return loader.errors.is_empty()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
