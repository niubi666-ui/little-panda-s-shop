extends Control
## Scene-owned local UI clock. Never touches gameplay RNG, data or shared materials.
static var _instance_serial := 0
const Profile = preload("res://presentation/builds/card_art_motion/profile.gd")
var profile: Profile
var overlay: TextureRect
var clock := 0.0
var phase := 0.0
var enabled := true
var paused := false
var intensity := 1.0
var _focus := 0.0
var _texture_size := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _particles: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _event_period := 0.0
var _marks: Marks
var _visible_marks := 0
var _layers: Array[Control] = []

class Marks extends Control:
	var motion
	func _draw() -> void: motion.draw_marks(self)

func configure(definition: Profile, texture: Texture2D) -> void:
	profile = definition
	profile.validate()
	_texture_size = texture.get_size()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	if profile.kind == "composite":
		for layer_profile in profile.layers:
			var layer = get_script().new()
			add_child(layer)
			layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer.configure(layer_profile,texture)
			_layers.append(layer)
		return
	enabled = profile.enabled
	intensity = profile.intensity
	_instance_serial += 1
	_rng.seed = profile.seed + _instance_serial * profile.instance_seed_stride
	phase = _rng.randf_range(0.0,profile.phase_span)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	overlay = TextureRect.new()
	overlay.name = "LocalArtOverlay"
	overlay.texture = texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var effect := ShaderMaterial.new()
	effect.shader = profile.shader
	overlay.material = effect
	add_child(overlay)
	var values := {"region_mask":profile.mask,"effect_kind":["fire","ice","thunder","energy","earth"].find(profile.kind),
		"phase":phase,"period":profile.flow_period_sec,"flow_px":profile.flow_px,
		"flow_direction":profile.flow_direction,"flow_speed_px":profile.flow_speed_px,"flow_emission":profile.flow_emission,
		"glow_variation":profile.glow_variation,"noise_scale":profile.noise_scale,"noise_speed":profile.noise_speed,
		"tint":profile.tint,"mist_opacity":profile.mist_opacity,"mist_speed_px":profile.mist_speed_px}
	for key in values:
		effect.set_shader_parameter(key,values[key])
	if profile.kind == "ice":
		var puffs := PackedVector4Array()
		puffs.resize(12)
		for i in profile.mist_puff_count:
			var origin := _path_point(profile.mist_emission_path,(i+_rng.randf())/profile.mist_puff_count)
			puffs[i] = Vector4(origin.x,origin.y,(i+_rng.randf())/profile.mist_puff_count,_rng.randf())
		var mist_values := {"mist_noise":profile.mist_noise,"mist_puffs":puffs,"mist_puff_count":profile.mist_puff_count,
			"mist_lifetime":profile.mist_lifetime,"mist_velocity":profile.mist_velocity,
			"mist_radius_start":profile.mist_radius_start,"mist_radius_end":profile.mist_radius_end,
			"mist_sway_px":profile.mist_sway_px,"mist_sway_hz":profile.mist_sway_hz,
			"mist_color":profile.mist_color,"mist_max_alpha":profile.mist_max_alpha}
		for key in mist_values: effect.set_shader_parameter(key,mist_values[key])
	_marks = Marks.new()
	_marks.name = "LocalArtMarks"
	_marks.motion = self
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	for i in profile.particle_count:
		_particles.append({"uv":_path_point(profile.emission_path,_rng.randf()),"life":_rng.randf_range(profile.particle_life.x,profile.particle_life.y),
			"offset":_rng.randf_range(0.0,profile.particle_life.y),"size":_rng.randf_range(profile.particle_radius.x,profile.particle_radius.y),"drift":_rng.randf_range(profile.particle_drift_spread.x,profile.particle_drift_spread.y)})
	if profile.kind == "thunder":
		var previous_path := -1
		for i in profile.arc_schedule_count:
			var available_paths: Array[int] = []
			for path in profile.arc_paths.size():
				if profile.arc_paths.size() > 1 and path == previous_path: continue
				if not _events.is_empty() and profile.arc_paths.size() > 2 and i == profile.arc_schedule_count-1 and path == _events[0].path: continue
				available_paths.append(path)
			var selected_path: int = available_paths[_rng.randi_range(0,available_paths.size()-1)]
			_events.append({"start":_event_period,"duration":_rng.randf_range(profile.arc_duration.x,profile.arc_duration.y),"path":selected_path,"seed":_rng.randi()})
			previous_path = selected_path
			_event_period += _rng.randf_range(profile.arc_interval.x,profile.arc_interval.y)
	resized.connect(_layout)
	visibility_changed.connect(_sync_visibility)
	_layout()
	_sync_visibility()

