extends Node3D
const Style = preload("res://presentation/combat/enemies/ranger_style.tres")
var brain
var geometry
var lines: Array[MeshInstance3D] = []
var ring: MeshInstance3D
var strips: Dictionary = {}
func configure(value, factory) -> void:
	brain = value
	geometry = factory
	for attack in ["fast", "volley"]:
		strips[attack] = geometry.strip(brain.config[attack + "_speed_mps"] * brain.config.arrow_lifetime_sec, brain.config.arrow_radius_m * 2.0, Style.warning_color)
	for i in int(brain.config.volley_count): lines.append(geometry.mesh_node(self))
	ring = geometry.mesh_node(self)
	ring.mesh = geometry.ring(brain.config.rain_radius_m, Style.line_width, Style.warning_color)
func refresh() -> void:
	var active: bool = brain.actor.health.alive() and brain.state == "windup"
	ring.visible = active and brain.attack_id == "rain"
	if ring.visible: ring.global_position = brain.target_point + Vector3.UP * Style.ground_height
	var count := int(brain.config.volley_count) if brain.attack_id == "volley" else 1
	for i in lines.size():
		lines[i].visible = active and brain.attack_id != "rain" and i < count
		if not lines[i].visible: continue
		lines[i].mesh = strips[brain.attack_id]
		var spread := deg_to_rad(brain.config.volley_angle_deg) * (float(i) / (count - 1) - 0.5) if count > 1 else 0.0
		lines[i].rotation.y = atan2(-brain.locked_direction.x, -brain.locked_direction.z) + spread
