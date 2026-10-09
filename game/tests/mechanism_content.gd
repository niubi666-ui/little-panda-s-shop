extends SceneTree
## Focused schema-v6 tests; no renderer or combat runtime required.
const Loader = preload("res://content/builds/build_loader.gd")
var failures: Array[String] = []
var base: Dictionary
var checks := 0

func _initialize() -> void:
	base = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	var loader := Loader.new()
	var catalog = loader.decode(base)
	check(catalog != null, "current v6 content accepted: " + str(loader.errors))
	if catalog == null:
		finish()
		return
	check(catalog.control_group("freeze").is_read_only(), "control groups readonly")
	check(catalog.test_presets().is_read_only() and catalog.test_preset("skill_frost").selections.is_read_only(), "preset nested arrays readonly")
	check(catalog.limits().max_projectile_hits == base.limits.max_projectile_hits, "hit cap comes from content")
	var data := base.duplicate(true)
	data.status_rules.control_groups[0].thaw_immunity_sec = 5.0
	check(catalog.control_group("freeze").thaw_immunity_sec != 5.0, "catalog isolated from input")
	for version in [1, 2, 3, 4, 5, 7]:
		data = base.duplicate(true)
		data.schema_version = version
		reject(data, "unsupported schema " + str(version))
	data = base.duplicate(true)
	data.limits.hidden_default = 5
	reject(data, "unknown field")
	data = base.duplicate(true)
	entry(data,"pierce").ranks[0].max_hits = data.limits.max_projectile_hits + 1
	reject(data, "pierce over cap")
	data = base.duplicate(true)
	entry(data,"pierce").ranks[0].max_hits = 1.5
	reject(data, "fractional hit cap")
	data = base.duplicate(true)
	entry(data,"pierce").excludes = []
	entry(data,"split").excludes = []
	reject(data, "both missing exclusions still rejected")
	data = base.duplicate(true)
	entry(data,"pierce").excludes = []
	reject(data, "asymmetric exclusion")
	data = base.duplicate(true)
	entry(data,"frost_blast").ranks[0].source_effect_id = "power"
	reject(data, "nonexplosion payload source")
	data = base.duplicate(true)
	entry(data,"frost_blast").requires = []
	reject(data, "payload source must be prerequisite")
	data = base.duplicate(true)
	entry(data,"frost_blast").ranks[0].status_id = "missing"
	reject(data, "unknown payload status")
	data = base.duplicate(true)
	entry(data,"frost_blast").ranks[0].allowed_origins = ["explosion"]
	reject(data, "no recursive explosion origin")
	data = base.duplicate(true)
	entry(data,"frost_blast").ranks[0].allowed_origins = ["direct_melee"]
	entry(data,"impact_blast").ranks[0].allowed_origins = ["direct_projectile"]
	reject(data, "disjoint source/payload origins")
	data = base.duplicate(true)
	var duplicate := entry(data,"frost_blast").duplicate(true)
	duplicate.id = "other_payload"
	data.upgrades.append(duplicate)
	reject(data, "finite payload forbids duplicate source definitions")
	data = base.duplicate(true)
	var frost := entry(data,"frost_blast")
	frost.max_rank = 2
	frost.ranks.append(frost.ranks[0].duplicate(true))
	frost.ranks[1].allowed_origins = ["direct_melee"]
	reject(data, "rank selectors stable")
	data = base.duplicate(true)
	data.statuses[1].refresh = "longest"
	reject(data, "freeze cannot opt into refresh")
	data = base.duplicate(true)
	data.statuses[1].control_group = "other_group"
	reject(data, "freeze cannot switch group")
	data = base.duplicate(true)
	data.status_rules.control_groups.append({"id":"other_group","kind":"freeze","thaw_immunity_sec":1.0})
	reject(data, "multiple freeze groups rejected")
	data = base.duplicate(true)
	data.status_rules.control_groups[0].thaw_immunity_sec = 0
	reject(data, "positive thaw window required")
	data = base.duplicate(true)
	data.statuses[0].control_group = "freeze"
	reject(data, "slow cannot share freeze control group")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("frost_blast", "special")]
	reject(data, "preset requires bound prerequisite")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("pierce", "skill"), selected("split", "skill")]
	reject(data, "preset exclusion")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("pierce", "skill", 2)]
	reject(data, "preset rank cap")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("missing", "special")]
	reject(data, "preset unknown id")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("contact_freeze", "primary", 2), selected("contact_freeze", "special")]
	check(loader.decode(data) != null, "preset same card independent action ranks")
	data = base.duplicate(true)
	var other_freeze: Dictionary = data.statuses[1].duplicate(true)
	other_freeze.id = "other_freeze"
	data.statuses.append(other_freeze)
	check(loader.decode(data) != null, "different freeze IDs allowed in same group")
	data = base.duplicate(true)
	data.actions[1].base_form_id = "missing"
	reject(data, "unknown base form")
	data = base.duplicate(true)
	data.forms[2].projectile_id = "missing"
	reject(data, "unknown formal projectile")
	data = base.duplicate(true)
	data.forms[1].ability_ids = []
	reject(data, "melee requires ability")
	data = base.duplicate(true)
	entry(data, "impact_blast").scope = "global"
	reject(data, "global cannot hold action core")
	data = base.duplicate(true)
	entry(data, "impact_blast").layer = "support"
	reject(data, "explosion cannot dodge core limit")
	data = base.duplicate(true)
	data.test_attacks[0].action_id = "special"
	reject(data, "debug test arrow isolated from formal special")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("power", "debug_arrow")]
	reject(data, "global stat cannot bind debug")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("contact_freeze", "debug_arrow")]
	reject(data, "preset cannot target debug even with formal card")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("contact_freeze", "primary"), selected("impact_blast", "primary")]
	reject(data, "preset same action two cores")
	data = base.duplicate(true)
	entry(data, "power").requires = ["agility"]
	entry(data, "agility").requires = ["power"]
	reject(data, "dependency cycle")
	data = base.duplicate(true)
	data.stats.damage_composition = "multiply"
	reject(data, "unsupported damage composition")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("pierce", "primary")]
	reject(data, "preset actual same-action projectile required")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("contact_freeze", "primary"), selected("freeze_duration", "special")]
	reject(data, "preset duration cannot borrow other action freeze")
	data = base.duplicate(true)
	data.test_presets[0].selections = [selected("impact_blast", "skill"), selected("frost_blast", "skill"), selected("split", "skill")]
	reject(data, "preset full frost split combination rejected")
	check(catalog.actions().is_read_only() and catalog.form("sword_wave").ability_ids.is_read_only(), "actions and forms immutable")
	finish()

func selected(id: String, action: String, rank: int = 1) -> Dictionary:
	return {"upgrade_id": id, "action_id": action, "rank": rank}

func entry(data: Dictionary, id: String) -> Dictionary:
	for value in data.upgrades:
		if value.id == id: return value
	assert(false, "Missing test entry " + id)
	return {}

func reject(data: Dictionary, label: String) -> void:
	var loader := Loader.new()
	check(loader.decode(data) == null and not loader.errors.is_empty(), label)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func finish() -> void:
	print("MECHANISM_CONTENT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