func source_to_local(uv: Vector2) -> Vector2:
	var scale_factor := maxf(size.x/_texture_size.x,size.y/_texture_size.y)
	var covered := _texture_size * scale_factor
	return uv * covered + (size-covered)*0.5

func _layout() -> void:
	if overlay == null or size.x <= 0.0 or size.y <= 0.0: return
	var covered := _texture_size * maxf(size.x/_texture_size.x,size.y/_texture_size.y)
	overlay.material.set_shader_parameter("uv_per_pixel",Vector2.ONE/covered)
	_marks.size = size
	_marks.queue_redraw()

func set_enabled(value: bool) -> void:
	enabled = value
	_sync_visibility()
func set_intensity(value: float) -> void:
	assert(is_finite(value) and value >= 0.0)
	intensity = value
	for layer in _layers: layer.set_intensity(value)
	_sync_visibility()
func set_paused(value: bool) -> void:
	paused = value
	for layer in _layers: layer.set_paused(value)
func _sync_visibility() -> void:
	for layer in _layers: layer.set_enabled(enabled)
	if overlay == null: return
	var shown := enabled and intensity > 0.0 and is_visible_in_tree()
	overlay.visible = shown
	_marks.visible = shown
	if not shown: _visible_marks = 0
	_marks.queue_redraw()
func advance(delta: float, focus: float) -> void:
	if not enabled or paused or intensity <= 0.0 or not is_visible_in_tree(): return
	clock += maxf(0.0,delta)
	_focus = focus
	if not _layers.is_empty():
		for layer in _layers: layer.advance(delta,focus)
		return
	overlay.material.set_shader_parameter("motion_clock",clock)
	overlay.material.set_shader_parameter("strength",intensity*(1.0+profile.hover_gain*_focus))
	_marks.queue_redraw()
func diagnostics() -> Dictionary:
	if not _layers.is_empty():
		var particles := 0
		for layer in _layers: particles += int(layer.diagnostics().particles)
		return {"clock":clock,"phase":phase,"particles":particles,"material_id":0,"layers":_layers.size()}
	return {"clock":clock,"phase":phase,"particles":_visible_marks,"material_id":overlay.material.get_instance_id()}

func _path_point(path: PackedVector2Array, amount: float) -> Vector2:
	var index := minf(amount*(path.size()-1),path.size()-1.000001)
	return path[int(index)].lerp(path[int(index)+1],fposmod(index,1.0))
func _particle_point(particle: Dictionary, age: float) -> Vector2:
	var sway := sin((age + float(particle.offset)) * TAU * profile.particle_sway_hz)
	return source_to_local(particle.uv) + profile.particle_drift * float(particle.drift) * age + profile.particle_sway * sway
