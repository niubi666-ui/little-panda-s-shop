extends Node
## Persistent composition root for the first shop art/interaction preview.
## No inventory, economy or persistent layout writes in this slice.

const TrainingStyle = preload("res://presentation/combat/training_style.tres")
const Loader = preload("res://content/shop_preview/shop_preview_loader.gd")
const Controller = preload("res://presentation/shop_preview/shop_preview_controller.gd")
const PlayerScene = preload("res://presentation/red_panda_preview.tscn")
const ShopScene = preload("res://shop/scenes/shop_interior.tscn")
const Style = preload("res://presentation/shop_preview/shop_preview_style.tres")
const CameraController = preload("res://presentation/shop_preview/shop_camera_controller.gd")
const CameraSettings = preload("res://presentation/shop_preview/shop_camera_settings.tres")
const FoliageUI = preload("res://presentation/foliage/foliage_ui.gd")
const ShopDecoration = preload("res://app/shop_decoration.gd")
const FoliageTheme = preload("res://presentation/foliage/foliage_theme_factory.gd")
const SceneTransition = preload("res://app/scene_transition.gd")

var _training_button: Button
var controller: Controller
var _transition: Node
var pause_menu


func _ready() -> void:
	var loader := Loader.new()
	var registry = loader.load_registry("res://data/manifest.json")
	if registry == null:
		for message in loader.get_errors():
			push_error(message)
		get_tree().quit(1)
		return
	var definition = registry.get_shop_preview()
	for language in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % language))
	var shop: Node3D = ShopScene.instantiate()
	$World.add_child(shop)
	var player: CharacterBody3D = PlayerScene.instantiate()
	$World.add_child(player)
	player.global_position = shop.get_node("PlayerSpawn").global_position
	var visual: Node3D = player.get_node("Visual")
	var animation_player: AnimationPlayer = visual.get_node("AnimationPlayer")
	# Imported resources are shared; isolate animation loop settings per actor instance.
	for library_name in animation_player.get_animation_library_list():
		var library: AnimationLibrary = animation_player.get_animation_library(library_name).duplicate(true)
		for animation_name in library.get_animation_list():
			library.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	var targets: Array[Node3D] = []
	for marker in shop.find_children("*", "Marker3D", true, false):
		if marker.has_meta("instance_id"):
			targets.append(marker)
	var style = Style.duplicate(true)
	style.theme = FoliageTheme.create()
	controller = Controller.new()
	controller.name = "ShopPreviewController"
	add_child(controller)
	var result := controller.configure(player, shop.get_node("ShopCamera"), visual, animation_player, targets, $UIRoot, definition, style)
	if result != OK:
		push_error("[bootstrap] Shop preview configuration failed: " + error_string(result))
		get_tree().quit(1)
		return
	_training_button = Button.new()
	_training_button.text = tr("combat.enter")
	_training_button.position = TrainingStyle.training_entry_position
	_training_button.theme = style.theme
	$UIRoot.add_child(_training_button)
	_training_button.pressed.connect(_enter_training)
	controller.interaction_opened.connect(func(_instance_id, _definition_id): _training_button.hide())
	controller.interaction_closed.connect(func(): _training_button.show())
	controller.use_foliage_shell()
	var foliage_ui := FoliageUI.new()
	pause_menu = preload("res://app/pause_menu.gd").new()
	add_child(pause_menu)
	pause_menu.configure(style.theme)
	foliage_ui.settings_requested.connect(pause_menu.open)
	foliage_ui.name = "FoliageUI"
	$UIRoot.add_child(foliage_ui)
	foliage_ui.modal_changed.connect(controller.set_external_ui_open)
	foliage_ui.modal_changed.connect(func(open): _training_button.visible = not open)
	foliage_ui.configure(registry.get_foliage_preview(), controller.is_interaction_open, style.theme)
	print("[bootstrap] Shop ready; targets=", targets.size(), "; engine=", Engine.get_version_info()["string"])
	var camera_controller := CameraController.new()
	camera_controller.name = "ShopCameraController"
	add_child(camera_controller)
	if camera_controller.configure(shop.get_node("ShopCamera"), player, CameraSettings) != OK:
		push_error("[bootstrap] Invalid camera presentation settings")
		get_tree().quit(1)
		return
	var decorating := ShopDecoration.new()
	decorating.name = "ShopDecoration"
	add_child(decorating)
	if decorating.configure(shop, player, shop.get_node("ShopCamera"), controller, camera_controller, $UIRoot, style.theme, definition, targets):
		foliage_ui.attach_decoration(decorating.open)
		decorating.mode_changed.connect(controller.set_external_ui_open)
		decorating.mode_changed.connect(foliage_ui.set_decoration_active)
		decorating.mode_changed.connect(func(active): _training_button.visible = not active)
	else:
		push_error("[bootstrap] Decoration prototype unavailable; shop remains usable")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("combat_training") and not event.is_echo():
		_enter_training()

func _enter_training() -> void:
	if is_instance_valid(_transition): return
	if controller.is_interaction_open() or $UIRoot/FoliageUI.is_modal_open(): return
	get_viewport().set_input_as_handled()
	_transition = SceneTransition.begin(get_tree(), "res://app/combat_training.tscn", _training_button.theme)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_training_button):
		_training_button.text = tr("combat.enter")
