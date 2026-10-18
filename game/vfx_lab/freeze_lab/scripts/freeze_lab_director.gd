extends Node3D
## 冰冻特效测试场：一排游戏里的真实敌人模型（体型各不相同），循环演示 冻结 → 冻住 → 碎冰。
## 按键：F 手动冻结/碎冰，空格 暂停/继续自动循环，P 暂停时间（检查冻结特效会不会一起停），L 白天/夜晚，C 机位。
## 录屏参数（-- 后面）：look=1 白天，camera=0/1/2。

@export var enemy_ids: PackedStringArray = ["brute", "charger", "scout", "crossbow", "banner", "elite_ranger"]
@export var spacing := 2.3
@export var freeze_scene: PackedScene
@export var camera: Camera3D
@export var label: Label
@export var world_env: WorldEnvironment
@export var sun: DirectionalLight3D
@export var looks: Array[Resource] = []
@export var hold_time := 2.4
@export var rest_time := 1.3
@export var stagger := 0.12

var _enemies: Array = []    # {visual, anim, fx}
var _auto := true
var _time_paused := false
var _look := 0
var _cycle_t := 0.0
var _cycle_state := "rest"


func _ready() -> void:
	for i in enemy_ids.size():
		_spawn(enemy_ids[i], Vector3((i - (enemy_ids.size() - 1) * 0.5) * spacing, 0, 0))
	_apply_look(0)
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			match kv[0]:
				"look": _apply_look(int(kv[1]))
				"camera": camera.apply_preset(int(kv[1]))
	_cycle_t = 0.6
	_refresh_label()


func _spawn(id: String, at: Vector3) -> void:
	var pres = load("res://presentation/combat/%s_presentation.tres" % id)
	var visual: Node3D = pres.visual_scene.instantiate()
	add_child(visual)
	visual.position = at
	# 面向镜头（+Z）：模型自带的朝向偏移再转半圈
	visual.rotation_degrees.y = pres.visual_yaw_offset_deg + 180.0
	var anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)
	if anim != null:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clip := _idle_clip(visual, anim)
		if clip != &"":
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip)
			anim.advance(randf() * anim.get_animation(clip).length)
	var fx: Node3D = freeze_scene.instantiate()
	add_child(fx)
	fx.attach(visual)
	_enemies.append({"visual": visual, "anim": anim, "fx": fx, "id": id})


func _idle_clip(visual: Node3D, anim: AnimationPlayer) -> StringName:
	var cs = visual.get("clip_set")
	if cs != null and cs.get("idle") != null and anim.has_animation(cs.idle):
		return cs.idle
	for name in anim.get_animation_list():
		if String(name).to_lower().contains("idle"):
			return name
	var list := anim.get_animation_list()
	return list[0] if not list.is_empty() else &""


func _process(delta: float) -> void:
	var dt := 0.0 if _time_paused else delta
	for e in _enemies:
		# 冻住时姿势保持不动（游戏里冻结时也是 control_locked 停住动作）
		if e.anim != null and dt > 0.0 and not e.fx.is_frozen():
			e.anim.advance(dt)
		e.fx.tick(dt)
	if _auto and dt > 0.0:
		_cycle_t -= dt
		if _cycle_t <= 0.0:
			if _cycle_state == "rest":
				_cycle_state = "frozen"
				_cycle_t = hold_time
				_stagger_call("freeze")
			else:
				_cycle_state = "rest"
				_cycle_t = rest_time
				_stagger_call("release")


func _stagger_call(method: String) -> void:
	for i in _enemies.size():
		var fx: Node3D = _enemies[i].fx
		get_tree().create_timer(stagger * i).timeout.connect(func(): fx.call(method))


func _apply_look(i: int) -> void:
	if looks.is_empty():
		return
	_look = posmod(i, looks.size())
	world_env.environment = looks[_look].environment
	sun.light_color = looks[_look].sun_color
	sun.light_energy = looks[_look].sun_energy
	sun.rotation_degrees = looks[_look].sun_rotation_deg


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F:
			_auto = false
			var frozen: bool = _enemies[0].fx.is_frozen()
			_stagger_call("release" if frozen else "freeze")
		KEY_SPACE:
			_auto = not _auto
		KEY_P:
			_time_paused = not _time_paused
		KEY_L:
			_apply_look(_look + 1)
		KEY_C:
			camera.apply_preset(camera.preset_index + 1)
		_:
			return
	_refresh_label()


func _refresh_label() -> void:
	if label == null:
		return
	label.text = "冰冻特效测试（贴合敌人体型）　|　%s　|　%s%s\n[F] 冻结/碎冰  [空格] 自动循环开/关  [P] 暂停时间  [L] 白天/夜晚  [C] 机位  右键拖动旋转  滚轮缩放" % [
		looks[_look].display_name if not looks.is_empty() else "", camera.preset_name(), "　|　自动循环" if _auto else ""]
