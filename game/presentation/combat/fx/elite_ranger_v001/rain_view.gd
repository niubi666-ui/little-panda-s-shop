extends Node3D
## Samples the real locked area and next pulse; visual arrows never perform hits.
const Flight = preload("res://presentation/combat/fx/elite_ranger_v001/arrow_flight.gd")
var rain: Dictionary
var profile
var style
var owner_handle := 0
var marker: MeshInstance3D
var arrows: Array[Dictionary] = []
var points := PackedVector3Array()
var finish_age := 0.0
var active_ring: Mesh

func configure(value: Dictionary, visual_profile, actor_style, geometry) -> void:
	rain = value
	profile = visual_profile
	style = actor_style
	owner_handle = rain.source.handle
	global_position = rain.center
	marker = geometry.mesh_node(self)
	marker.position.y = style.ground_height
	marker.mesh = geometry.ring(rain.config.rain_radius_m,style.line_width,style.warning_color)
	active_ring = geometry.ring(rain.config.rain_radius_m,style.line_width * style.rain_active_width_ratio,style.rain_active_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.visual_seed + rain.id
	var rotation := rng.randf()*TAU
	for i in style.rain_arrow_count:
		var angle := float(i)*PI*(3.0-sqrt(5.0))+rotation
		var distance: float = sqrt((float(i)+0.5)/style.rain_arrow_count)*float(rain.config.rain_radius_m)*profile.rain_radius_ratio
		var point: Vector3 = rain.center + Vector3(cos(angle)*distance,style.ground_height,sin(angle)*distance)
		points.append(point)
		var arrow := Flight.new()
		add_child(arrow)
		arrow.configure(profile,style,owner_handle,profile.visual_seed+rain.id+i,false)
		arrow.width_ratio = profile.rain_trail_width_ratio
		arrow.tip_ratio = profile.rain_tip_size_ratio
		arrow.reset()
		arrows.append({"view":arrow,"point":point,"height":style.rain_height*rng.randf_range(profile.rain_height_ratio.x,profile.rain_height_ratio.y),"window":style.rain_fall_sec*rng.randf_range(profile.rain_fall_window_ratio.x,profile.rain_fall_window_ratio.y),"wave":-1})

func sample(delta: float) -> void:
	for entry in arrows:
		var until: float = rain.time_left
		var t := clampf(1.0-until/float(entry.window),0.0,1.0)
		if t <= 0.0:
			entry.view.fade(delta)
			continue
		if entry.wave != rain.pulses:
			entry.view.reset()
			entry.wave = rain.pulses
		var height: float = entry.height*(1.0-profile.rain_fall_curve.sample_baked(t))
		entry.view.sample(entry.point+Vector3.UP*height,Vector3.DOWN,delta)

func commit_pulse(last: bool) -> void:
	marker.mesh = active_ring
	for entry in arrows:
		entry.view.sample(entry.point-Vector3.UP*profile.rain_embed_m,Vector3.DOWN,0.0)
	if last: marker.hide()

func fade(delta: float) -> bool:
	finish_age += delta
	for entry in arrows: entry.view.fade(delta)
	return finish_age >= profile.rain_finish_sec
