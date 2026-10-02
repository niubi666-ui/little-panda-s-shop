extends SceneTree
## Matched art/performance comparison; never changes gameplay or quality resources.
var label := "baseline"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): label = args[0]
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var started := Time.get_ticks_msec()
	var host = load("res://app/combat_training.tscn").instantiate()
	host.build_choices_enabled = false
	root.add_child(host)
	current_scene = host
	host.paused = true
	host.get_node("UIRoot").hide()
	var creation_ms := Time.get_ticks_msec() - started
	await create_timer(5.0).timeout
	var samples: Array[float] = []
	for i in 180:
		var stamp := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - stamp) / 1000.0)
	samples.sort()
	var total := 0.0
	for value in samples: total += value
	var result := {"label": label, "creation_ms": creation_ms, "mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var base := "E:/ShopGame/builds/foliage_" + label
	for zoom in [17.0, 12.0, 24.0]:
		host.get_node("Camera").size = zoom
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(base + "_zoom_" + str(int(zoom)) + ".png")
	var output := FileAccess.open(base + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("FOLIAGE_COMPARISON ", JSON.stringify(result))
	host.queue_free()
	await process_frame
	await process_frame
	quit()
