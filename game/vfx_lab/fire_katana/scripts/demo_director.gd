extends Node3D
## 火焰太刀演示：循环播放几招挥砍，命中木桩时生成火焰受击特效、顿帧、震镜头。
## 按键：E 切换元素（火/冰/雷/土），空格 暂停/继续，1-4 只放某一招，0 循环全部，S 慢放，L 白天/夜晚，C 切换机位。

@export var rig: Node3D
@export var impact_scene: PackedScene
@export var moves: Array[Resource] = []
@export var camera: Camera3D
@export var target_post: Node3D
@export var label: Label
@export var world_env: WorldEnvironment
@export var sun: DirectionalLight3D
@export var looks: Array[Resource] = []
@export var slow_scale := 0.3
## 元素切换（E 键）：fire 用本场景原有的火焰层；其它元素挂 enchant_mount 下的附魔场景
@export var element_ids: PackedStringArray = ["fire", "ice", "thunder", "earth"]
@export var element_names: PackedStringArray = ["火", "冰", "雷", "土"]
@export var element_enchants: Dictionary = {}     ## 元素 → 附魔场景（enchant_base.gd 约定）
@export var element_impacts: Dictionary = {}      ## 元素 → 受击场景；没有就用 impact_scene
@export var blade_overlays: Dictionary = {}       ## 元素 → 刀身覆盖层材质（刀身材质的 next_pass）
@export var enchant_mount: Node3D                 ## 刀身中点、刀尖朝 -Z
@export var blade_length := 0.71
@export var blade_fx: Node3D
@export var fire_trail: Node3D
@export var katana_mesh: MeshInstance3D

var _index := 0
var _solo := -1
var _paused := false
var _slow := false
var _look := 0
var _in_hitstop := false
var _element := 0
var _enchant: Node3D


func _ready() -> void:
	# 在挥刀（katana_rig）更新完刀的姿态之后再驱动附魔
	process_priority = 10
	rig.contact.connect(_on_contact)
	rig.phase_changed.connect(func(_p, _m): _refresh_label())
	_apply_look(0)
	_set_element(0)
	# 录屏用的命令行开关（-- look=1 camera=1 move=4）
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"look": _apply_look(int(kv[1]))
			"camera": camera.apply_preset(int(kv[1]))
			"move": _solo = int(kv[1]) - 1
			"element": _set_element(maxi(element_ids.find(kv[1]), 0))
			"slow":
				_slow = kv[1] == "1"
				Engine.time_scale = slow_scale if _slow else 1.0
	_refresh_label()
	_run()


func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	while is_inside_tree():
		if _paused or moves.is_empty():
			await get_tree().process_frame
			continue
		var i := _solo if _solo >= 0 else _index
		await rig.play_move(moves[i])
		if _solo < 0:
			_index = (_index + 1) % moves.size()


func _set_element(i: int) -> void:
	_element = posmod(i, element_ids.size())
	var id := element_ids[_element]
	if is_instance_valid(_enchant):
		_enchant.queue_free()
	_enchant = null
	if element_enchants.has(id):
		_enchant = element_enchants[id].instantiate()
		enchant_mount.add_child(_enchant)
		_enchant.configure_blade(blade_length)
	blade_fx.set_enabled(id == "fire")
	fire_trail.visible = id == "fire"
	var blade_mat: ShaderMaterial = katana_mesh.get_surface_override_material(0)
	blade_mat.next_pass = blade_overlays.get(id, null)


func _process(delta: float) -> void:
	if is_instance_valid(_enchant):
		_enchant.set_power(rig.heat())
		_enchant.tick(delta)


func _on_contact(pos: Vector3, tangent: Vector3, blade_dir: Vector3, out_dir: Vector3, move: Resource) -> void:
	var scene: PackedScene = element_impacts.get(element_ids[_element], impact_scene)
	var fx: Node3D = scene.instantiate()
	add_child(fx)
	var x := tangent.normalized()
	var y := (blade_dir - x * blade_dir.dot(x)).normalized()
	var z := x.cross(y)
	fx.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * move.impact_scale), pos)
	fx.play()
	target_post.hit(tangent * 0.6 - out_dir, move.intensity)
	camera.shake(move.shake)
	if move.hitstop > 0.0 and not _in_hitstop:
		_hitstop(move.hitstop)


func _hitstop(duration: float) -> void:
	_in_hitstop = true
	Engine.time_scale = 0.03
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = slow_scale if _slow else 1.0
	_in_hitstop = false


func _apply_look(i: int) -> void:
	if looks.is_empty():
		return
	_look = posmod(i, looks.size())
	var look: Resource = looks[_look]
	world_env.environment = look.environment
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy
	sun.rotation_degrees = look.sun_rotation_deg


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_0:
			_solo = -1
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i: int = event.keycode - KEY_1
			if i < moves.size():
				_solo = i
		KEY_S:
			_slow = not _slow
			if not _in_hitstop:
				Engine.time_scale = slow_scale if _slow else 1.0
		KEY_L:
			_apply_look(_look + 1)
		KEY_E:
			_set_element(_element + 1)
		KEY_C:
			camera.apply_preset(camera.preset_index + 1)
		_:
			return
	_refresh_label()


func _refresh_label() -> void:
	if label == null:
		return
	var cur := "—"
	var i := _solo if _solo >= 0 else _index
	if i < moves.size():
		cur = moves[i].display_name
	var look_name: String = looks[_look].display_name if not looks.is_empty() else ""
	label.text = "元素太刀 · 特效演示（%s）\n当前招式：%s%s%s　|　%s　|　%s\n[E] 切换元素  [空格] 暂停  [1-4] 单招  [0] 循环  [S] 慢放  [L] 白天/夜晚  [C] 机位  右键拖动旋转  滚轮缩放" % [
		element_names[_element], cur, "（单招）" if _solo >= 0 else "", "（暂停）" if _paused else "", look_name, camera.preset_name()]
