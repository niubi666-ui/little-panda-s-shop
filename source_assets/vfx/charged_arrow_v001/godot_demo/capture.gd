extends SceneTree
const RiftScript = preload("res://fx/rift.gd")
## Own standalone process. Fixed-step rendering; not gameplay or concepts from game/.
var demo
var movie := false
var output := "E:/ShopGame/source_assets/vfx/charged_arrow_v001/previews"
var frames := "E:/ShopGame/builds/charged_arrow_v001_frames"
var report: Dictionary = {"source":"Standalone Godot Forward+ art study, actual elf and red panda assets", "fps":30, "segments":[], "checks":[]}
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	movie=OS.get_cmdline_user_args().has("--movie")
	create_timer(3600.0).timeout.connect(func():quit(1))
	call_deferred("run")
func snap(path: String) -> void:
	# The isolated window is offscreen. Force drawing instead of depending on OS visibility.
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(path)==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://demo.tscn").instantiate()
	root.add_child(demo)
	current_scene=demo
	demo.set_process(false)
	for i in 8: await process_frame
	print("CHARGED_ARROW_CAPTURE_READY")
	var cases: Array = [{"id":"stand","duration":9.4,"scale":1.0},{"id":"slow","duration":3.6,"scale":0.2},{"id":"walk","duration":3.8,"scale":1.0},{"id":"dodge","duration":3.8,"scale":1.0},{"id":"trail","duration":5.1,"scale":1.0}]
	if not movie:
		cases=[{"id":"charge","duration":2.25,"scale":1.0},{"id":"release","duration":2.428,"scale":1.0},{"id":"scar","duration":3.44,"scale":1.0},{"id":"walk","duration":2.72,"scale":1.0},{"id":"dodge","duration":2.75,"scale":1.0}]
	for item in cases:
		var mode: String=item.id if item.id in ["walk","dodge","trail"] else "stand"
		demo.reset(mode)
		demo.slow=false
		if item.id=="slow":
			demo.step(2.12)
			demo.slow_button.button_pressed=true
		else: demo.slow_button.button_pressed=false
		var directory: String=frames.path_join(item.id)
		if movie: DirAccess.make_dir_recursive_absolute(directory)
		var count:=int(ceil(float(item.duration)*30.0))
		var segment: Dictionary={"id":item.id,"frames":count,"time_scale":item.scale,"start_simulation_time":demo.rules.clock,"events":[]}
		for i in count:
			var delta:=1.0/30.0*float(item.scale)
			if not movie and i==count-1: delta=float(item.duration)-demo.rules.clock
			demo.step(maxf(delta,0.0))
			await process_frame
			if movie: await snap(directory.path_join("frame_%04d.png"%i))
			if movie and i%60==0: print("CHARGED_ARROW_PROGRESS ",item.id," ",i,"/",count)
			if movie and item.id=="stand":
				for shot in [{"id":"charge","time":2.25},{"id":"release","time":2.428},{"id":"scar","time":3.44}]:
					if i==int(round(float(shot.time)*30.0))-1: await snap(output.path_join(shot.id+".png"))
		if not movie:
			await snap(output.path_join(item.id+".png"))
			print("CHARGED_ARROW_STILL ",item.id," clock=",demo.rules.clock," hp=",demo.rules.health)
		else:
			segment.events=demo.rules.events.duplicate(true)
			report.segments.append(segment)
			print("CHARGED_ARROW_SEGMENT ",item.id," ",count)
		if item.id=="walk": assert(demo.rules.arrow_count==1)
		if item.id=="dodge": assert(demo.rules.arrow_count==0)
	# Validate the graphical presenter uses exactly the same rule dimensions and pause clock.
	demo.reset("stand")
	demo.step(3.0)
	assert(is_equal_approx(demo.effect.ground.material_override.get_shader_parameter("half_width"),demo.rules.config.skill.trail_half_width_m))
	assert(is_equal_approx(demo.effect.ground.material_override.get_shader_parameter("tick_sec"),demo.rules.config.skill.trail_tick_sec))
	assert(demo.effect.rift.walls.mesh.get_aabb().size.y>=demo.art.rift_depth_m)
	assert(demo.effect.rift.curtains[0].mesh.get_aabb().end.y>=demo.art.rift_height_m.x)
	for i in 101:
		var shape: Vector2=demo.effect.rift.shape(float(i)/100.0*demo.rules.config.skill.range_m)
		assert(absf(shape.x)+shape.y<=demo.rules.config.skill.trail_half_width_m)
	assert(not demo.effect.rift.floor_view.floor_materials.is_empty())
	assert(demo.effect.rift.floor_view.floor_materials[0].get_shader_parameter("rift_active"))
	for name in ["Courtyard_foundation","Continuous_forest_valley_ground"]:
		assert(name in demo.effect.rift.floor_view.cut_surfaces)
	for material in demo.effect.rift.floor_view.floor_materials:
		assert(material.get_shader_parameter("rift_contour")==demo.effect.rift.contour_texture)
	var contour_image: Image=demo.effect.rift.contour_texture.get_image()
	for i in demo.art.rift_station_count:
		var texel:=contour_image.get_pixel(i,0)
		var at: float=float(i)/(demo.art.rift_station_count-1)*demo.rules.config.skill.range_m
		var sample: Vector2=demo.effect.rift.shape(at)/demo.rules.config.skill.trail_half_width_m
		assert(sample.is_equal_approx(Vector2(texel.r,texel.g)))
	var before: Array=[demo.rules.clock,demo.rules.target,demo.rules.health,demo.effect.ground.material_override.get_shader_parameter("time_value")]
	demo.step(0.0)
	assert([demo.rules.clock,demo.rules.target,demo.rules.health,demo.effect.ground.material_override.get_shader_parameter("time_value")]==before)
	var a: Dictionary={"health":demo.rules.health,"events":demo.rules.events.duplicate(true)}
	demo.reset("stand")
	demo.effect.set_enabled(false)
	demo.step(3.0)
	assert(demo.rules.health==a.health and demo.rules.events==a.events)
	assert(not demo.effect.rift.floor_view.floor_materials[0].get_shader_parameter("rift_active"))
	demo.effect.set_enabled(true)
	demo.language="en"
	demo.refresh()
	await process_frame
	for button in demo.buttons.values(): assert(button.get_global_rect().end.x<=root.size.x)
	await snap(output.path_join("ui_en.png"))
	report.checks=["fixed rule hazard width", "0.5-second rule pulse drives shader", "pause freezes visual clock", "disabled VFX preserves test damage", "walking test hit", "dodge test safe", "geometric rift depth", "elevated turbulent plumes", "rift fits hazard across 101 points", "floor opens and restores with VFX", "English buttons fit viewport", "foundation and terrain cut beneath paving", "all ground layers share contour texture", "geometry matches 160 contour texels"]
	if movie:
		var file:=FileAccess.open(output.path_join("capture_report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CHARGED_ARROW_VISUAL_CHECKS ",report.checks.size())
	demo.queue_free()
	await process_frame
	await process_frame
	quit(0)
