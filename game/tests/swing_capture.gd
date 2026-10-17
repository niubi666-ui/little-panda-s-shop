extends SceneTree
## 出刀逐帧截图（图形模式）：左键第一段、第三段、R 重击各一张拼图，每格是一个物理帧（60 帧/秒），从按键开始到收招结束。
## 输出 builds/visual_pass/swing_<招式>.png。用来检查“快—狠—停”的节奏和刀光、敌人受击是否对得上。
## godot --path game --resolution 1280x800 --script res://tests/swing_capture.gd
const OUT := "E:/ShopGame/builds/visual_pass/"
const CELL := Vector2i(320, 200)
const COLUMNS := 6
var arena
var player

class AimSink:
	var movement := Vector3.ZERO
	var facing := Vector3.FORWARD
	var global_position := Vector3.ZERO
	func clear_intents() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(120.0).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	arena.training_tools.panel.hide()
	player = arena.player
	player.set_damage_immunity(true)
	arena.input_adapter.actor = AimSink.new()
	for case in [["primary", "slash_1", 0], ["primary", "slash_3", 2], ["special", "heavy", 0]]:
		await _capture(case[0], case[1], int(case[2]))
	quit(0)

func _dummy():
	for actor in arena.actors:
		if actor != player and actor.health.alive(): actor.global_position = Vector3(60, 0.12, 60)
	var dummy = arena._spawn(arena.catalog.actor("scout"), player.global_position + Vector3(0, 0, -1.6), 1)
	arena._register_enemy_brain(dummy)
	dummy.health.maximum = 5000.0
	dummy.health.current = 5000.0
	await physics_frame
	return dummy

func _hold(dummy) -> void:
	dummy.global_position = player.global_position + Vector3(0, 0, -1.6)
	player.facing = Vector3.FORWARD

## combo：先打出前面几段（不截图），再截目标那一段
func _capture(action: String, name: String, combo: int) -> void:
	player.global_position = Vector3(0, player.global_position.y, 2.0)
	var dummy = await _dummy()
	for i in combo:
		_hold(dummy)
		player.request_action(action)
		while player.runner.phase() != "recovery" or player.runner.elapsed < player.runner.ability.windup + player.runner.ability.active + 0.02:
			_hold(dummy)
			await physics_frame
	if combo == 0:
		while player.runner.busy(): await physics_frame
		for i in 20: await physics_frame
	_hold(dummy)
	player.request_action(action)
	var frames: Array[Image] = []
	var labels: Array = []
	var phases: Array = []
	# 截图读回比实时慢：把引擎时间放慢，按战斗时间每 1/60 秒留一格
	Engine.time_scale = 0.1
	var kept_at := -1.0
	var idle_frames := 0
	for i in 3000:
		await RenderingServer.frame_post_draw
		var busy: bool = player.runner.busy()
		var clock: float = player.runner.elapsed if busy else kept_at + 1.0 / 60.0
		if busy and kept_at >= 0.0 and clock - kept_at < 1.0 / 60.0 - 0.0005: continue
		kept_at = clock
		var image := root.get_texture().get_image()
		var size := image.get_size()
		# 判定段开始后第 3 格：另存一张原尺寸，方便看清刀光细节
		if phases.count("active") == 2 and busy and player.runner.phase() == "active":
			image.get_region(Rect2i(size.x / 2 - 400, size.y / 2 - 250, 800, 500)).save_png(OUT + "swing_" + name + "_hit.png")
		# 只取角色附近：以主角为中心的一块
		var center := (arena.get_node("Camera") as Camera3D).unproject_position(player.global_position + Vector3.UP * 0.9)
		image = image.get_region(Rect2i(int(center.x) - 200, int(center.y) - 125, 400, 250))
		image.resize(CELL.x, CELL.y)
		image.convert(Image.FORMAT_RGBA8)
		frames.append(image)
		phases.append(player.runner.phase() if busy else "idle")
		labels.append("%s@%.3f" % [phases.back(), clock])
		if not busy:
			idle_frames += 1
			if idle_frames >= 3: break
	Engine.time_scale = 1.0
	var rows := int(ceil(frames.size() / float(COLUMNS)))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	var tints := {"windup": Color(1, 0.8, 0.2), "active": Color(1, 0.2, 0.2), "recovery": Color(0.3, 0.6, 1), "idle": Color(0.5, 0.5, 0.5)}
	for index in frames.size():
		var at := Vector2i(index % COLUMNS * CELL.x, index / COLUMNS * CELL.y)
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, CELL), at)
		# 左上角色块：黄=前摇 红=判定 蓝=收招
		sheet.fill_rect(Rect2i(at + Vector2i(4, 4), Vector2i(26, 12)), tints.get(phases[index], Color.WHITE))
	sheet.save_png(OUT + "swing_" + name + ".png")
	print("SHOT swing_", name, " frames=", frames.size(), " ", labels)
	dummy.receive_hit(dummy.health.current + 1.0)
	for i in 30: await physics_frame