func draw_marks(canvas: Control) -> void:
	_visible_marks = 0
	if not enabled or intensity <= 0.0 or not is_visible_in_tree(): return
	var amount: float = intensity*(1.0+profile.hover_gain*_focus)
	var t := clock+phase
	for particle in _particles:
		var age := fposmod(t+particle.offset,particle.life)
		var point := _particle_point(particle,age)
		if not Rect2(Vector2.ZERO,size).has_point(point): continue
		var alpha: float = sin(PI*age/particle.life)*profile.particle_opacity*amount
		canvas.draw_circle(point,particle.size*profile.particle_glow_scale,Color(profile.tint,alpha*profile.particle_glow_opacity))
		if profile.particle_tail_sec > 0.0:
			var tail := _particle_point(particle,maxf(0.0,age-profile.particle_tail_sec))
			canvas.draw_line(tail,point,Color(profile.tint,alpha),particle.size,true)
		if profile.kind == "earth":
			var shard := PackedVector2Array()
			for corner in [Vector2(0,-1.6),Vector2(1,0),Vector2(0,1.6),Vector2(-1,0)]:
				shard.append(point+corner.rotated(age)*particle.size)
			canvas.draw_colored_polygon(shard,Color(profile.particle_core,alpha))
		else: canvas.draw_circle(point,particle.size,Color(profile.particle_core,alpha))
		_visible_marks += 1
	for i in profile.stream_count:
		var path: PackedVector2Array = profile.stream_paths[i%profile.stream_paths.size()]
		var progress := fposmod(t/profile.stream_period+float(i)/profile.stream_count,1.0)
		var opacity: float = sin(PI*progress)*profile.stream_opacity*amount
		var previous := source_to_local(_path_point(path,maxf(0.0,progress-profile.stream_tail_fraction)))
		for part in range(1,9):
			var along := lerpf(maxf(0.0,progress-profile.stream_tail_fraction),progress,float(part)/8.0)
			var point := source_to_local(_path_point(path,along))
			var alpha := opacity*float(part)/8.0
			canvas.draw_line(previous,point,Color(profile.tint,alpha*profile.particle_glow_opacity),profile.stream_width*profile.particle_glow_scale,true)
			canvas.draw_line(previous,point,Color(profile.particle_core,alpha),profile.stream_width,true)
			previous = point
		_visible_marks += 1
	if profile.kind == "ice":
		_visible_marks += profile.mist_puff_count
		var cycle := floori(t/profile.sparkle_period)
		for i in profile.sparkle_count:
			var age: float = fposmod(t,profile.sparkle_period)-i*profile.sparkle_stagger
			if age < 0.0 or age >= profile.sparkle_duration: continue
			var point := source_to_local(profile.sparkle_points[(cycle*profile.sparkle_count+i)%profile.sparkle_points.size()])
			var strength: float = sin(PI*age/profile.sparkle_duration)*amount
			var length: float = profile.sparkle_size*strength
			canvas.draw_circle(point,length,Color(profile.tint,profile.particle_glow_opacity*strength))
			canvas.draw_line(point-Vector2(length,0),point+Vector2(length,0),Color(profile.particle_core,strength),profile.sparkle_width,true)
			canvas.draw_line(point-Vector2(0,length),point+Vector2(0,length),Color(profile.particle_core,strength),profile.sparkle_width,true)
			_visible_marks += 1
	elif profile.kind == "thunder":
		var local_time := fposmod(t,_event_period)
		for event in _events:
			# Wrap each lifetime as well as the schedule: the last arcs continue
			# over the seam while the next arcs appear, without a periodic dead gap.
			var age: float = fposmod(local_time-event.start,_event_period)
			if age >= event.duration: continue
			var strength: float = sin(PI*age/event.duration)*amount
			var reveal := clampf(age/profile.arc_reveal_sec,0.0,1.0)
			_arc(canvas,profile.arc_paths[event.path],strength,event.seed,reveal)
			for i in profile.arc_branches.size():
				if profile.branch_parents[i] == event.path: _arc(canvas,profile.arc_branches[i],strength,event.seed+i,reveal)
func _arc(canvas: Control, path: PackedVector2Array, strength: float, seed_value: int, reveal: float) -> void:
	var points := PackedVector2Array()
	var flutter := floori((clock+phase)*profile.arc_flutter_hz)
	var visible_segments := reveal*(path.size()-1)
	for i in path.size():
		var jitter := Vector2(sin(float(seed_value%1009)+i*17.0+flutter),cos(float(seed_value%1013)+i*13.0+flutter))*profile.arc_jitter_px
		var point := source_to_local(path[i])+jitter if i>0 and i<path.size()-1 else source_to_local(path[i])
		if i > visible_segments:
			points.append(points[-1].lerp(point,fposmod(visible_segments,1.0)))
			break
		points.append(point)
	if points.size() < 2 or reveal <= 0.0: return
	canvas.draw_polyline(points,Color(profile.tint,strength*profile.arc_opacities.x),profile.arc_widths.x,true)
	canvas.draw_polyline(points,Color(profile.tint,strength*profile.arc_opacities.y),profile.arc_widths.y,true)
	canvas.draw_polyline(points,Color(profile.particle_core,strength*profile.arc_opacities.z),profile.arc_widths.z,true)
