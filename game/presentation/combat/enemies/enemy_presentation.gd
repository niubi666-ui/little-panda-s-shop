extends Node3D
## Reads role state only; visuals cannot schedule damage or modify AI decisions.
const FX = preload("res://presentation/combat/enemies/enemy_fx_style.tres")
const RING_SEGMENTS := 64
const RangerWarning = preload("res://presentation/combat/enemies/ranger_warning.gd")
const RangerStyle = preload("res://presentation/combat/enemies/ranger_style.tres")
const RangerEffects = preload("res://presentation/combat/fx/elite_ranger_v001/ranger_effects.gd")
const RollAfterimage = preload("res://presentation/combat/fx/elite_ranger_v001/roll_afterimage.gd")
var runtime
var style
var entries: Array = []
var balls: Dictionary = {}
var ranger_vfx: Node3D
func configure(enemy_runtime, actor_style, camera: Camera3D=null, surfaces: Array=[]) -> void:
	runtime = enemy_runtime
	style = actor_style
	ranger_vfx = RangerEffects.new()
	add_child(ranger_vfx)
	ranger_vfx.configure(runtime,RangerStyle,self,camera,surfaces)
func mesh_node(parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
func register(brain, view, profile: Dictionary) -> void:
	var root := RangerWarning.new() if profile.role == "ranger" else Node3D.new()
	add_child(root)
	var afterimage
	if profile.role == "ranger":
		root.external_charged_cue=true
		root.configure(brain, self)
		view.visual.bind_brain(brain)
		afterimage=RollAfterimage.new();root.add_child(afterimage)
		afterimage.configure(view.visual.afterimage_source(),RangerStyle.roll_afterimage_profile)
		view.hit_feedback.bar.position.y = RangerStyle.health_bar_height
		view.hit_feedback.bar.mesh.size = RangerStyle.health_bar_size
	elif profile.role != "melee" and view.visual.has_method("bind_brain"):
		# 通用骨骼表现：按 AI 状态（前摇/冲锋/支援等）选动作
		view.visual.bind_brain(brain)
	var warning := mesh_node(root)
	# 每个敌人一份预警材质：前摇进度驱动“填满即出手”
	var warning_material: ShaderMaterial = null
	if profile.role == "ranged":
		warning_material = material(FX.ranged_lane_material, FX.line_color)
		warning.mesh = strip(profile.config.fire_range_m, FX.line_width, warning_material)
	elif profile.role == "charger":
		warning_material = material(FX.charge_lane_material, FX.charge_color)
		warning.mesh = strip(profile.config.charge_distance_m, profile.config.hit_radius_m * 2.0, warning_material)
	var aura := mesh_node(root)
	var buff := mesh_node(root)
	var weapon: MeshInstance3D = view.visual.find_child("Weapon", true, false)
	var original: Material = weapon.get_active_material(0) if weapon != null else null
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color.WHITE
	flash.emission_enabled = true
	flash.emission = Color.WHITE
	flash.emission_energy_multiplier = FX.white_emission
	entries.append({"brain":brain,"view":view,"profile":profile,"root":root,"warning":warning,"aura":aura,"buff":buff,"weapon":weapon,"original":original,"flash":flash,"weapon_rest":weapon.position if weapon != null else Vector3.ZERO,"afterimage":afterimage,"warning_material":warning_material})
func refresh(delta: float = 0.0) -> void:
	for entry in entries:
		var actor = entry.brain.actor
		entry.root.visible = actor.health.alive()
		if entry.afterimage!=null:entry.afterimage.refresh(0.0 if actor.control_locked else delta,entry.brain.state=="rolling",actor.health.alive())
		if not actor.health.alive(): continue
		entry.root.global_position = actor.global_position
		entry.root.position.y += FX.ground_height
		var role: String = entry.profile.role
		if role == "ranger": entry.root.refresh(delta)
		var special := role != "melee"
		if special:
			entry.view.blade_pivot.hide()
			entry.view.sector.hide()
		var warning: bool = special and entry.brain.state == "windup"
		entry.warning.visible = warning and role != "ranger"
		if warning:
			entry.warning.rotation.y = atan2(-entry.brain.locked_direction.x, -entry.brain.locked_direction.z)
			if entry.warning_material != null and entry.brain.windup_duration > 0.0:
				entry.warning_material.set_shader_parameter("fill", 1.0 - clampf(entry.brain.time_left / entry.brain.windup_duration, 0.0, 1.0))
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
		if projectile.config.get("ranger_arrow", false): continue
		live[projectile.id] = true
		if not balls.has(projectile.id):
			var ball := mesh_node(self)
			var sphere := SphereMesh.new()
			sphere.radius = projectile.config.projectile_radius_m
			sphere.height = sphere.radius * 2.0
			var material := StandardMaterial3D.new()
			material.albedo_color = FX.projectile_color
			material.emission_enabled = true
			material.emission = material.albedo_color
			material.emission_energy_multiplier = FX.projectile_emission
			sphere.material = material
			ball.mesh = sphere
			balls[projectile.id] = ball
		balls[projectile.id].global_position = projectile.position
		balls[projectile.id].basis = Basis.looking_at(projectile.direction, Vector3.UP)
	for id in balls.keys():
		if not live.has(id):
			balls[id].queue_free()
			balls.erase(id)
	ranger_vfx.refresh(delta)

func remove_actor(actor) -> void:
	ranger_vfx.remove_actor(actor.handle)
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].brain.actor == actor:
			entries[i].root.queue_free()
			entries.remove_at(i)
