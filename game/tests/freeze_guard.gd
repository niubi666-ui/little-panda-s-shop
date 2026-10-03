extends "res://tests/enemy_roles.gd"
const BuildLoader = preload("res://content/builds/build_loader.gd")
const Statuses = preload("res://combat/status/status_runtime.gd")
const BuildRuntime = preload("res://combat/builds/build_runtime.gd")
const BuildFixture = preload("res://tests/fixtures/action_build_fixture.gd")
var builds
var statuses := Statuses.new()
var source := {"source_handle":1,"team":0,"root_id":1,"room_generation":1,"ability_id":"test"}
var freeze: Dictionary
var guard_sec: float

func run() -> void:
	combat = CombatLoader.new().load_catalog()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	var other: Dictionary = data.statuses[1].duplicate(true)
	other.id = "another_freeze"
	data.statuses.append(other)
	data.status_rules.actor_responses = {"scout":"resistant", "banner":"immune"}
	var loader := BuildLoader.new()
	builds = loader.decode(data)
	check(builds != null, "shared control group fixture validates")
	if builds == null:
		print(loader.errors)
		quit(1)
		return
	freeze = builds.status("test_freeze")
	guard_sec = builds.control_group(freeze.control_group).thaw_immunity_sec
	statuses.configure(builds)
	world = Node3D.new()
	root.add_child(world)
	check_continuous_sources()
	check_clock_boundaries()
	check_root_attempts()
	check_explicit_remove()
	check_cleanup()
	check_damage_immunity()
	check_reentrant_control()
	statuses.clear()
	world.free()
	print("FREEZE_GUARD ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check_continuous_sources() -> void:
	var a = actor("brute", Vector3.ZERO)
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source,{}), "first freeze accepted")
	var initial := statuses.control_snapshot(a)
	var different: Dictionary = source.duplicate()
	different.root_id = 2
	different.source_handle = 2
	different.ability_id = "area_payload"
	for step in 4:
		statuses.tick(freeze.duration_sec / 8.0)
		check(not statuses.apply(a,"another_freeze",freeze.max_duration_sec,different,{}), "new source/id/root cannot renew active group")
		check(initial == statuses.control_snapshot(a), "rejected freeze cannot move absolute deadlines")
	statuses.tick(freeze.duration_sec / 2.0)
	check(not a.control_locked and a.runner.actions_allowed, "natural thaw restores action window under repeated attacks")
	check(statuses.snapshot(a).is_empty() and statuses.visuals().is_empty(), "immunity alone is not drawn as a slow status")
	check(statuses.diagnostics().tracked_actors == 1, "immunity retains only weak target tracking")
	for step in 4:
		check(not statuses.apply(a,"another_freeze",freeze.duration_sec,different,{}), "different freeze id cannot bypass thaw immunity")
		statuses.tick(guard_sec / 8.0)
	check(not a.control_locked and a.runner.actions_allowed, "target stays actionable throughout thaw immunity")
	statuses.tick(guard_sec / 2.0 + 0.000001)
	check(statuses.control_snapshot(a).is_empty() and statuses.diagnostics().tracked_actors == 0, "expired immunity record detaches after idle window")
	check(statuses.apply(a,"another_freeze",freeze.duration_sec,different,{}), "new root freezes once immunity ends")
	statuses.clear()
	a.free()

func check_clock_boundaries() -> void:
	var a = actor("brute", Vector3.ZERO)
	statuses.apply(a,freeze.id,freeze.duration_sec,source,{})
	statuses.tick(freeze.duration_sec + guard_sec / 2.0)
	var guard: Dictionary = statuses.control_snapshot(a)[freeze.control_group]
	check(is_equal_approx(guard.immune_until,freeze.duration_sec + guard_sec), "large delta starts immunity from true expiry")
	check(not a.control_locked and not statuses.apply(a,freeze.id,freeze.duration_sec,source,{}), "large step can land inside actionable immune window")
	var before := statuses.control_snapshot(a)
	var clock_before: float = statuses.diagnostics().clock
	statuses.tick(0.0)
	statuses.tick(-1.0)
	check(statuses.control_snapshot(a) == before and statuses.diagnostics().clock == clock_before, "pause/nonpositive delta does not advance guard")
	statuses.tick(guard_sec)
	check(statuses.control_snapshot(a).is_empty(), "one step spanning remaining immunity removes record")
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source,{}), "fresh cast after large delta accepted")
	statuses.tick(freeze.duration_sec + guard_sec + 1.0)
	check(not a.control_locked and statuses.diagnostics().tracked_actors == 0, "single step crossing both stages does not extend immunity")
	statuses.clear()
	a.free()
	var resistant = actor("scout", Vector3.ZERO)
	statuses.apply(resistant,freeze.id,freeze.duration_sec,source,{})
	var scale: float = builds.status_response("scout").freeze_duration_scale
	check(is_equal_approx(statuses.control_snapshot(resistant)[freeze.control_group].immune_until,freeze.duration_sec * scale + guard_sec), "resistance changes freeze duration before computing thaw deadline")
	statuses.clear()
	resistant.free()

