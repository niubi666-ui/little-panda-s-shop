extends Node3D
## Local health subscriber. Uses the actor view's clock (including pause), never gameplay RNG.
var settings: Resource
var _actor: Node3D
var _font: Font
var _height: float
var _sequence := 0
var _entries: Array[Dictionary] = []

func configure(owner_actor: Node3D, profile: Resource, font: Font, body_height: float) -> void:
	settings = profile
	assert(settings.lifetime_sec > 0.0 and settings.max_visible_per_actor > 0)
	assert(settings.fade_start_ratio >= 0.0 and settings.fade_start_ratio < 1.0)
	assert(settings.pop_end_ratio > 0.0 and settings.pop_end_ratio <= 1.0)
	_actor = owner_actor
	_font = settings.font_override if settings.font_override != null else font
	_height = maxf(body_height, settings.minimum_height) + settings.height_offset
	# Keep old numbers at the hit location as the actor moves/rolls/gets knocked back.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_actor.health.damaged.connect(_on_damage)

func _on_damage(amount: float) -> void:
	if amount <= 0.0: return
	if _entries.size() >= settings.max_visible_per_actor:
		var oldest: Dictionary = _entries.pop_front()
		oldest.label.free()
	var label := Label3D.new()
	label.text = String.num(amount, settings.decimal_places)
	if label.text.contains("."):
		label.text = label.text.rstrip("0").trim_suffix(".")
	label.font = _font
	label.font_size = settings.font_size
	label.pixel_size = settings.pixel_size
	label.outline_size = settings.outline_size
	label.outline_modulate = settings.outline_color
	label.modulate = settings.player_color if _actor.team == 0 else settings.enemy_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	# Alternate screen sides without touching any gameplay random stream.
	var lane := (_sequence % 3) - 1
	_sequence += 1
	var origin: Vector3 = _actor.global_position + Vector3.UP * _height + right * lane * settings.spread_m
	label.position = origin
	label.scale = Vector3.ONE * settings.pop_scale
	_entries.append({"label": label, "age": 0.0, "origin": origin})

func tick(delta: float) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		var entry := _entries[i]
		entry.age += delta
		if entry.age >= settings.lifetime_sec:
			entry.label.free()
			_entries.remove_at(i)
			continue
		var progress: float = entry.age / settings.lifetime_sec
		var label: Label3D = entry.label
		label.position = entry.origin + Vector3.UP * settings.rise_m * (1.0 - pow(1.0 - progress, 2.0))
		label.scale = Vector3.ONE * lerpf(settings.pop_scale, 1.0, minf(progress / settings.pop_end_ratio, 1.0))
		var alpha := 1.0 - clampf((progress - settings.fade_start_ratio) / (1.0 - settings.fade_start_ratio), 0.0, 1.0)
		label.modulate.a = alpha
		label.outline_modulate.a = settings.outline_color.a * alpha

func has_tail() -> bool:
	return not _entries.is_empty()
