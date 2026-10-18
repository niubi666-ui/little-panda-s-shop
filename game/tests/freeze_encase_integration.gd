extends SceneTree
## 冰冻状态表现接入检查（图形模式截图）：真实冻结 → 冰壳贴在敌人自己的网格上、冰晶长出、体型不同尺寸不同；
## 暂停时冰封不动；解冻后碎冰收尾播完再释放、敌人材质恢复。
## godot --path game --resolution 1280x800 --script res://tests/freeze_encase_integration.gd
const OUT := "E:/ShopGame/builds/freeze_encase_review/"
var arena
var player
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func step(delta: float = 1.0 / 60.0) -> void:
	if delta > 0.0:
		arena.builds.before_motion(delta)
		player.step(delta)
		arena.builds.step(delta)
	for v in arena.views: v.refresh(delta)
	arena.builds.refresh(delta)

func run() -> void:
	create_timer(180.0).timeout.connect(func(): push_error("FREEZE_ENCASE TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.encounter.cancel()
	arena.input_adapter.actor = null
	arena.get_node("UIRoot").hide()
	player = arena.player
	player.collision_mask = 0
	player.position = Vector3(0, player.position.y, 2.5)
	var enemies: Array = arena.actors.filter(func(a): return a != player and a.health.alive())
	check(enemies.size() >= 2, "training room has at least two enemies")
	for i in enemies.size():
		enemies[i].position = Vector3(60, 0, 60)
	var targets: Array = enemies.slice(0, 2)
	for i in targets.size():
		targets[i].position = Vector3(-1.2 + 2.4 * i, 0, 0)
		targets[i].health.current = targets[i].health.maximum
	var camera: Camera3D = arena.get_node("Camera")
	camera.global_position = Vector3(0, 3.2, 5.5)
	camera.look_at(Vector3(0, 0.8, 0))
	for i in 10:
		step()
		await process_frame
	var statuses = arena.builds.runtime.statuses
	for t in targets:
		for attempt in 4:
			if t.control_locked: break
			statuses.apply(t, "test_freeze", 3.0, {})
		check(t.control_locked, "enemy frozen: " + t.definition.id)
	for i in 30:
		step()
		await process_frame
	var mech = arena.builds.mechanisms
	var fx_nodes: Array = []
	for t in targets:
		var entry = mech._statuses.get(t.handle)
		var fx = entry.node if entry != null else null
		check(fx != null and fx.has_method("is_frozen") and fx.is_frozen(), "freeze encase active: " + t.definition.id)
		if fx == null or not fx.has_method("is_frozen"): continue
		fx_nodes.append(fx)
		check(fx._meshes.size() > 0 and fx._meshes.all(func(m): return m.material_overlay == fx._shell), "ice shell on the enemy's own meshes: " + t.definition.id)
		check(fx._crystals.size() >= 6, "crystals grown on the body: " + t.definition.id)
		check(fx._base.size() >= 5, "ice spikes around the feet: " + t.definition.id)
		check(absf(fx.global_position.y - t.global_position.y) < 0.05, "ice sits on the ground: " + t.definition.id)
		print("  %s height=%.2f radius=%.2f crystals=%d base=%d" % [t.definition.id, fx._height, fx._radius, fx._crystals.size(), fx._base.size()])
	await shot("frozen")
	# 暂停：冰封的时钟和粒子都停
	if not fx_nodes.is_empty():
		var age: float = fx_nodes[0]._t
		for i in 10:
			step(0.0)
			await process_frame
		check(is_equal_approx(age, fx_nodes[0]._t), "pause freezes the ice")
		check(fx_nodes[0].shards.speed_scale == 0.0, "pause freezes ice particles")
	# 解冻：碎冰收尾，播完释放，材质恢复
	var visual_meshes: Array = []
	for fx in fx_nodes: visual_meshes.append_array(fx._meshes)
	var shattered := false
	for i in 360:
		step()
		if not shattered and not mech._tails.is_empty():
			shattered = true
			for k in 6:
				step()
				await process_frame
			await shot("shatter")
		if shattered and mech._tails.is_empty(): break
		await process_frame
	check(shattered, "thaw plays the shatter tail")
	check(mech._tails.is_empty(), "shatter tail released after it finishes")
	check(visual_meshes.all(func(m): return not is_instance_valid(m) or m.material_overlay == null or not (m.material_overlay is ShaderMaterial and m.material_overlay.shader.resource_path.ends_with("ice_shell.gdshader"))), "enemy materials restored")
	print("FREEZE_ENCASE checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