func check_root_attempts() -> void:
	var a = actor("brute", Vector3.ZERO)
	var attempts: Dictionary = {}
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source,attempts), "root first target/group attempt accepted")
	var sentinel := RefCounted.new()
	var sentinel_ref: WeakRef = weakref(sentinel)
	var temporary_root: Dictionary = {"sentinel":sentinel}
	check(not statuses.apply(a,freeze.id,freeze.duration_sec,source,temporary_root), "root retention probe rejects active target")
	temporary_root = {}
	sentinel = null
	check(sentinel_ref.get_ref() == null, "status runtime retains no attempt map or strong root reference")
	statuses.tick(freeze.duration_sec + guard_sec + 1.0)
	check(not statuses.apply(a,"another_freeze",freeze.duration_sec,source,attempts), "same root cannot retry via new status after immunity expires")
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source,{}), "fresh root has independent attempt map")
	var rejected_root: Dictionary = {}
	check(not statuses.apply(a,freeze.id,freeze.duration_sec,source,rejected_root), "active target consumes rejected root attempt")
	statuses.tick(freeze.duration_sec + guard_sec + 1.0)
	check(not statuses.apply(a,freeze.id,freeze.duration_sec,source,rejected_root), "previously rejected root cannot wait out immunity and retry")
	var another = actor("brute", Vector3.ZERO)
	check(statuses.apply(another,freeze.id,freeze.duration_sec,source,attempts), "root may freeze different target handle")
	var immune = actor("banner", Vector3.ZERO)
	var immune_attempts: Dictionary = {}
	check(not statuses.apply(immune,freeze.id,freeze.duration_sec,source,immune_attempts), "immune target rejects control")
	check(immune_attempts.has(immune.handle) and immune_attempts[immune.handle].has(freeze.control_group), "immune rejection still consumes root group attempt")
	var invalid_attempts: Dictionary = {}
	a.receive_hit(a.health.maximum)
	check(not statuses.apply(a,freeze.id,freeze.duration_sec,source,invalid_attempts) and invalid_attempts.is_empty(), "dead target consumes no freeze attempt")
	statuses.clear()
	a.free();another.free();immune.free()

func check_explicit_remove() -> void:
	var a = actor("brute", Vector3.ZERO)
	statuses.apply(a,freeze.id,freeze.duration_sec,source,{})
	statuses.apply(a,"test_slow",builds.status("test_slow").duration_sec,source,{})
	statuses.tick(freeze.duration_sec / 4.0)
	statuses.remove(a,freeze.id)
	check(not a.control_locked and a.control_move_scale == builds.status("test_slow").move_scale, "explicit thaw reveals remaining slow")
	var guard: Dictionary = statuses.control_snapshot(a)[freeze.control_group]
	check(is_equal_approx(guard.active_until,statuses.diagnostics().clock) and is_equal_approx(guard.immune_until,statuses.diagnostics().clock + guard_sec), "explicit removal starts full guard from current battle time")
	statuses.remove(a,"test_slow")
	check(statuses.snapshot(a).is_empty() and not statuses.control_snapshot(a).is_empty(), "removing final slow preserves thaw protection")
	var old_guard := statuses.control_snapshot(a)
	statuses.remove(a,freeze.id)
	check(statuses.control_snapshot(a) == old_guard, "removing already absent status cannot extend immunity")
	check(not statuses.apply(a,"another_freeze",freeze.duration_sec,source,{}), "dispel cannot be used to bypass guard")
	statuses.tick(guard_sec + 0.000001)
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source), "legacy four-argument apply remains usable after guard")
	statuses.clear()
	check(statuses.apply(a,freeze.id,freeze.duration_sec,source), "omitted attempt dictionary is fresh for each call")
	statuses.clear()
	a.free()

