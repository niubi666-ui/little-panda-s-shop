extends "res://tests/build_runtime.gd"
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Session = preload("res://app/session/training_build_session.gd")
const Split = preload("res://combat/builds/projectile_split.gd")
const Factory = preload("res://combat/builds/projectile_factory.gd")

func run() -> void:
	_builds = BuildLoader.new().load_catalog()
	_combat = CombatLoader.new().load_catalog()
	_resolver.configure(_builds)
	check_compatibility()
	check_arrow()
	print("PROJECTILE_CAPABILITIES ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check_compatibility() -> void:
	var entry: Dictionary = _builds.upgrade("split")
	check(not Capabilities.eligible(entry, Capabilities.summarize(_builds, _resolver.resolve({}), [])), "melee cannot offer split")
	check(Capabilities.eligible(entry, Capabilities.summarize(_builds, _resolver.resolve({"wave": 1}), [])), "wave can offer split")
	var arrow_summary := Capabilities.summarize(_builds, _resolver.resolve({}), ["test_arrow"])
	check(Capabilities.eligible(entry, arrow_summary), "arrow alone can offer split")
	check(arrow_summary.is_read_only() and arrow_summary[0].projectile.is_read_only(), "summary immutable with per-attack association")
	var unsupported: Dictionary = _builds.projectile("test_arrow").duplicate(true)
	unsupported.child_id = ""
	check(not Capabilities.eligible(entry, [{"attack_id": "inert", "projectile": unsupported}]), "no child strategy is incompatible")
	unsupported.executor = "beam"
	unsupported.child_id = "test_arrow"
	check(not Capabilities.supports_split(unsupported, entry.ranks[0]), "beam cannot masquerade as linear projectile")
	var session := Session.new()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	fixture.offer.pool_ids = ["split"]
	fixture.offer.fallback_ids = []
	var catalog = BuildLoader.new().decode(fixture)
	var commit_fail := [true]
	session.configure(catalog, 719, func(_state): return ERR_CANT_CREATE if commit_fail[0] else OK, ["test_arrow"])
	var before: Dictionary = session.snapshot()
	check(not session.open_offer().ok and session.snapshot() == before, "arrow offer failure preserves RNG")
	commit_fail[0] = false
	var offer: Dictionary = session.open_offer().offer
	check(offer.candidates == ["split"], "actual candidate sampler offers split without wave")
	check(session.choose(offer.id, "split").ok and not session.snapshot().ranks.has("wave"), "arrow-only split selection commits")
	var unarmed := Session.new()
	unarmed.configure(catalog, 719, func(_state): return OK)
	check(unarmed.open_offer().offer.candidates.is_empty(), "same pool cannot issue currently useless split")
	var definition: Dictionary = _builds.projectile("test_arrow")
	var parent := Factory.initial(definition, Vector3.ZERO, Vector3.FORWARD, 12.0)
	parent.definition = _builds.projectile("sword_wave").duplicate(true)
	parent.definition.child_id = ""
	check(Split.requests(_builds, _builds.limits(), _resolver.resolve({"split": 1}), parent, 1).is_empty(), "runtime rejects incompatible member of mixed loadout")
	parent.definition = definition
	check(Split.requests(_builds, _builds.limits(), _resolver.resolve({"split": 1}), parent, 1).size() == 2, "same shared rule accepts compatible member")
	check(Split.requests(_builds, _builds.limits(), _resolver.resolve({"split": 1}), parent, 1).is_empty(), "one trigger per object and upgrade")
	var changed_child := Factory.child(_builds.projectile("sword_wave"), parent, Vector3.FORWARD, 0.5, 1)
	check(changed_child.definition.id == "sword_wave" and changed_child.speed == _builds.projectile("sword_wave").speed_mps, "child definition controls physical type and speed")
	check(changed_child.lifetime <= parent.lifetime and changed_child.damage == parent.damage * 0.5, "different child definition cannot refresh lifetime or damage scale")
	fixture.projectiles[0].child_id = "missing"
	check(BuildLoader.new().decode(fixture) == null, "dangling child definition rejected")

func check_arrow() -> void:
	var player := make_actor("player", 0)
	var impact := make_actor("brute", 1)
	var behind := make_actor("brute", 1)
	impact.position = Vector3(0, 0, -1)
	var definition: Dictionary = _builds.projectile("test_arrow")
	var params: Dictionary = _builds.upgrade("split").ranks[0]
	var direction := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-float(params.spread_deg) / 2.0))
	behind.position = Vector3.FORWARD * (1.0 - float(definition.radius_m)) + direction * 2.0
	var runtime := Runtime.new()
	runtime.configure(_builds, player, func(): return [impact, behind], Callable(), ["test_arrow"])
	runtime.set_program(_resolver.resolve({"split": 1, "power": 1}))
	check(runtime.fire_attack("test_arrow", Vector3.FORWARD), "arrow fires without wave or sword cast")
	check(not runtime.fire_attack("test_arrow", Vector3.FORWARD), "cooldown enforced")
	runtime.tick(0.001)
	check(runtime.projectiles().size() == 1 and runtime.projectiles()[0].definition_id == "test_arrow", "one initial arrow with presentation ID")
	var paused: Array = runtime.projectiles()
	runtime.tick(0.0)
	check(runtime.projectiles() == paused, "paused simulation does not move arrow")
	# Program changes after fire cannot retrofit a root.
	runtime.set_program(_resolver.resolve({}))
	runtime.tick(1.0 / float(definition.speed_mps))
	check(runtime.projectiles().size() == 2, "arrow and wave share split processor")
	var damage := float(_builds.test_attack("test_arrow").damage) * float(_resolver.resolve({"power": 1}).damage_scale)
	check(is_equal_approx(impact.health.maximum - impact.health.current, damage), "arrow snapshot applies power once")
	for p in runtime.projectiles(): check(p.definition_id == "test_arrow", "children use explicit arrow definition")
	var diagnostics: Dictionary = runtime.diagnostics()
	check(diagnostics.roots == 1 and diagnostics.budgets.values()[0] == int(_builds.limits().root_effect_budget) - 3, "parent and two children share a single root budget")
	runtime.tick(float(definition.lifetime_sec))
	check(is_equal_approx(behind.health.maximum - behind.health.current, damage * float(params.damage_ratio)), "child keeps damage snapshot without double scaling")
	check(is_equal_approx(impact.health.maximum - impact.health.current, damage), "children exclude ancestor hit target")
	check(runtime.projectiles().is_empty() and runtime.diagnostics().roots == 0, "root reclaimed after children expire")
	runtime.clear_room()
	check(runtime.fire_attack("test_arrow", Vector3.FORWARD), "room reset clears test cooldown")
	runtime.clear_room()
	runtime.tick(1.0)
	check(runtime.projectiles().is_empty(), "room clear cancels queued arrow")
	cleanup(runtime, [player, impact, behind])
