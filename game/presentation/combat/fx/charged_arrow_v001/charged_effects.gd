extends Node3D
const Cast=preload("res://presentation/combat/fx/charged_arrow_v001/cast_view.gd")
const Cuts=preload("res://presentation/combat/fx/charged_arrow_v001/surface_cuts.gd")
const Art=preload("res://presentation/combat/fx/charged_arrow_v001/profile.tres")
var runtime
var camera: Camera3D
var cuts
var casts: Dictionary={}
var enabled:=true
func configure(value, view_camera: Camera3D, surfaces: Array) -> void:
	runtime=value;camera=view_camera
	if camera==null:
		camera=Camera3D.new();add_child(camera)
	cuts=Cuts.new();add_child(cuts);cuts.configure(surfaces,Art.rift_station_count)
	runtime.charged_rifts.started.connect(_started)
	runtime.charged_rifts.pulsed.connect(_pulsed)
	runtime.actor_attacks_removed.connect(remove_actor)
	runtime.attacks_cleared.connect(clear)
func _ensure(key: String, brain):
	if not casts.has(key):
		var view:=Cast.new();add_child(view);view.configure(brain,camera,cuts.token());casts[key]=view
	return casts[key]
func _started(area: Dictionary) -> void:
	if not enabled:return
	for brain in runtime.brains:
		if brain.actor==area.source:
			_ensure(area.projectile.config.volley_id,brain).commit(area)
			return
func _pulsed(area: Dictionary, applied: float, point: Vector3) -> void:
	var key: String=area.projectile.config.volley_id
	if not enabled or applied<=0.0 or not casts.has(key):return
	var state=casts[key].state
	state.target=point
	state.damaged.emit("scar",applied,state.fire_time+area.age)
func refresh(delta: float) -> void:
	if not enabled:return
	for brain in runtime.brains:
		if brain.get("attack_id")=="charged" and brain.state=="windup":
			_ensure(str(brain.actor.handle)+":"+str(brain.cast_id),brain)
	var live: Dictionary={}
	for area in runtime.charged_rifts.items:
		var key: String=area.projectile.config.volley_id
		live[key]=true
		if not casts.has(key):_started(area)
	for key in casts.keys():
		if casts[key].sample(delta,live.has(key)):_remove(key)
	cuts.flush()
func _remove(key: String) -> void:
	var view=casts[key]
	view.effect.set_enabled(false);view.hide();view.queue_free();casts.erase(key)
func remove_actor(handle: int) -> void:
	for key in casts.keys():
		if casts[key].owner_handle==handle:_remove(key)
func clear() -> void:
	for key in casts.keys():_remove(key)
func set_enabled(value: bool) -> void:
	enabled=value
	if not enabled:clear()
func _exit_tree() -> void:
	for pair in [[runtime.charged_rifts.started,_started],[runtime.charged_rifts.pulsed,_pulsed],[runtime.actor_attacks_removed,remove_actor],[runtime.attacks_cleared,clear]]:
		if pair[0].is_connected(pair[1]):pair[0].disconnect(pair[1])
