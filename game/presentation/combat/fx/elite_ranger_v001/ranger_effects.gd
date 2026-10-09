extends Node3D
## Local presentation consumer. No AI, damage calls, collision nodes or gameplay RNG.
const Flight = preload("res://presentation/combat/fx/elite_ranger_v001/arrow_flight.gd")
const Rain = preload("res://presentation/combat/fx/elite_ranger_v001/rain_view.gd")
const Burst = preload("res://presentation/combat/fx/elite_ranger_v001/ranger_burst.gd")
const EPSILON := 0.000001
const Charged=preload("res://presentation/combat/fx/charged_arrow_v001/charged_effects.gd")
var charged_fx
var runtime
var style
var profile
var geometry
var enabled := true
var live_arrows: Dictionary = {}
var live_rains: Dictionary = {}
var tails: Array = []
var final_rains: Array = []
var bursts: Array = []
var releases: Dictionary = {}

func configure(value, actor_style, factory, camera: Camera3D=null, surfaces: Array=[]) -> void:
	runtime = value
	style = actor_style
	profile = style.skill_vfx_profile
	geometry = factory
	charged_fx=Charged.new();add_child(charged_fx);charged_fx.configure(runtime,camera,surfaces)
	assert(profile != null and profile.valid(),"Ranger VFX requires a complete presentation Resource")
	runtime.projectile_spawned.connect(_arrow_started)
	runtime.projectile_finished.connect(_arrow_finished)
	runtime.rain_started.connect(_rain_started)
	runtime.rain_pulsed.connect(_rain_pulsed)
	runtime.actor_attacks_removed.connect(remove_actor)
	runtime.attacks_cleared.connect(clear)

func set_enabled(value: bool) -> void:
	enabled = value
	charged_fx.set_enabled(value)
	if not enabled: clear()

func _visual_position(projectile: Dictionary) -> Vector3:
	var blend_distance := minf(style.arrow_launch_blend_distance_m,float(projectile.config.aim_distance_m)/2.0)
	var blend := clampf(projectile.position.distance_to(projectile.start_position)/maxf(blend_distance,EPSILON),0.0,1.0)
	return projectile.position+projectile.visual_launch_offset*(1.0-blend)

func _arrow_started(projectile: Dictionary) -> void:
	if not enabled or not projectile.config.get("ranger_arrow",false): return
	if projectile.config.get("charged",false):return
	var arrow := Flight.new()
	add_child(arrow)
	arrow.configure(profile,style,projectile.source.handle,profile.visual_seed+projectile.id,true)
	if projectile.config.get("charged", false):
		arrow.width_ratio = style.charged_trail_ratio
		arrow.tip_ratio = style.charged_trail_ratio
	arrow.sample(_visual_position(projectile),projectile.direction,0.0)
	live_arrows[projectile.id] = {"view":arrow,"projectile":projectile}
	var key: String = projectile.config.volley_id
	if not releases.has(key):
		releases[key] = projectile.source.handle
		var origin: Vector3 = projectile.start_position+projectile.visual_launch_offset
		_burst(PackedVector3Array([origin]),origin,projectile.direction,projectile.source.handle,profile.visual_seed+projectile.id,profile.launch_burst,0.0)

func _arrow_finished(id: int, point: Vector3, direction: Vector3, owner: int, reason: String) -> void:
	if not live_arrows.has(id): return
	var arrow = live_arrows[id].view
	if reason == "cancelled":
		_dispose(arrow)
	else:
		arrow.finish(point,direction)
		tails.append(arrow)
		if reason in ["hit","world"]:
			_burst(PackedVector3Array([point]),point,direction,owner,profile.visual_seed+id,profile.arrow_impact,0.0)
	live_arrows.erase(id)

func _rain_started(value: Dictionary) -> void:
	if not enabled: return
	var view := Rain.new()
	add_child(view)
	view.configure(value,profile,style,geometry)
	live_rains[value.id] = view
	_burst(PackedVector3Array([value.launch]),value.launch,Vector3.UP,value.source.handle,profile.visual_seed+value.id,profile.launch_burst,0.0)

