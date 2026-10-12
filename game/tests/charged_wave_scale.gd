extends "res://tests/action_build_runtime.gd"
func run() -> void:
	builds = BuildLoader.new().load_catalog(); combat = CombatLoader.new().load_catalog()
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	var f := setup([select("charged_wave","skill")])
	f.player.press_skill(); f.player.step(float(f.player.charge_parameters().max_charge_sec))
	check(f.runtime.projectiles().is_empty(), "holding does not fire")
	f.player.release_skill(); f.player.step(.01); f.runtime.tick(.001)
	var fact: Dictionary = f.runtime.projectiles()[0]
	check(fact.charged and is_equal_approx(fact.radius,1.95), "committed full charge has authored demo width")
	var view := preload("res://presentation/builds/build_effects_view.gd").new()
	root.add_child(view); view.configure(load("res://presentation/builds/build_effects_style.tres"))
	view.sync([fact],.1)
	var wave = view._projectiles[fact.id]
	check(wave.profile == load("res://presentation/combat/fx/sword_waves_v001/frost_profile.tres"), "full charge uses existing frost art without needing freeze card")
	check(wave._art.global_basis.get_scale().is_equal_approx(Vector3.ONE), "art matches original demo dimensions on all axes")
	var victim = actor("brute",1,Vector3(1.5,0,-2))
	victim.health.maximum = 1000.0; victim.health.current = 1000.0
	f.runtime.tick(.2)
	check(is_equal_approx(1000.0-victim.health.current,combat.ability("wave_cast").damage*3.0), "wide side contact deals triple base damage")
	check(not f.runtime.statuses.snapshot(victim).has("test_freeze"), "frost appearance grants no unselected freeze ability")
	view.clear(); view.free(); clean(f)
	f = setup([select("charged_wave","skill")])
	f.player.press_skill(); f.player.step(.1); f.player.release_skill(); f.player.step(.01); f.runtime.tick(.001)
	fact = f.runtime.projectiles()[0]
	check(not fact.charged and is_equal_approx(fact.radius,builds.projectile("sword_wave").radius_m), "short charge keeps normal width")
	clean(f)
	print("CHARGED_WAVE_SCALE ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
