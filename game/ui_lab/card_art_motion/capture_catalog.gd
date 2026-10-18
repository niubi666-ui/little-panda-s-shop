extends SceneTree
## Developer-only streaming capture: no intermediate frame files in the project.
const Lab = preload("res://ui_lab/card_art_motion/card_art_motion_lab.tscn")
var _stream := StreamPeerTCP.new()
var _capturing := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var port := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-port="): port = int(argument.trim_prefix("--capture-port="))
	if port <= 0:
		push_error("Use scripts/record_catalog.py to provide a local capture receiver")
		quit(1)
		return
	_stream.connect_to_host("127.0.0.1",port)
	while _stream.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		_stream.poll()
		await process_frame
	if _stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		quit(1)
		return
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	root.add_child(Lab.instantiate())
	RenderingServer.frame_post_draw.connect(_capture)

func _capture() -> void:
	if _capturing: return
	_capturing = true
	var frame := root.get_texture().get_image().save_jpg_to_buffer(0.95)
	_stream.put_u32(frame.size())
	if _stream.put_data(frame) != OK:
		push_error("Capture receiver disconnected")
		quit(1)
	_capturing = false