func _rain_pulsed(id: int, _center: Vector3, owner: int, pulse: int, last: bool) -> void:
	if not live_rains.has(id): return
	var view = live_rains[id]
	view.commit_pulse(last)
	_burst(view.points,view.rain.center,Vector3.DOWN,owner,profile.visual_seed+id+pulse,profile.rain_impact,float(view.rain.config.rain_radius_m))
	if last:
		final_rains.append(view)
		live_rains.erase(id)

func _burst(points: PackedVector3Array, center: Vector3, direction: Vector3, owner: int, seed: int, settings, radius: float) -> void:
	var burst := Burst.new()
	add_child(burst)
	burst.configure(settings,points,center,direction,owner,seed,radius)
	bursts.append(burst)

func refresh(delta: float) -> void:
	charged_fx.refresh(delta)
	var live: Dictionary = {}
	var active_releases: Dictionary = {}
	for projectile in runtime.projectiles:
		if not projectile.config.get("ranger_arrow",false): continue
		if projectile.config.get("charged",false):continue
		live[projectile.id]=true
		active_releases[projectile.config.volley_id]=true
		if enabled and not live_arrows.has(projectile.id): _arrow_started(projectile)
		if live_arrows.has(projectile.id): live_arrows[projectile.id].view.sample(_visual_position(projectile),projectile.direction,delta)
	# Missing without a finish fact means cancellation, replacement or direct test reset.
	for id in live_arrows.keys():
		if not live.has(id):
			_dispose(live_arrows[id].view)
			live_arrows.erase(id)
	for key in releases.keys():
		if not active_releases.has(key): releases.erase(key)
	var rain_ids: Dictionary = {}
	for rain in runtime.rains:
		rain_ids[rain.id]=true
		if enabled and not live_rains.has(rain.id): _rain_started(rain)
		if live_rains.has(rain.id): live_rains[rain.id].sample(delta)
	for id in live_rains.keys():
		if not rain_ids.has(id):
			_dispose(live_rains[id])
			live_rains.erase(id)
	for array in [tails,final_rains]:
		for i in range(array.size()-1,-1,-1):
			if array[i].fade(delta):
				_dispose(array[i])
				array.remove_at(i)
	for i in range(bursts.size()-1,-1,-1):
		if bursts[i].step(delta):
			_dispose(bursts[i])
			bursts.remove_at(i)

func _dispose(node: Node3D) -> void:
	node.hide()
	node.queue_free()

func remove_actor(handle: int) -> void:
	charged_fx.remove_actor(handle)
	for id in live_arrows.keys():
		if live_arrows[id].view.owner_handle==handle:
			_dispose(live_arrows[id].view)
			live_arrows.erase(id)
	for id in live_rains.keys():
		if live_rains[id].owner_handle==handle:
			_dispose(live_rains[id])
			live_rains.erase(id)
	for array in [tails,final_rains,bursts]:
		for i in range(array.size()-1,-1,-1):
			if array[i].owner_handle==handle:
				_dispose(array[i]);array.remove_at(i)
	for key in releases.keys():
		if releases[key]==handle: releases.erase(key)

func clear() -> void:
	if charged_fx!=null:charged_fx.clear()
	for entry in live_arrows.values(): _dispose(entry.view)
	for node in live_rains.values(): _dispose(node)
	for array in [tails,final_rains,bursts]:
		for node in array: _dispose(node)
		array.clear()
	live_arrows.clear()
	live_rains.clear()
	releases.clear()

func _exit_tree() -> void:
	if runtime == null: return
	for binding in [[runtime.projectile_spawned,_arrow_started],[runtime.projectile_finished,_arrow_finished],[runtime.rain_started,_rain_started],[runtime.rain_pulsed,_rain_pulsed],[runtime.actor_attacks_removed,remove_actor],[runtime.attacks_cleared,clear]]:
		if binding[0].is_connected(binding[1]): binding[0].disconnect(binding[1])