func check_cleanup() -> void:
	var a = actor("brute", Vector3.ZERO)
	statuses.apply(a,freeze.id,freeze.duration_sec,source,{})
	statuses.tick(freeze.duration_sec)
	check(a.killed.is_connected(statuses._on_killed), "guard-only record retains death cleanup subscription")
	a.receive_hit(a.health.maximum)
	check(statuses.diagnostics().tracked_actors == 0 and statuses.control_snapshot(a).is_empty(), "death clears guard immediately")
	check(not a.runner.actions_allowed, "death wins over control release")
	a.free()
	var b = actor("brute", Vector3.ZERO)
	statuses.apply(b,freeze.id,freeze.duration_sec,source,{})
	statuses.tick(freeze.duration_sec)
	b.free()
	statuses.tick(0.01)
	check(statuses.diagnostics().tracked_actors == 0, "freed guard-only target leaves no dangling weak record")
	var c = actor("brute", Vector3.ZERO)
	statuses.apply(c,freeze.id,freeze.duration_sec,source,{})
	statuses.tick(freeze.duration_sec)
	statuses.clear()
	check(statuses.diagnostics().tracked_actors == 0 and statuses.diagnostics().clock == 0.0, "room clear drops all guard records and resets local clock")
	check(not c.killed.is_connected(statuses._on_killed), "room clear disconnects surviving actor signal")
	check(statuses.apply(c,freeze.id,freeze.duration_sec,source,{}), "new room does not inherit prior immunity")
	statuses.clear()
	c.free()

func check_damage_immunity() -> void:
	var player = actor("player", Vector3.ZERO)
	player.dodge_left = player.dodge.duration
	player.dodge_age = 0.0
	check(player.invulnerable() and player.receive_hit(1.0) == 0.0, "fixture has damage invulnerability")
	check(statuses.apply(player,freeze.id,freeze.duration_sec,source,{}), "zero damage from dodge is not control immunity")
	check(player.control_locked and player.dodge_left == 0.0, "freeze cancels active dodge")
	statuses.clear()
	player.free()

func check_reentrant_control() -> void:
	var a = actor("brute", Vector3.ZERO)
	a.control_interrupted.connect(statuses.clear, CONNECT_ONE_SHOT)
	var attempts: Dictionary = {}
	check(not statuses.apply(a,freeze.id,freeze.duration_sec,source,attempts), "synchronous clear reports no surviving applied status")
	check(not a.control_locked and statuses.diagnostics().tracked_actors == 0, "control callback can clear all status records without stale dictionary access")
	check(attempts.has(a.handle), "aborted application still consumed its root attempt")
	a.free()
	var killed = actor("brute", Vector3.ZERO)
	killed.control_interrupted.connect(func():killed.receive_hit(killed.health.maximum), CONNECT_ONE_SHOT)
	check(not statuses.apply(killed,freeze.id,freeze.duration_sec,source,{}), "synchronous death makes apply return false")
	check(statuses.diagnostics().tracked_actors == 0 and not killed.runner.actions_allowed, "synchronous death clears control without re-enabling actions")
	killed.free()
	var removed = actor("brute", Vector3.ZERO)
	removed.control_interrupted.connect(func():statuses.remove(removed,freeze.id), CONNECT_ONE_SHOT)
	check(not statuses.apply(removed,freeze.id,freeze.duration_sec,source,{}), "synchronous dispel reports absent active status")
	check(not removed.control_locked and not statuses.control_snapshot(removed).is_empty(), "synchronous dispel preserves thaw immunity")
	statuses.clear()
	removed.free()
	var player = actor("player", Vector3.ZERO)
	var first = actor("brute", Vector3(0,0,-1))
	var second = actor("brute", Vector3(0,0,-2))
	var build := BuildRuntime.new()
	build.configure(builds,player,func():return [first,second],Callable(),["test_arrow"])
	check(build.set_program(BuildFixture.compile(builds,{"pierce":1,"contact_freeze":1},"debug_arrow")), "reentrant runtime test compiles an explicitly bound debug-arrow fixture")
	var build_ref: WeakRef = weakref(build)
	first.control_interrupted.connect(func():build_ref.get_ref().clear_room(), CONNECT_ONE_SHOT)
	check(build.fire_attack("test_arrow",Vector3.FORWARD), "reentrant runtime test fires")
	build.tick(0.001)
	build.tick(0.3)
	check(build.diagnostics().roots == 0 and build.diagnostics().queued == 0, "synchronous control clear_room invalidates root and following queued statuses")
	check(build.statuses.diagnostics().tracked_actors == 0 and not first.control_locked and not second.control_locked, "clear_room during status application does not leave frozen enemies")
	build.clear_room()
	player.free();first.free();second.free()