func remove_dead() -> void:
	for index in range(entries.size() - 1, -1, -1):
		if not entries[index].brain.actor.health.alive():
			ranger_vfx.remove_actor(entries[index].brain.actor.handle)
			entries[index].root.queue_free()
			entries.remove_at(index)
## 预警材质：复制 FX 里配置的模板（柔边 + 描边 + 可填充进度，见 fx/telegraph.gdshader），再填颜色。
func material(template: ShaderMaterial, color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = template.duplicate()
	mat.set_shader_parameter("color", color)
	return mat
## UV.x 横向 0..1，UV.y 沿长度 0..1。
func strip(length: float, width: float, mat: ShaderMaterial) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var a := Vector3(-width / 2.0, 0, 0)
	var b := Vector3(width / 2.0, 0, 0)
	var c := Vector3(width / 2.0, 0, -length)
	var d := Vector3(-width / 2.0, 0, -length)
	var uv := {a: Vector2(0, 0), b: Vector2(1, 0), c: Vector2(1, 1), d: Vector2(0, 1)}
	for point in [a,b,c,a,c,d]:
		mesh.surface_set_uv(uv[point])
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh
func ring(radius: float, width: float, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material(FX.ring_material, color))
	# 细环画宽一些再靠柔边收窄，远看不会碎成锯齿
	var band := maxf(width * FX.ring_band_scale, FX.ring_min_band_m)
	for i in RING_SEGMENTS:
		var a := Vector3(cos(TAU * i / RING_SEGMENTS), 0, sin(TAU * i / RING_SEGMENTS))
		var b := Vector3(cos(TAU * (i + 1) / RING_SEGMENTS), 0, sin(TAU * (i + 1) / RING_SEGMENTS))
		var points := [a*radius,b*radius,b*(radius-band),a*radius,b*(radius-band),a*(radius-band)]
		var uvs := [Vector2(0, 0.5), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 0.5)]
		for index in points.size():
			mesh.surface_set_uv(uvs[index])
			mesh.surface_add_vertex(points[index])
	mesh.surface_end()
	return mesh
func clear() -> void:
	for entry in entries: entry.root.queue_free()
	entries.clear()
	for ball in balls.values(): ball.queue_free()
	balls.clear()
	if ranger_vfx != null: ranger_vfx.clear()
