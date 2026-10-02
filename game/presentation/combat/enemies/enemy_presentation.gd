extends Node3D
## Reads role state only; visuals cannot schedule damage or modify AI decisions.
const FX = preload("res://presentation/combat/enemies/enemy_fx_style.tres")
const RING_SEGMENTS := 64
var runtime
var style
var entries: Array = []
var balls: Dictionary = {}
func configure(enemy_runtime, actor_style) -> void:
	runtime = enemy_runtime
	style = actor_style
func mesh_node(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
func register(brain, view, profile: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	var warning := mesh_node(root)
	if profile.role == "ranged": warning.mesh = strip(profile.config.fire_range_m, FX.line_width, FX.line_color)
	elif profile.role == "charger": warning.mesh = strip(profile.config.charge_distance_m, profile.config.hit_radius_m * 2.0, FX.charge_color)
	var aura := mesh_node(root)
	var buff := mesh_node(root)
	var weapon: MeshInstance3D = view.visual.find_child("Weapon", true, false)
	var original: Material = weapon.get_active_material(0) if weapon != null else null
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color.WHITE
	flash.emission_enabled = true
	flash.emission = Color.WHITE
	flash.emission_energy_multiplier = FX.white_emission
	entries.append({"brain":brain,"view":view,"profile":profile,"root":root,"warning":warning,"aura":aura,"buff":buff,"weapon":weapon,"original":original,"flash":flash,"weapon_rest":weapon.position if weapon != null else Vector3.ZERO})
func refresh() -> void:
	for entry in entries:
		var actor = entry.brain.actor
		entry.root.visible = actor.health.alive()
		if not actor.health.alive(): continue
		entry.root.global_position = actor.global_position
		entry.root.position.y += FX.ground_height
		var role: String = entry.profile.role
		var special := role != "melee"
		if special:
			entry.view.blade_pivot.hide()
			entry.view.sector.hide()
		var warning: bool = special and entry.brain.state == "windup"
		entry.warning.visible = warning
		if warning:
			entry.warning.rotation.y = atan2(-entry.brain.locked_direction.x, -entry.brain.locked_direction.z)
		if entry.weapon != null:
			entry.weapon.material_override = entry.flash if warning else entry.original
			entry.weapon.position = entry.weapon_rest
			if warning and role == "charger": entry.weapon.position += Vector3.BACK * FX.spear_pullback_m * (1.0 - entry.brain.time_left / entry.brain.windup_duration)
		entry.aura.visible = role == "support"
		if role == "support" and entry.aura.mesh == null: entry.aura.mesh = ring(entry.profile.config.aura_radius_m, FX.aura_width, FX.aura_color)
		entry.buff.visible = actor.aura_active
		if actor.aura_active and entry.buff.mesh == null: entry.buff.mesh = ring(style.actor_presentations[actor.definition.id].body_shape.radius * FX.recipient_radius_scale, FX.aura_width, FX.aura_color)
	var live: Dictionary = {}
	for projectile in runtime.projectiles:
		live[projectile.id] = true
		if not balls.has(projectile.id):
			var ball := mesh_node(self)
			var sphere := SphereMesh.new()
			sphere.radius = projectile.config.projectile_radius_m
			sphere.height = sphere.radius * 2.0
			var material := StandardMaterial3D.new()
			material.albedo_color = FX.projectile_color
			material.emission_enabled = true
			material.emission = FX.projectile_color
			material.emission_energy_multiplier = FX.projectile_emission
			sphere.material = material
			ball.mesh = sphere
			balls[projectile.id] = ball
		balls[projectile.id].global_position = projectile.position
	for id in balls.keys():
		if not live.has(id):
			balls[id].queue_free()
			balls.erase(id)
func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat
func strip(length: float, width: float, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material(color))
	var a := Vector3(-width / 2.0, 0, 0)
	var b := Vector3(width / 2.0, 0, 0)
	var c := Vector3(width / 2.0, 0, -length)
	var d := Vector3(-width / 2.0, 0, -length)
	for point in [a,b,c,a,c,d]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh
func ring(radius: float, width: float, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material(color))
	for i in RING_SEGMENTS:
		var a := Vector3(cos(TAU * i / RING_SEGMENTS), 0, sin(TAU * i / RING_SEGMENTS))
		var b := Vector3(cos(TAU * (i + 1) / RING_SEGMENTS), 0, sin(TAU * (i + 1) / RING_SEGMENTS))
		for point in [a*radius,b*radius,b*(radius-width),a*radius,b*(radius-width),a*(radius-width)]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh
func clear() -> void:
	for entry in entries: entry.root.queue_free()
	entries.clear()
	for ball in balls.values(): ball.queue_free()
	balls.clear()
