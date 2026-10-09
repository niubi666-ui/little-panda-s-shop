extends "res://tests/action_build_runtime.gd"
## Renderer-independent isolation test using real runtime facts and real view adapters.
const EffectsView = preload("res://presentation/builds/build_effects_view.gd")
const MechanismView = preload("res://presentation/builds/mechanism_view.gd")
const EffectsStyle = preload("res://presentation/builds/build_effects_style.tres")
const MechanismStyle = preload("res://presentation/builds/mechanism_style.tres")
const Probe = preload("res://tests/fixtures/action_vfx_probe.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func run() -> void:
	var loader := BuildLoader.new()
	builds = loader.load_catalog()
	combat = CombatLoader.new().load_catalog()
	check(builds != null and combat != null, "vfx fixture catalogs load: " + str(loader.errors))
	if builds == null or combat == null: finish_vfx(); return
	resolver.configure(builds)
	var expected: Dictionary = {}
	for mode in ["default", "disabled", "null_slots", "replacement"]:
		var result := run_frost_trial(mode)
		if expected.is_empty(): expected = result
		else: check(result == expected, mode + ": same casts retain identical HP/status results")
	check_cancel_cleanup()
	print("ACTION_BUILD_VFX ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func finish_vfx() -> void:
	print("ACTION_BUILD_VFX ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(1)

func scene_for(slot: String) -> PackedScene:
	var node := Node3D.new()
	node.set_script(Probe)
	node.set("slot", slot)
	var scene := PackedScene.new()
	check(scene.pack(node) == OK, "pack replaceable scene: " + slot)
	node.free()
	return scene

func attach_views(f: Dictionary, mode: String) -> Dictionary:
	var effects_style: Resource = EffectsStyle.duplicate(true)
	var mechanism_style: Resource = MechanismStyle.duplicate(true)
	if mode == "disabled":
		effects_style.enabled = false
		mechanism_style.enabled = false
	if mode in ["replacement", "null_slots"]:
		effects_style.projectile_scene_rules.clear()
		for pair in [["projectile_scenes", "projectile"], ["trail_scenes", "trail"], ["contact_scenes", "contact"], ["termination_scenes", "end"]]:
			effects_style.get(pair[0])["sword_wave"] = scene_for(pair[1]) if mode == "replacement" else null
		for event in ["started", "cue"]:
			effects_style.action_scenes["wave_cast/" + event] = scene_for("action_" + event) if mode == "replacement" else null
		mechanism_style.area_scenes["impact_blast/status"] = scene_for("area") if mode == "replacement" else null
		mechanism_style.status_scenes["freeze"] = scene_for("status") if mode == "replacement" else null
	var effects := EffectsView.new()
	var mechanisms := MechanismView.new()
	root.add_child(effects)
	root.add_child(mechanisms)
	effects.configure(effects_style)
	mechanisms.configure(mechanism_style)
	f.runtime.projectile_presented.connect(effects.on_projectile_event)
	f.runtime.action_presented.connect(effects.on_action_event)
	f.runtime.area_presented.connect(mechanisms.show_area_fact)
	return {"effects": effects, "mechanisms": mechanisms}

func refresh_views(f: Dictionary, views: Dictionary, delta: float) -> void:
	views.effects.sync(f.runtime.projectiles(), delta)
	views.mechanisms.sync(f.runtime.statuses.visuals(), delta)

func step_trial(f: Dictionary, views: Dictionary, delta: float) -> void:
	f.runtime.statuses.tick(delta)
	f.runtime.tick(delta)
	refresh_views(f, views, delta)

func probe_time(views: Dictionary) -> float:
	var elapsed := 0.0
	for owner in [views.effects, views.mechanisms]:
		for child in owner.get_children():
			if child.get_script() == Probe: elapsed += float(child.elapsed)
	return elapsed

func run_frost_trial(mode: String) -> Dictionary:
	Probe.records.clear()
	var selected: Array = builds.test_preset("skill_frost").selections.duplicate(true)
	var f := setup(selected, func(_a, _b): return null)
	var near = actor("brute", 1, Vector3(0, 0, -1))
	var side = actor("brute", 1, Vector3(1, 0, -1))
	var later = actor("brute", 1, Vector3(0, 0, -5))
	var views := attach_views(f, mode)
	cast(f, "skill")
	refresh_views(f, views, 0.0)
	check(f.runtime.projectiles().size() == 1, mode + ": cue launches authoritative projectile")
	if mode == "default": check(views.effects.get_child_count() > 0, "default configured mesh visibly instantiated")
	if mode in ["disabled", "null_slots"]: check(views.effects.get_child_count() == 0, mode + ": no projectile/action/trail nodes")
	# Apply a stronger new program after release, before impact. No consumer may
	# guess old shot metadata or duration from the newest selected program.
	selected.append(select("freeze_duration", "skill"))
	var next := resolver.resolve({"selections": selected, "revision": 2})
	check(f.runtime.set_program(next) and f.player.set_action_program(next.actions, combat), mode + ": new plan applied with old shot in flight")
	step_trial(f, views, 0.1)
	check(near.control_locked and side.control_locked and not later.control_locked, mode + ": actual old frost payload freezes its local area")
	var status: Dictionary = f.runtime.statuses.snapshot(side).test_freeze
	check(status.source.action_id == "skill" and status.source.revision == 1, mode + ": status records original action/revision")
	check(is_equal_approx(status.remaining, builds.status("test_freeze").duration_sec), mode + ": new duration support cannot rewrite old cast")
	if mode == "default": check(views.mechanisms.get_child_count() >= 3, "default area and both frozen bodies have views")
	if mode in ["disabled", "null_slots"]: check(views.mechanisms.get_child_count() == 0, mode + ": no area/status nodes")
	var before_shots: Array = f.runtime.projectiles()
	var before_status: Dictionary = f.runtime.statuses.snapshot(side)
	var before_time := probe_time(views)
	var child_counts := [views.effects.get_child_count(), views.mechanisms.get_child_count()]
	for ignored in 3: step_trial(f, views, 0.0)
	check(f.runtime.projectiles() == before_shots and f.runtime.statuses.snapshot(side) == before_status, mode + ": delta0 freezes projectile and status rules")
	check(probe_time(views) == before_time and child_counts == [views.effects.get_child_count(), views.mechanisms.get_child_count()], mode + ": delta0 preserves visual lifetime and instances")
	if mode == "replacement":
		for slot in ["action_started", "action_cue", "projectile", "trail", "contact", "area", "status"]:
			check(Probe.records.any(func(record): return record.method == "configure" and record.slot == slot), "Resource hook consumed committed fact: " + slot)
		check(Probe.records.any(func(record): return record.method == "configure" and record.slot == "status" and record.fact.statuses[0].source.action_id == "skill" and record.fact.statuses[0].source.revision == 1), "status Resource receives original bound source metadata")
		for record in Probe.records:
			if record.method != "configure" or record.slot == "status": continue
			check(record.fact.action_id == "skill" and record.fact.revision == 1 and record.fact.presentation_key == "wave_cast", "old metadata reaches " + str(record.slot))
		for owner in [views.effects, views.mechanisms]:
			for child in owner.get_children():
				if child.get_script() == Probe: check(not child.running, "adapter communicates paused clock")
		check(f.runtime.projectiles()[0].revision == 1, "probe mutation cannot corrupt authoritative snapshot")
	# Cancel the actor after release: action cue nodes go away, the already released
	# projectile remains alive until its own authoritative terminal event.
	f.player.runner.cancel("dodge")
	check(not f.runtime.projectiles().is_empty(), mode + ": cancellation preserves already emitted projectile")
	if mode == "replacement":
		check(not views.effects.get_children().any(func(node): return node.get_script() == Probe and str(node.slot).begins_with("action_")), "cancel removes action started/cue nodes")
	step_trial(f, views, 0.5)
	step_trial(f, views, 0.5)
	check(f.runtime.projectiles().is_empty() and later.health.current < later.health.maximum, mode + ": flight finishes with same later pierced hit")
	if mode == "replacement":
		check(Probe.records.any(func(record): return record.method == "configure" and record.slot == "end" and record.fact.reason == "expired" and record.fact.revision == 1), "termination hook consumes old shot reason and metadata")
		check(Probe.records.any(func(record): return record.method == "finish" and record.slot == "projectile" and record.reason == "expired"), "live projectile adapter receives finish reason")
	var outcome := {"health": [near.health.current, side.health.current, later.health.current], "initial_freeze": status.remaining,
		"status_action": status.source.action_id, "status_revision": status.source.revision,
		"rejected": f.runtime.diagnostics().rejected}
	f.runtime.clear_room()
	views.effects.clear()
	views.mechanisms.clear()
	check(views.effects.get_child_count() == 0 and views.mechanisms.get_child_count() == 0, mode + ": room teardown removes all view nodes")
	check(f.runtime.projectiles().is_empty() and not side.control_locked and f.runtime.statuses.visuals().is_empty(), mode + ": room teardown removes rules and status visuals")
	views.effects.free()
	views.mechanisms.free()
	clean(f)
	return outcome

func check_cancel_cleanup() -> void:
	Probe.records.clear()
	var f := setup([])
	var views := attach_views(f, "replacement")
	f.player.runner.committed.connect(func(_id,_ability): f.player.runner.cancel("control"), CONNECT_ONE_SHOT)
	check(f.player.runner.start(combat.ability("wave_cast"), Vector3.FORWARD, f.program.actions.skill), "pre-cue cancel fixture begins")
	check(views.effects.get_child_count() == 0, "cancelled commit retires action scene before instant cue")
	f.player.runner.cancel("dodge")
	step_trial(f, views, 0.0)
	check(views.effects.get_child_count() == 0 and f.runtime.projectiles().is_empty(), "pre-cue cancellation leaves no action VFX or projectile")
	f.player.runner.tick(2.0)
	step_trial(f, views, 2.0)
	check(views.effects.get_child_count() == 0 and views.mechanisms.get_child_count() == 0, "cancelled cast never resurrects VFX after time advances")
	views.effects.clear()
	views.mechanisms.clear()
	views.effects.free()
	views.mechanisms.free()
	clean(f)
