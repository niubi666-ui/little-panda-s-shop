extends Node3D
## Replace this adapter and its scenes when final models/animations arrive.
## It only reads confirmed runtime state; it never schedules damage.
const TESSELLATION_SEGMENTS := 32
const HitFeedback = preload("res://presentation/combat/hit_feedback.gd")
const AttackMotion = preload("res://presentation/combat/attack_motion.gd")
var actor
var style
var actor_style
var visual: Node3D
var animation: AnimationPlayer
var sector: MeshInstance3D
var blade_pivot: Node3D
var label: Label3D
var hit_feedback: HitFeedback
var blade: Node3D
var weapon_effect: Node3D
var _visual_rest_basis := Basis.IDENTITY
func configure(owner_actor, settings, font: Font) -> void:
	actor = owner_actor
	style = settings
	actor_style = style.actor_presentations[actor.definition.id]
	if actor.team == 0:
		for key in style.attack_motions:
			assert(style.weapon_tip_radius_by_ability.has(key), "Missing sword presentation radius: " + key)
			assert(style.weapon_tip_radius_by_ability[key] > style.blade_size.z / 2.0, "Sword presentation radius must contain half the blade")
			var motion: AttackMotion = style.attack_motions[key]
			motion.validate()
			assert(style.weapon_tip_radius_by_ability[key] - motion.extension_distance - motion.pullback_distance > style.blade_size.z / 2.0, "Sword pullback must leave its midpoint in front of the actor")
	visual = actor_style.visual_scene.instantiate()
	_visual_rest_basis = visual.basis
	add_child(visual)
	animation = visual.find_child("AnimationPlayer", true, false)
	if animation != null:
		for library_name in animation.get_animation_library_list():
			var library: AnimationLibrary = animation.get_animation_library(library_name).duplicate(true)
			for animation_name in library.get_animation_list():
				library.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			animation.remove_animation_library(library_name)
			animation.add_animation_library(library_name, library)
	blade_pivot = Node3D.new()
	add_child(blade_pivot)
	assert(style.weapon_visual_scene != null)
	blade = Node3D.new()
	var sword_visual: Node3D = style.weapon_visual_scene.instantiate()
	# Source model has a unit-length blade along -Z; keep VFX midpoint unscaled.
	sword_visual.scale = Vector3.ONE * style.blade_size.z
	blade.add_child(sword_visual)
	blade.position = style.blade_offset
	blade_pivot.add_child(blade)
	if actor.team == 0: set_weapon_effect(style.weapon_effect_scene)
	sector = MeshInstance3D.new()
	sector.position.y = style.sector_height
	sector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sector)
	label = Label3D.new()
	label.position.y = style.health_label_height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = font
	label.font_size = style.health_font_size
	label.pixel_size = style.health_label_pixel_size
	add_child(label)
	if actor.team != 0:
		label.hide()
		hit_feedback = HitFeedback.new()
		add_child(hit_feedback)
		hit_feedback.configure(actor, visual, style.hit_feedback, actor_style.body_height)
## Build presentation adapters can swap this scene; physics never reads it.
func set_weapon_effect(scene: PackedScene) -> void:
	if is_instance_valid(weapon_effect):
		weapon_effect.get_parent().remove_child(weapon_effect)
		weapon_effect.queue_free()
	weapon_effect = null
	# Explicitly empty Resource slots disable VFX without changing the attack.
	if scene == null: return
	weapon_effect = scene.instantiate()
	assert(weapon_effect.has_method("set_active") and weapon_effect.has_method("set_time_running"))
	blade.add_child(weapon_effect)
	if weapon_effect.has_method("configure_blade"):
		weapon_effect.configure_blade(style.blade_size.z)
	weapon_effect.set_active(false)
