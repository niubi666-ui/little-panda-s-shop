extends SceneTree
const Runtime = preload("res://combat/enemies/enemy_runtime.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Presentation = preload("res://presentation/combat/enemies/enemy_presentation.gd")
const Style = preload("res://presentation/combat/training_style.tres")
var failures: Array[String] = []
var checks := 0
var combat
var runtime
var player
var ranger
var brain
var presentation
var fx
var pulses: Array = []
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func():quit(1))
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label);push_error(label)
func make_actor(id: String, handle: int):
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	actor.configure(combat.actor(id),abilities,combat.dodge() if id=="player" else null,handle,0 if id=="player" else 1)
	root.add_child(actor)
	return actor
func start(id: String) -> void:
	brain._start(id)
	brain.tick(brain.windup_duration)
func step(delta: float) -> void:
	runtime.after_motion(delta)
	presentation.refresh(delta)
func run() -> void:
	combat = preload("res://content/combat/combat_loader.gd").new().load_catalog()
	var catalog = preload("res://content/enemies/enemy_loader.gd").new().load_catalog(combat)
	player=make_actor("player",1);ranger=make_actor("elite_ranger",2)
	player.position=Vector3(0,0,-6)
	runtime=Runtime.new()
	runtime.configure(player,.35,func(a):return a.position+Vector3.UP,func(_a,_b,_r):return 1.0)
	brain=runtime.add(ranger,catalog.profile("elite_ranger"),Callable(),func(_a,_b):return true,func(_a,_b):return true,{"roll_path":func(_a,_b):return true,"ground":func(_p):return true,"rain_escape":func(_areas,_settings):return true,"seed":42})
	presentation=Presentation.new();root.add_child(presentation);presentation.configure(runtime,Style)
	fx=presentation.ranger_vfx
	check(fx.profile.valid(),"complete authoritative VFX Resources load")
	var invalid=fx.profile.duplicate();invalid.arrow_scene=null
	check(not invalid.valid(),"missing arrow asset rejects profile without fallback")
	var state: int=brain.random.state
	start("fast");step(.08)
	check(fx.live_arrows.size()==1,"single actual projectile has one physical arrow view")
	var arrow=fx.live_arrows.values()[0].view
	check(arrow.body.find_children("*","MeshInstance3D",true,false).size()>=2,"physical arrow asset plus tip flare are present")
	check(arrow.history.size()>=2 and arrow.layers[0].mesh.get_surface_count()>0,"travel creates a world-space layered trail")
	var age: float=arrow.clock
	var point: Vector3=arrow.body.global_position
	presentation.refresh(0.0)
	check(arrow.clock==age and arrow.body.global_position==point,"zero display delta freezes trail and projectile presentation")
	check(brain.random.state==state,"visual seeds do not consume ranger gameplay RNG")
	var hp: float=player.health.current
	while not runtime.projectiles.is_empty(): step(.02)
	var shown_damage: float=hp-player.health.current
	check(fx.live_arrows.is_empty() and not fx.tails.is_empty(),"hit retires arrow and leaves finite afterglow")
	check(fx.bursts.size()>=2,"actual hit creates an impact burst separate from release")
	fx.set_enabled(false);player.health.restore();hp=player.health.current
	start("fast");step(.5)
	check(is_equal_approx(hp-player.health.current,shown_damage),"disabled visuals preserve single-arrow damage")
	check(fx.live_arrows.is_empty() and fx.bursts.is_empty(),"disabled VFX produces no meshes or bursts")
	fx.set_enabled(true);player.health.restore()
	brain._start("charged")
	var warning := preload("res://presentation/combat/enemies/ranger_warning.gd").new()
	root.add_child(warning);warning.configure(brain,presentation)
	brain.time_left=brain.config.charged_lock_sec
	warning.refresh(.01)
	check(warning.glow.visible and warning.light.visible and warning.charge_audio.playing and warning.lock_audio.playing,"charged locked cue has visible glow and distinct audio")
	await physics_frame
	await physics_frame
	warning.refresh(0.0)
	check(warning.charge_audio.stream_paused and warning.lock_audio.stream_paused,"pause stops charge and lock sound playback")
	brain.tick(brain.time_left);warning.refresh(.01);step(.02)
	check(not warning.glow.visible and not warning.charge_audio.playing,"release retires charge cue")
	var charged=fx.charged_fx.casts.values()[0]
	check(charged.effect.flight_arrow.visible and charged.state.config.skill.arrow_radius_m==brain.config.arrow_radius_m,"approved charged arrow renders from authoritative rule radius")
	warning.free();runtime.projectiles.clear();runtime.charged_rifts.clear();presentation.refresh(0.0);fx.clear()
	start("volley");step(.02)
	check(fx.live_arrows.size()==int(brain.config.volley_count),"five actual projectiles produce exactly five arrow views")
	check(fx.bursts.size()==1,"simultaneous volley shares one bow-release flare")
	runtime.projectiles.clear();presentation.refresh(0.0);fx.clear()
	check(fx.live_arrows.is_empty(),"unsignalled reset cannot leave orphan arrow views")
	runtime.rain_pulsed.connect(func(id,_center,_owner,pulse,last):pulses.append([id,pulse,last]))
	start("rain")
	var rain_id: int=runtime.rains[0].id
	var locked: Vector3=runtime.rains[0].center
	check(fx.live_rains[rain_id].arrows.size()==fx.style.rain_arrow_count,"rain uses the configured visual arrow count")
	for location in fx.live_rains[rain_id].points:
		var offset: Vector3=location-locked;offset.y=0.0
		check(offset.length()<brain.config.rain_radius_m,"rain arrow is contained by the actual locked radius")
	step(brain.config.rain_delay_sec - brain.config.rain_windup_sec - fx.style.rain_fall_sec / 2.0)
	var falling=fx.live_rains[rain_id].arrows[0].view
	check(falling.body.visible and falling.body.global_basis.z.y>0.0,"falling physical arrowhead points downward")
	var warning_mesh=fx.live_rains[rain_id].marker.mesh
	step(fx.style.rain_fall_sec)
	check(fx.live_rains[rain_id].marker.mesh!=warning_mesh,"first damage pulse changes warning circle into active danger ring")
	player.position=Vector3(10,0,-6)
	for i in 100: step(.02)
	check(pulses.size()==int(brain.config.rain_pulses) and pulses.back()[2],"all pulse facts arrive including final pulse removed in the same tick")
	check(runtime.rains.is_empty() and fx.live_rains.is_empty(),"last pulse retires rule area and its warning")
	for i in 100: presentation.refresh(.02)
	check(fx.final_rains.is_empty() and fx.bursts.is_empty() and fx.tails.is_empty(),"all final rain and impact afterglow is bounded")
	player.position=Vector3(0,0,-6)
	start("rain");start("volley")
	runtime.remove_actor(ranger)
	check(fx.live_arrows.is_empty() and fx.live_rains.is_empty() and fx.bursts.is_empty(),"source replacement immediately cleans all owned visual effects")
	runtime.clear()
	check(fx.releases.is_empty(),"room clear resets release deduplication")
	presentation.queue_free();player.queue_free();ranger.queue_free()
	await process_frame
	await process_frame
	print("RANGER_VFX ",JSON.stringify({"checks":checks,"failures":failures,"pulses":pulses.size()}))
	quit(0 if failures.is_empty() else 1)
