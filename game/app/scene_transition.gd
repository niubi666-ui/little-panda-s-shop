extends Node
## One transient transition owner outside current_scene; no autoload or gameplay service.
signal completed
signal failed(error: Error)
const ViewScene = preload("res://presentation/loading/loading_screen.tscn")
var target_path: String
var view: CanvasLayer
var stage := "pending"
var timings: Dictionary = {}
var _tree: SceneTree
var _previous_pause: bool
var _previous_disable_3d: bool
var _restored := false
var _started_ms: int
var _phase_started_ms: int
var _present_frames := 0
var _packed: PackedScene
var _prepare_scene: Callable

static func begin(tree: SceneTree, path: String, ui_theme: Theme, prepare_scene: Callable = Callable()) -> Node:
	var script = load("res://app/scene_transition.gd")
	var operation: Node = script.new()
	operation.name = "SceneTransition"
	operation.process_mode = Node.PROCESS_MODE_ALWAYS
	operation.target_path = path
	operation._prepare_scene = prepare_scene
	operation._tree = tree
	operation._previous_pause = tree.paused
	operation._previous_disable_3d = tree.root.disable_3d
	operation.view = ViewScene.instantiate()
	operation.view.get_node("Screen").theme = ui_theme
	operation.add_child(operation.view)
	tree.root.add_child(operation)
	# Lock immediately so repeated input in the same frame cannot reach gameplay.
	tree.paused = true
	tree.root.disable_3d = true
	operation._started_ms = Time.get_ticks_msec()
	operation.view.dismiss_requested.connect(operation._dismiss_failure)
	operation.view.show_progress(0.0)
	return operation

func _input(event: InputEvent) -> void:
	# Leave mouse/focus events available to the error screen's own controls.
	if stage != "failed" and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	match stage:
		"pending":
			# Render the overlay before requesting resources, with no timed fake progress.
			_present_frames += 1
			if _present_frames >= 2: _request()
		"loading": _poll()
		"preparing":
			_present_frames += 1
			if _present_frames >= 2: _commit()
		"first_frames":
			_present_frames += 1
			if _present_frames >= 2: _complete()

func _request() -> void:
	stage = "loading"
	_phase_started_ms = Time.get_ticks_msec()
	if not ResourceLoader.exists(target_path, "PackedScene"):
		_fail(ERR_FILE_NOT_FOUND)
		return
	if ResourceLoader.has_cached(target_path):
		# Only read an already resident scene here; cold loads always use the worker.
		_accept_packed(ResourceLoader.load(target_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene)
		return
	# Keep loading on a background worker without requesting extra dependency workers.
	# 4.7 has a reported nested LoadToken leak; exit diagnostics remain part of QA.
	# https://github.com/godotengine/godot/issues/120661
	var error := ResourceLoader.load_threaded_request(target_path, "PackedScene", false)
	if error != OK:
		_fail(error)
		return

func _poll() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_path, progress)
	if not progress.is_empty(): view.show_progress(float(progress[0]))
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail(ERR_CANT_OPEN)
		return
	_accept_packed(ResourceLoader.load_threaded_get(target_path) as PackedScene)

func _accept_packed(packed: PackedScene) -> void:
	_packed = packed
	if _packed == null:
		_fail(ERR_INVALID_DATA)
		return
	timings["resource_ms"] = Time.get_ticks_msec() - _phase_started_ms
	stage = "preparing"
	_present_frames = 0
	view.show_preparing()

func _commit() -> void:
	stage = "committing"
	_phase_started_ms = Time.get_ticks_msec()
	_tree.scene_changed.connect(_on_scene_ready, CONNECT_ONE_SHOT)
	var scene := _packed.instantiate()
	if _prepare_scene.is_valid(): _prepare_scene.call(scene)
	_prepare_scene = Callable()
	var error := _tree.change_scene_to_node(scene)
	if error != OK:
		scene.free()
		_tree.scene_changed.disconnect(_on_scene_ready)
		_fail(error)

func _on_scene_ready() -> void:
	timings["instantiate_ms"] = Time.get_ticks_msec() - _phase_started_ms
	# Permit the first new 3D frames behind the overlay, while gameplay stays paused.
	_tree.root.disable_3d = _previous_disable_3d
	_phase_started_ms = Time.get_ticks_msec()
	_present_frames = 0
	stage = "first_frames"

func _complete() -> void:
	timings["first_frames_ms"] = Time.get_ticks_msec() - _phase_started_ms
	timings["total_ms"] = Time.get_ticks_msec() - _started_ms
	print("[transition] ", target_path, " ", JSON.stringify(timings))
	stage = "complete"
	_restore()
	completed.emit()
	queue_free()

func _fail(error: Error) -> void:
	stage = "failed"
	push_warning("[transition] Cannot load %s: %s" % [target_path, error_string(error)])
	view.show_failure()
	failed.emit(error)

func _dismiss_failure() -> void:
	if stage != "failed": return
	_restore()
	queue_free()

func _restore() -> void:
	if _restored: return
	_restored = true
	_tree.paused = _previous_pause
	_tree.root.disable_3d = _previous_disable_3d

func _exit_tree() -> void:
	_restore()
