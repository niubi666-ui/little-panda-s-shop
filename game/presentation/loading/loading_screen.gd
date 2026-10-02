extends CanvasLayer
## Replace the visual scene/animation later; the app owns actual loading and switching.
signal dismiss_requested
var _progress := 0.0
var _stage := "loading"
@onready var _title: Label = $Screen/Center/Panel/Margin/Content/Title
@onready var _status: Label = $Screen/Center/Panel/Margin/Content/Status
@onready var _bar: ProgressBar = $Screen/Center/Panel/Margin/Content/Progress
@onready var _close: Button = $Screen/Center/Panel/Margin/Content/Close

func _ready() -> void:
	_close.pressed.connect(func(): dismiss_requested.emit())
	_refresh()

func show_progress(ratio: float) -> void:
	_progress = maxf(_progress, clampf(ratio, 0.0, 1.0))
	_refresh()

func show_preparing() -> void:
	_stage = "preparing"
	_progress = 1.0
	_refresh()

func show_failure() -> void:
	_stage = "failed"
	_refresh()
	_close.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	_title.text = tr("loading.title")
	_bar.value = _progress * _bar.max_value
	_bar.visible = _stage != "failed"
	_close.visible = _stage == "failed"
	_close.text = tr("loading.return")
	if _stage == "loading":
		_status.text = tr("loading.progress").format({"percent": int(_progress * _bar.max_value)})
	else:
		_status.text = tr("loading." + _stage)
