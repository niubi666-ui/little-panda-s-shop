extends Node3D
## Adapts authoritative brain/projectile/area state to the approved art renderer.
const Effect=preload("res://presentation/combat/fx/charged_arrow_v001/lightseeker.gd")
const Art=preload("res://presentation/combat/fx/charged_arrow_v001/profile.tres")
class State extends RefCounted:
	signal released
	signal damaged(kind: String, amount: float, timestamp: float)
	var config: Dictionary
	var clock:=0.0
	var fire_time:=-1.0
	var locked:=false
	var origin:=Vector3.ZERO
	var direction:=Vector3.FORWARD
	var target:=Vector3.ZERO
	var ground_height:=0.0
	var distance_m:=0.0
	var flight_finished:=false
	var flight_end_age:=0.0
	func travelled() -> float:return distance_m
var state:=State.new()
var effect
var brain
var cast_id: int
var owner_handle: int
var area: Dictionary={}
var token
var contacted:=false
func configure(value, camera: Camera3D, floor_token) -> void:
	brain=value;cast_id=brain.cast_id;owner_handle=brain.actor.handle;token=floor_token
	var c: Dictionary=brain.config
	state.config={"skill":{"range_m":c.charged_range_m,"charge_sec":c.charged_windup_sec,"speed_mps":c.charged_speed_mps,"arrow_radius_m":c.arrow_radius_m,"trail_half_width_m":c.charged_rift_half_width_m,"trail_duration_sec":c.charged_rift_duration_sec,"trail_tick_sec":c.charged_rift_interval_sec}}
	state.flight_end_age=c.charged_range_m/c.charged_speed_mps
	_sample_charge()
	effect=Effect.new();add_child(effect)
	effect.configure(Art,state,camera,token)
func _sample_charge() -> void:
	state.ground_height=brain.actor.global_position.y
	state.origin=brain.actor.global_position+Vector3.UP*brain.config.arrow_height_m+brain.locked_direction*minf(brain.config.arrow_spawn_forward_m,brain.locked_distance/2.0)
	state.direction=brain.locked_direction
	state.clock=brain.config.charged_windup_sec-brain.time_left
	state.locked=brain.time_left<=brain.config.charged_lock_sec
func commit(value: Dictionary) -> void:
	area=value
	state.fire_time=state.config.skill.charge_sec
	state.clock=state.fire_time
	state.direction=area.direction
	state.ground_height=area.origin.y
	state.origin=area.projectile.start_position+area.projectile.visual_launch_offset
	state.released.emit()
func sample(delta: float, live: bool) -> bool:
	if area.is_empty():
		if not is_instance_valid(brain.actor) or not brain.actor.health.alive() or brain.state!="windup" or brain.attack_id!="charged" or brain.cast_id!=cast_id:return true
		_sample_charge()
	else:
		if live:state.clock=state.fire_time+area.age
		else:state.clock+=delta
		state.distance_m=area.length
		state.flight_end_age=area.length/area.projectile.config.projectile_speed_mps
		state.flight_finished=area.projectile.finished
		if area.projectile.contact and not contacted:
			contacted=true;state.target=brain.target.global_position;state.damaged.emit("arrow",0.0,state.clock)
		if state.clock-state.fire_time>=state.config.skill.trail_duration_sec+Art.trail_fade_sec:return true
	effect.pause_audio(delta<=0.0)
	effect.refresh()
	return false
func _exit_tree() -> void:
	if is_instance_valid(token):token.queue_free()