func refresh(delta: float = 0.0) -> void:
	if hit_feedback != null: hit_feedback.tick(delta)
	var custom_animation := visual.has_method("refresh_actor")
	if custom_animation: visual.refresh_actor(actor, delta)
	# Death can hide the actor before the remaining VFX tails have expired.
	# Freeze their clocks on pause even when this view takes an early return.
	if is_instance_valid(weapon_effect): weapon_effect.set_time_running(delta > 0.0)
	if not actor.health.alive():
		_finish_weapon_pose()
		_pose_visual(atan2(-actor.facing.x, -actor.facing.z), Vector3.ZERO)
	visible = actor.health.alive() or (hit_feedback != null and hit_feedback.has_tail())
	if custom_animation and visual.has_presentation_tail(): visible = true
	if not visible: return
	if not actor.health.alive():
		blade_pivot.hide()
		sector.hide()
		return
	label.text = "%s / %s" % [ceili(actor.health.current), ceili(actor.health.maximum)]
	var phase: String = actor.runner.phase()
	# End the stroke at its last sword pose before recovery or a cancellation.
	if phase != "active": _finish_weapon_pose()
	var direction: Vector3 = actor.runner.direction if actor.runner.busy() else actor.facing
	var yaw := atan2(-direction.x, -direction.z)
	_pose_visual(yaw, Vector3.ZERO)
	blade_pivot.rotation.y = yaw
	if animation != null and not custom_animation:
		animation.speed_scale = 1.0 if delta > 0.0 else 0.0
		var action: StringName = actor_style.move_animation if actor.velocity.length_squared() > 0.0 else actor_style.idle_animation
		if animation.has_animation(action) and animation.current_animation != action:
			animation.play(action, style.animation_blend_sec)
	sector.visible = actor.team != 0 and (phase == "windup" or phase == "active")
	var trail_enabled := true
	if actor.team == 0:
		# Preserve the approved sword/VFX placement when gameplay reach is tuned.
		# Gameplay never reads this presentation radius or the selected effect.
		var key := _motion_key()
		var reach: float = style.weapon_tip_radius_by_ability[key]
		var motion: AttackMotion = style.attack_motions[key]
		var pose := motion.sample_pose(phase, _phase_progress(phase))
		blade.position = Vector3(pose.lateral_offset, style.blade_offset.y + pose.grip_height_offset, -(reach - pose.tip_retreat - style.blade_size.z / 2.0))
		blade.rotation.x = deg_to_rad(pose.pitch_deg)
		blade_pivot.rotation.y += deg_to_rad(pose.yaw_deg)
		_pose_visual(yaw, pose.body_degrees)
		trail_enabled = motion.trail_enabled
	if actor.runner.busy():
		var ability = actor.runner.ability
		if actor.team != 0:
			var progress := clampf((actor.runner.elapsed - ability.windup) / ability.active, 0.0, 1.0)
			blade_pivot.rotation.y += lerpf(-ability.angle / 2.0, ability.angle / 2.0, progress)
		sector.rotation.y = yaw
		if sector.visible:
			var tint: Color = style.warning_color if phase == "windup" else style.strike_color
			_draw_sector(ability.radius, ability.angle, tint)
	if is_instance_valid(weapon_effect):
		weapon_effect.set_active(phase == "active" and trail_enabled)
		if weapon_effect.has_method("sample_current_pose"):
			weapon_effect.sample_current_pose()
	blade_pivot.visible = actor.team == 0 or actor.runner.busy()
func _motion_key() -> String:
	if not actor.runner.busy(): return actor.attacks[0].id
	var key: String = actor.runner.presentation_key
	if style.attack_motion_groups.has(key):
		assert(style.attack_motion_groups[key].has(actor.runner.ability.id), "Missing ability in sword motion group: " + key)
		key = style.attack_motion_groups[key][actor.runner.ability.id]
	assert(style.attack_motions.has(key), "Missing configured sword motion: " + key)
	return key
func _phase_progress(phase: String) -> float:
	if phase == "idle": return 0.0
	var ability = actor.runner.ability
	match phase:
		"windup": return clampf(actor.runner.elapsed / ability.windup, 0.0, 1.0)
		"active": return clampf((actor.runner.elapsed - ability.windup) / ability.active, 0.0, 1.0)
		"recovery": return clampf((actor.runner.elapsed - ability.windup - ability.active) / ability.recovery, 0.0, 1.0)
	return 0.0
func _pose_visual(yaw: float, body_degrees: Vector3) -> void:
	# Lean in the actor's facing space, ahead of the model's authored yaw offset.
	# Rebuild from its original basis each sample; never accumulate rotations.
	visual.basis = Basis(Vector3.UP, yaw) * Basis.from_euler(body_degrees * (PI / 180.0)) * Basis(Vector3.UP, deg_to_rad(actor_style.visual_yaw_offset_deg)) * _visual_rest_basis
func _finish_weapon_pose() -> void:
	if is_instance_valid(weapon_effect) and weapon_effect.has_method("finish_at_current_pose"):
		weapon_effect.finish_at_current_pose()
	elif is_instance_valid(weapon_effect):
		weapon_effect.set_active(false)
func _draw_sector(radius: float, angle: float, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for i in TESSELLATION_SEGMENTS:
		var a := -angle / 2.0 + angle * float(i) / TESSELLATION_SEGMENTS
		var b := -angle / 2.0 + angle * float(i + 1) / TESSELLATION_SEGMENTS
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(a), 0, -cos(a)) * radius)
		mesh.surface_add_vertex(Vector3(sin(b), 0, -cos(b)) * radius)
	mesh.surface_end()
	sector.mesh = mesh
