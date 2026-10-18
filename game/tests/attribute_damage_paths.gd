extends "res://tests/combat_attributes.gd"
const Resolver = preload("res://combat/builds/build_resolver.gd")
var builds
func run() -> void:
	combat = CombatLoader.new().load_catalog()
	enemies = EnemyLoader.new().load_catalog(combat)
	builds = BuildLoader.new().load_catalog()
	world = Node3D.new(); root.add_child(world)
	check(combat != null and enemies != null and builds != null, "all migrated catalogs load")
	if combat == null or enemies == null or builds == null: quit(1); return
	derived_paths()
	test_arrow_and_chain()
	live_elements()
	for element in ["fire", "ice", "thunder", "earth"]: mastery_path(element)
	for pair in [["fire","ice","steam"],["fire","thunder","overload"],["fire","earth","lava"],["ice","thunder","superconduct"],["ice","earth","shatter"],["thunder","earth","magnet"]]: reaction_path(pair)
	for id in ["scout","elite_ranger"]: freeze_paths(id)
	enemy_paths()
	world.free()
	print("ATTRIBUTE_DAMAGE_PATHS ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func selection(id: String, action: String) -> Dictionary: return {"upgrade_id":id,"action_id":action,"rank":1}
func fixture(cards: Array, source_id: String = "player") -> Dictionary:
	var source = actor(source_id,Vector3.ZERO)
	source.attributes.set_modifier("test", "crit_chance", "flat", -source.attributes.value("crit_chance"))
	var resolver := Resolver.new(); resolver.configure(builds)
	var state := {"revision":1,"selections":cards}
	check(resolver.validate_state(state).is_empty(), "legal fixture " + str(resolver.validate_state(state)))
	var program := resolver.resolve(state)
	var targets: Array = []
	var rt := BuildRuntime.new(); rt.configure(builds,source,func():return targets,func(_a,_b):return null,["test_arrow"])
	rt.set_program(program); source.set_action_program(program.actions,combat)
	source.runner.committed.connect(rt.on_committed)
	source.runner.cue_reached.connect(rt.on_cue)
	source.runner.finished.connect(rt.on_finished)
	return {"source":source,"rt":rt,"program":program,"targets":targets,"cards":cards}
func tough(f: Dictionary, id: String = "scout", point: Vector3 = Vector3(0,0,-4)):
	var target = actor(id,point)
	target.team = 1 - f.source.team
	target.attributes.set_modifier("test", "max_health", "flat",10000.0)
	target.health.restore(); f.targets.append(target)
	return target
func begin(f: Dictionary, action: String) -> Dictionary:
	f.source.cancel(); f.source.runner._cooldowns.clear()
	var plan: Dictionary = f.program.actions[action]
	check(f.source.runner.start(combat.ability(plan.ability_ids[0]),Vector3.FORWARD,plan), "real cast commits " + action)
	return f.rt._context_for_cast(f.source.runner.cast_id)
func hit(f: Dictionary, action: String, target) -> Dictionary:
	var context := begin(f,action)
	return f.rt._apply_direct_damage(context,target,context.base_damage,"direct_projectile" if action == "skill" else "direct_melee")
func change(f: Dictionary, cards: Array) -> void:
	var resolver := Resolver.new(); resolver.configure(builds)
	f.program = resolver.resolve({"revision":2,"selections":cards})
	check(not f.program.is_empty(),"live build change valid")
	f.rt.set_program(f.program)
func dispose(f: Dictionary) -> void:
	f.rt.clear_room(); f.source.free()
	for target in f.targets: target.free()
func derived_paths() -> void:
	var f := fixture([selection("power","global"),selection("split","skill"),selection("impact_blast","skill")])
	f.source.attributes.set_modifier("test", "crit_chance", "flat",0.95)
	var victim = tough(f)
	victim.attributes.set_modifier("test","armor","flat",990.0)
	victim.health.current = 1.0
	var nearby = tough(f,"scout",Vector3(1,0,-4))
	var hits: Array = []
	nearby.damage_received.connect(func(fact): hits.append(fact))
	var context := begin(f,"skill")
	check(context.damage_request.critical,"root critical chosen once")
	f.source.runner.tick(f.source.runner.ability.windup)
	for i in 60: f.rt.tick(1.0/60.0)
	var explosions := hits.filter(func(fact):return fact.profile_id == "impact_blast")
	check(hits.any(func(fact):return fact.origin=="split_projectile" and fact.critical),"actual split projectile inherits root crit")
	check(not explosions.is_empty(),"actual wave contact emits explosion")
	if not explosions.is_empty():
		var e: Dictionary = explosions[0]
		check(not e.critical and e.components[0].type=="magical","explosion is magical and ignores parent crit")
		check(e.components[0].basis > 5.0,"overkill and high armor do not collapse explosion basis")
		check(is_equal_approx(e.raw,e.components[0].basis*f.program.actions.skill.damage_scale),"derived weapon bonus applies once")
		check(e.is_read_only() and e.components.is_read_only(),"published damage immutable")
	var child_request: Dictionary = f.rt._damage_request(context,context.base_damage*0.65,"split_projectile")
	var child := Damage.submit(nearby,child_request)
	check(child.critical and child.components[0].type=="physical","split inherits critical and parent damage type")
	var old: Dictionary = child_request.duplicate(true)
	f.rt.clear_room()
	check(not Damage.submit(nearby,old).valid_hit,"old room request rejected")
	dispose(f)
	# Return path hits the same live target again with the original root decision.
	f=fixture([selection("returning_wave","skill"),selection("pierce","skill")]); victim=tough(f); hits=[]
	f.source.attributes.set_modifier("test","crit_chance","flat",0.95)
	victim.damage_received.connect(func(fact):hits.append(fact))
	begin(f,"skill"); f.source.runner.tick(f.source.runner.ability.windup)
	for i in 180: f.rt.tick(1.0/60.0)
	check(hits.size()==2 and hits.all(func(fact):return fact.critical),"outbound and returning wave share crit")
	dispose(f)
func test_arrow_and_chain() -> void:
	var f:=fixture([selection("split","debug_arrow"),selection("power","global")])
	f.source.attributes.set_modifier("test","crit_chance","flat",0.95)
	var victim=tough(f)
	var adjacent=tough(f,"scout",Vector3(0.7,0,-5))
	var hits: Array=[]
	victim.damage_received.connect(func(fact):hits.append(fact))
	adjacent.damage_received.connect(func(fact):hits.append(fact))
	check(f.rt.fire_attack("test_arrow",Vector3.FORWARD),"test arrow fires without sword upgrade")
	for i in 120: f.rt.tick(1.0/60.0)
	check(hits.any(func(fact):return fact.profile_id=="debug.test_arrow" and fact.origin=="direct_projectile"),"test arrow uses its referenced damage profile")
	check(hits.any(func(fact):return fact.origin=="split_projectile" and fact.critical and fact.components[0].type=="physical"),"test arrow split inherits physical critical")
	dispose(f)
	f=fixture([selection("chain","debug_melee"),selection("power","global")])
	f.source.attributes.set_modifier("test","crit_chance","flat",0.95)
	victim=tough(f,"scout",Vector3(0,0,-1)); victim.health.current=1.0
	victim.attributes.set_modifier("test","armor","flat",990.0)
	adjacent=tough(f,"scout",Vector3(1,0,-1)); hits=[]
	adjacent.damage_received.connect(func(fact):hits.append(fact))
	var context:=begin(f,"debug_melee")
	var direct: Dictionary=f.rt.apply_melee_damage(f.source,victim,context.base_damage)
	f.rt.on_melee_hit(f.source,victim,context.cast_id,context.ability_id,direct.health_loss)
	for i in 4: f.rt.tick(1.0/60.0)
	var chains:=hits.filter(func(fact):return fact.profile_id=="chain")
	check(chains.size()==1,"actual melee schedules one chain to nearby target")
	if not chains.is_empty():
		var ratio: float=builds.upgrade("chain").ranks[0].damage_ratio
		check(not chains[0].critical and chains[0].components[0].type=="magical","chain ignores parent crit and is magical")
		check(is_equal_approx(chains[0].raw,context.base_damage*ratio*f.program.actions.debug_melee.damage_scale),"chain basis ignores main target overkill and armor; source bonus once")
	dispose(f)

func live_elements() -> void:
	var cards := [selection("fire_core","primary"),selection("earth_core","special")]
	var f:=fixture(cards); var target=tough(f)
	var hits: Array=[]; target.damage_received.connect(func(fact):hits.append(fact))
	hit(f,"primary",target); f.rt.elements.tick(0.5,f.rt)
	var burns:=hits.filter(func(fact):return fact.profile_id=="element.fire.tick")
	check(not burns.is_empty(),"fire tick uses damage executor")
	var before: float=burns.back().raw if not burns.is_empty() else 0.0
	change(f,cards+[selection("fire_kindling","global")]); f.rt.elements.tick(0.5,f.rt)
	burns=hits.filter(func(fact):return fact.profile_id=="element.fire.tick")
	check(not burns.is_empty() and burns.back().raw>before,"existing burn reads new global boost")
	hit(f,"special",target)
	check(f.rt.elements._zones.size()==1,"fire earth creates lava source recipe")
	hits.clear(); f.rt.elements.tick(0.5,f.rt)
	var ticks:=hits.filter(func(fact):return fact.profile_id=="reaction.lava.tick")
	check(not ticks.is_empty(),"lava tick reaches executor")
	before=ticks.back().raw if not ticks.is_empty() else 0.0
	change(f,cards+[selection("dual_lava","global")]); f.rt.elements.tick(0.5,f.rt)
	ticks=hits.filter(func(fact):return fact.profile_id=="reaction.lava.tick")
	check(not ticks.is_empty() and ticks.back().raw>before,"existing lava reads new reaction boost")
	f.source.health.apply(f.source.health.current,false); before=target.health.current
	f.rt.elements.tick(0.5,f.rt)
	check(target.health.current==before,"dead source cannot keep dealing damage")
	dispose(f)
	# Build runtime is injected with an enemy source too; no executor fallback to player.
	f=fixture([selection("fire_core","primary")],"crossbow"); target=tough(f)
	hits=[]; target.damage_received.connect(func(fact):hits.append(fact))
	hit(f,"primary",target); f.rt.elements.tick(0.5,f.rt)
	check(hits.any(func(fact):return fact.profile_id=="element.fire.tick" and fact.team==1 and fact.source_handle==f.source.handle),"DoT retains real non-player source")
	dispose(f)
func mastery_path(element: String) -> void:
	var f:=fixture([selection(element+"_core","primary"),selection(element+"_core","skill"),selection(element+"_mastery_burst","global")])
	var target=tough(f); var adjacent=tough(f,"scout",Vector3(1,0,-4))
	var hits: Array=[]; adjacent.damage_received.connect(func(fact):hits.append(fact))
	for i in 6: hit(f,"primary",target)
	var seen:=hits.filter(func(fact):return fact.profile_id=="mastery."+element)
	check(not seen.is_empty(),element+" mastery uses unified damage")
	if not seen.is_empty(): check(seen[0].components[0].type==("physical" if element=="earth" else "magical") and not seen[0].critical,element+" mastery type/crit")
	dispose(f)
func reaction_path(pair: Array) -> void:
	var f:=fixture([selection(pair[0]+"_core","primary"),selection(pair[1]+"_core","special")])
	var target=tough(f); var hits: Array=[]
	target.damage_received.connect(func(fact):hits.append(fact))
	for i in (3 if pair[2]=="shatter" else 1): hit(f,"primary",target)
	hit(f,"special",target)
	var seen:=hits.filter(func(fact):return fact.profile_id=="reaction."+pair[2]+".direct")
	check(not seen.is_empty(),pair[2]+" direct reaction reaches executor")
	if not seen.is_empty(): check(seen[0].components[0].type==("physical" if pair[2]=="shatter" else "magical"),pair[2]+" reaction type")
	dispose(f)
func freeze_paths(id: String) -> void:
	var f:=fixture([selection("ice_core","skill"),selection("shatter_followup","skill"),selection("opening_strike","primary"),selection("ice_coat","skill")])
	var target=tough(f,id)
	target.grant_protection(500.0,10.0)
	for i in 3: check(hit(f,"skill",target).valid_hit,"shielded cold hit counts")
	check(f.rt.statuses.snapshot(target).has("test_freeze"),id+" freezes through shield")
	check(f.source.protection_amount>0.0,id+" successful window grants ice coat")
	var follow:=hit(f,"skill",target)
	check(follow.poise_basis>24.0,id+" earlier independent freeze grants followup")
	var opening:=hit(f,"primary",target)
	check(opening.poise_basis>16.0,id+" other action freeze grants opening strike")
	target.set_damage_immunity(true)
	check(not hit(f,"skill",target).valid_hit,"invulnerability rejects element hit")
	dispose(f)
func enemy_paths() -> void:
	var player=actor("player",Vector3(0,0,-8)); player.attributes.set_modifier("test","max_health","flat",10000); player.health.restore()
	var ranger=actor("elite_ranger",Vector3.ZERO)
	ranger.set_spawn_scaling(1.6,1.2)
	check(ranger.health.maximum==720.0,"boss HP depth applied once")
	var rt=runtime(player)
	rt.sweep_world=func(_a,_b,_r):return 1.0
	var brain=rt.add(ranger,enemies.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_d):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_a,_b):return true,"seed":1})
	var hits: Array=[]; player.damage_received.connect(func(fact):hits.append(fact))
	brain._start("charged"); brain.tick(brain.windup_duration); rt.after_motion(0.1); rt.after_motion(0.4)
	check(hits.any(func(fact):return fact.profile_id=="enemy.elite_ranger.charged" and is_equal_approx(fact.raw,60.0)),"charged arrow AD and depth exactly once")
	check(hits.any(func(fact):return fact.profile_id=="enemy.elite_ranger.charged_rift" and fact.components[0].type=="magical" and is_equal_approx(fact.raw,9.6)),"rift AP magical and depth once")
	brain.cancel(); brain._start("rain"); brain.tick(brain.windup_duration)
	for i in 180: rt.after_motion(1.0/60.0)
	check(hits.any(func(fact):return fact.profile_id=="enemy.elite_ranger.rain" and fact.components[0].type=="physical"),"actual rain pulse physical")
	var banner=actor("banner",Vector3(1,0,0)); add(rt,banner)
	rt.update_auras(); rt.update_auras()
	check(is_equal_approx(ranger.attributes.value("attack_speed_multiplier"),1.3),"repeated aura refresh does not stack")
	check(is_equal_approx(ranger.attributes.value("move_speed_mps"),3.3*1.3),"aura movement applies once")
	var old: Dictionary=brain.attack_request.duplicate(true); rt.clear()
	check(not Damage.submit(player,old).valid_hit,"enemy old room request rejected")
	player.free();ranger.free();banner.free()
