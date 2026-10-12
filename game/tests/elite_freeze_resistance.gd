extends "res://tests/freeze_guard.gd"

func run() -> void:
	combat = CombatLoader.new().load_catalog()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	# Special cumulative resistance remains available independently of the ranger's live profile.
	data.status_rules.actor_responses.elite_ranger = "elite_freeze_resistant"
	var other: Dictionary = data.statuses[1].duplicate(true)
	other.id = "another_freeze"
	data.statuses.append(other)
	builds = BuildLoader.new().decode(data)
	check(builds != null and combat != null, "catalogs load")
	if builds == null or combat == null: quit(1); return
	for bad in [0, -1, 1.5, "3", 65]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.status_rules.responses[0].freeze_hits_required = bad
		check(BuildLoader.new().decode(invalid) == null, "invalid freeze threshold rejected: " + str(bad))
	var missing: Dictionary = data.duplicate(true)
	missing.status_rules.responses[0].erase("freeze_hits_required")
	check(BuildLoader.new().decode(missing) == null, "missing threshold rejected")
	freeze = builds.status("test_freeze")
	guard_sec = builds.control_group(freeze.control_group).thaw_immunity_sec
	statuses.configure(builds)
	world = Node3D.new(); root.add_child(world)
	var elite = actor("elite_ranger", Vector3.ZERO)
	var normal = actor("scout", Vector3.ZERO)
	var attempts: Dictionary = {}
	check(not statuses.apply(elite, freeze.id, freeze.duration_sec, source, attempts), "first hit only accumulates")
	check(not elite.control_locked and statuses.snapshot(elite).is_empty() and statuses.visuals().is_empty(), "partial buildup does not freeze or show frozen state")
	check(not statuses.apply(elite, "another_freeze", freeze.duration_sec, source, attempts), "same root alternate status cannot count twice")
	check(statuses.freeze_progress(elite)[freeze.control_group] == 1, "one root one count")
	statuses.tick(10.0)
	check(statuses.freeze_progress(elite)[freeze.control_group] == 1, "partial buildup survives ticks without active status")
	check(not statuses.apply(elite, "another_freeze", freeze.duration_sec, source, {}), "second distinct root accumulates shared group")
	check(statuses.apply(elite, freeze.id, freeze.duration_sec, source, {}) and elite.control_locked, "third hit freezes elite")
	check(statuses.freeze_progress(elite).is_empty(), "freeze consumes all buildup")
	check(not statuses.apply(elite, freeze.id, freeze.duration_sec, source, {}), "active freeze cannot accumulate")
	statuses.tick(freeze.duration_sec)
	check(not statuses.apply(elite, freeze.id, freeze.duration_sec, source, {}), "thaw immunity cannot accumulate")
	check(statuses.freeze_progress(elite).is_empty(), "immune contacts leave no progress")
	statuses.tick(guard_sec + 0.01)
	for hit in 3:
		check(statuses.apply(elite, freeze.id, freeze.duration_sec, source, {}) == (hit == 2), "next freeze again requires three hits")
	check(statuses.apply(normal, freeze.id, freeze.duration_sec, source, {}) and normal.control_locked, "normal enemy still freezes on first hit")
	statuses.clear()
	statuses.apply(elite, freeze.id, freeze.duration_sec, source, {})
	statuses.clear()
	check(statuses.freeze_progress(elite).is_empty() and statuses.diagnostics().tracked_actors == 0, "room reset clears buildup")
	statuses.apply(elite, freeze.id, freeze.duration_sec, source, {})
	elite.health.apply(elite.health.maximum, false)
	check(statuses.freeze_progress(elite).is_empty() and statuses.diagnostics().tracked_actors == 0, "death clears partial buildup")
	statuses.clear(); world.free()
	print("ELITE_FREEZE_RESISTANCE ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
