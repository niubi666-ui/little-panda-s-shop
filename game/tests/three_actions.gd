extends "res://tests/action_build_runtime.gd"
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const CooldownText = preload("res://presentation/combat/skill_cooldown_text.gd")

func run() -> void:
	builds=BuildLoader.new().load_catalog()
	combat=CombatLoader.new().load_catalog()
	resolver.configure(builds)
	var f:=setup([])
	check(f.program.actions.primary.ability_ids.size()==3 and f.program.actions.special.form_id=="sword_heavy" and f.program.actions.skill.form_id=="sword_wave", "zero Build grants all three actions")
	check(not builds.has_upgrade("sword_wave_form") and not builds.has_upgrade("sword_heavy_form"), "obsolete unlock/restore cards removed")
	var legacy:Dictionary=f.program.actions.duplicate(true)
	legacy.erase("skill")
	check(not f.player.set_action_program(legacy,combat), "old two-action wiring explicitly rejected")
	for upgrade in ["contact_freeze","impact_blast","pierce","split"]:
		check(resolver.legal_operations({"selections":[],"revision":0},upgrade).any(func(op):return op.action_id=="skill"), "base skill eligible for " + upgrade)
	for id in ["primary","special","skill"]:
		f.player.runner.tick(10.0)
		cast(f,id)
		check(f.player.runner.action_id==id, "all base actions execute: "+id)
	check(f.runtime.projectiles().size()==1,"only Q produces the base projectile")
	clean(f)
	# Three separate cores and ranks compile without leaking into any other action.
	f=setup([select("impact_blast","primary"),select("contact_freeze","special"),select("impact_blast","skill"),select("pierce","skill")])
	check(f.program.actions.primary.effects.size()==1 and f.program.actions.special.effects.size()==1 and f.program.actions.skill.effects.size()==2,"three-way bindings remain independent")
	var victim=actor("brute",1,Vector3.FORWARD)
	cast(f,"skill");f.runtime.tick(.2)
	check(not victim.control_locked,"Q blast does not inherit heavy freeze")
	clean(f)
	f=setup([select("impact_blast","primary"),select("contact_freeze","skill")])
	victim=actor("brute",1,Vector3.FORWARD)
	cast(f,"special")
	check(victim.health.current<victim.health.maximum and not victim.control_locked and f.runtime.projectiles().is_empty(),"heavy remains useful melee damage without primary/Q effects")
	clean(f)
	# Later left input cancels pending right input; other same-frame priorities remain stable.
	var input_cases := [
		{"order":["primary","special","skill"], "winner":"skill"},
		{"order":["skill","primary","special"], "winner":"special"},
		{"order":["special","skill","primary"], "winner":"primary"},
		{"order":["primary","skill","special"], "winner":"skill"},
		{"order":["special","primary","skill"], "winner":"skill"},
		{"order":["skill","special","primary"], "winner":"primary"},
	]
	for test_case in input_cases:
		f=setup([])
		for id in test_case.order:f.player.request_action(id,100)
		f.player.step(.001)
		f.runtime.tick(.001)
		check(f.player.runner.action_id==test_case.winner and f.player.runner.cast_id==1,"one winning action respects later-left cancellation: "+str(test_case.order))
		for id in ["primary","special","skill"]:
			if id != test_case.winner: check(f.player.runner.cooldown_for(id)==0.0,"cancelled input does not spend cooldown: "+id)
		f.player.step(f.player.runner.ability.windup); f.runtime.tick(.001)
		check(f.runtime.projectiles().size()==(1 if test_case.winner=="skill" else 0),"only accepted skill emits at its authored swing cue")
		clean(f)
	f=setup([])
	f.player.request_action("skill",101);f.player.request_dodge();f.player.step(.001)
	check(f.player.runner.cast_id==0 and f.player.dodge_left>0.0,"dodge wins over Q")
	clean(f)
	f=setup([])
	var camera:=Camera3D.new();root.add_child(camera)
	var blocked:Dictionary={"value":true}
	var input:=InputAdapter.new(f.player,camera,func():return blocked.value)
	var key:=InputEventMouseButton.new();key.button_index=MOUSE_BUTTON_RIGHT;key.pressed=true
	input.event(key)
	check(f.player.buffered_action_id.is_empty(),"modal/pause gate blocks Q")
	blocked.value=false
	input.event(key);f.player.step(.001);f.runtime.tick(.001)
	check(f.player.runner.action_id=="skill" and f.runtime.projectiles().is_empty(),"right mouse begins native wave windup")
	f.player.step(f.player.runner.ability.windup); f.runtime.tick(.001)
	check(f.runtime.projectiles().size()==1,"right mouse fires without unlock")
	var field:=LineEdit.new();root.add_child(field);field.grab_focus();await process_frame
	input.event(key)
	check(f.player.buffered_action_id.is_empty(),"text focus blocks Q")
	field.free()
	for locale in ["zh_CN","en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale));TranslationServer.set_locale(locale)
		var seconds := "%.1f" % (ceilf(f.player.runner.cooldown_for("skill") * 10.0) / 10.0)
		check(not CooldownText.format_for(f.player).contains("combat.") and CooldownText.format_for(f.player).contains(seconds),"localized skill countdown uses actual timer")
	var remaining:float=f.player.runner.cooldown_for("skill")
	f.player.step(0.0)
	check(f.player.runner.cooldown_for("skill")==remaining,"zero-time pause does not advance Q cooldown")
	f.player.runner.tick(1.0)
	check(not CooldownText.format_for(f.player).contains("1.0"),"HUD transitions out of cooldown")
	var heavy := InputEventKey.new(); heavy.physical_keycode = KEY_R; heavy.pressed = true
	input.event(heavy); f.player.step(.001)
	check(f.player.runner.action_id == "special", "R starts heavy attack")
	f.player.runner.cancel(); f.player.clear_intents()
	var old_key := InputEventKey.new(); old_key.physical_keycode = KEY_Q; old_key.pressed = true
	input.event(old_key)
	check(f.player.buffered_action_id.is_empty(), "Q no longer requests a combat action")
	camera.free();clean(f)
	print("THREE_ACTIONS ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
