extends SceneTree
## Run graphically with --script, never with --write-movie or --fixed-fps.
## CPU render = viewport render CPU + global frame setup; excludes script _process.
const Settings = preload("res://ui_lab/card_art_motion/benchmark_settings.tres")
const LabScene = preload("res://ui_lab/card_art_motion/card_art_motion_lab.tscn")
var _lab
var _output_path: String
var _report: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU benchmark needs a graphical window; headless timings are not representative.")
		quit(2)
		return
	for argument in OS.get_cmdline_args():
		if argument in ["--write-movie", "--fixed-fps", "--disable-render-loop"]:
			push_error("Benchmark cannot run with movie capture, fixed simulation FPS, or disabled rendering.")
			quit(2)
			return
	_output_path = ProjectSettings.globalize_path(Settings.output_path)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output_path = argument.trim_prefix("--output=")
	Engine.max_fps = Settings.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.gui_disable_input = true
	_lab = LabScene.instantiate()
	root.add_child(_lab)
	_lab._demo = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cards="):
			var ids := Array(argument.trim_prefix("--cards=").split(","))
			assert(ids.size() == 3)
			_lab._all_groups.append({"label":"mixed","ids":ids})
			_lab._groups.add_item("Benchmark")
			_lab.set_group(_lab._all_groups.size()-1)
	_lab.set_process_input(false)
	_lab.panel.set_process_input(false)
	_lab.set_intensity(Settings.intensity)
	_lab.set_motion_paused(false)
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	_report = {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"window_resolution": [root.size.x, root.size.y],
		"viewport_resolution": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"scene": LabScene.resource_path, "cards": _lab._all_groups[_lab.group_index].ids,
		"intensity": Settings.intensity, "sample_sec_per_block": Settings.sample_sec,
		"warmup_sec_per_block": Settings.warmup_sec, "mode_sequence": Settings.mode_sequence,
		"utc_started": Time.get_datetime_string_from_system(true), "blocks": [],
		"measurement_notes": [
			"RenderingServer viewport CPU plus global setup, in milliseconds; excludes script process/physics work.",
			"GPU uses RenderingServer viewport timestamps; zero/unavailable samples are counted separately.",
			"Wall frame interval includes waiting, scheduling and the benchmark itself; it is not pure CPU execution time.",
			"Process monitor is an engine cached sample, not an independent per-frame CPU measurement.",
			"No 3D gameplay loaded, input disabled, no mouse focus changes, no recording or image readback during samples.",
			"Same process alternates static/dynamic twice. System background load and GPU power states remain uncontrolled.",
			"This is a three-card UI cost comparison, not a gameplay frame rate claim or minimum specification."
		]
	}
	var merged := {"static": _new_samples(), "dynamic": _new_samples()}
	for mode in Settings.mode_sequence:
		_lab.set_motion_enabled(mode == "dynamic")
		await wait_seconds(Settings.warmup_sec)
		var samples: Dictionary = await measure(Settings.sample_sec, viewport)
		var block := {"mode": mode, "metrics": summarize(samples)}
		_report.blocks.append(block)
		for metric in samples: merged[mode][metric].append_array(samples[metric])
		print("CARD_ART_BENCHMARK ", JSON.stringify(block))
	_report["combined"] = {"static": summarize(merged.static), "dynamic": summarize(merged.dynamic)}
	DirAccess.make_dir_recursive_absolute(_output_path.get_base_dir())
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write benchmark report: " + _output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	print("CARD_ART_BENCHMARK saved=", _output_path)
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	_lab.queue_free()
	await process_frame
	quit()

func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until: await process_frame

func _new_samples() -> Dictionary:
	return {"render_cpu_ms": [], "gpu_ms": [], "wall_frame_interval_ms": [], "cached_process_monitor_ms": []}

func measure(seconds: float, viewport: RID) -> Dictionary:
	var result := _new_samples()
	var previous := Time.get_ticks_usec()
	var until := previous + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		result.wall_frame_interval_ms.append(float(now - previous) / 1000.0)
		previous = now
		result.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu())
		result.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		result.cached_process_monitor_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	return result

func summarize(samples: Dictionary) -> Dictionary:
	var result := {}
	for metric in samples:
		var values: Array = samples[metric].filter(func(value): return float(value) > 0.0)
		values.sort()
		var total := 0.0
		for value in values: total += float(value)
		result[metric] = {"samples": values.size(), "zero_or_unavailable": samples[metric].size() - values.size(),
			"mean": null if values.is_empty() else total / values.size(),
			"p95": null if values.is_empty() else values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)]}
	return result
