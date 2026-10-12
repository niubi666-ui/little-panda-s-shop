extends "res://tests/freeze_followup.gd"
func tough(point: Vector3):
	var target = actor("elite_ranger", 1, point)
	target.health.maximum = 1000.0; target.health.current = 1000.0
	return target
func run() -> void:
	builds = BuildLoader.new().load_catalog(); combat = CombatLoader.new().load_catalog()
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	for distance in [2.0,6.0]: check_window(distance)
	check_melee_and_derived(); check_provenance()
	var f := setup([select("contact_freeze","skill"),select("shatter_heavy","special"),select("ice_coat","skill")])
	var victim = tough(Vector3.FORWARD)
	cast(f,"skill"); f.runtime.tick(.12)
	check(not victim.control_locked and victim.control_action_scale < 1.0, "boss window is slow, not hard freeze")
	check(f.player.protection_amount > 0.0, "successful boss window grants shield")
	f.player.runner.cancel(); cast(f,"special")
	check(victim.control_action_scale == 1.0 and not f.runtime.statuses.snapshot(victim).has("test_freeze"), "heavy consumes boss window")
	check(f.runtime.statuses.snapshot(victim).has("frost_mark"), "heavy preserves independent mark")
	check(not f.runtime.statuses.control_snapshot(victim).is_empty(), "heavy starts thaw protection")
	clean(f)
	f = setup([select("contact_freeze","skill"),select("shatter_followup","skill")])
	victim = tough(Vector3.FORWARD)
	cast(f,"skill"); f.runtime.tick(.12)
	var ctx: Dictionary = f.runtime._context_for_cast(f.player.runner.cast_id).duplicate(true); ctx.id += 1
	f.runtime.statuses.remove(victim,"test_freeze")
	check(Conditional.evaluate(ctx,victim,24.0,"direct_projectile",f.runtime.statuses,builds,f.runtime.get_instance_id()).bonus == 0.0,"mark plus immunity alone never grants followup")
	clean(f)
	print("BOSS_FROST_BUILDS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
