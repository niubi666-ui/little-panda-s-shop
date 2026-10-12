extends SceneTree
## 森林遗迹 v002 实战截图：真实出招命中敌人，截取命中瞬间。图形模式运行。
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena); current_scene = arena
	await create_timer(4.5).timeout          # 等第一波敌人入场
	arena.get_node("UIRoot").hide()
	var player = arena.player
	var enemy = null
	for a in arena.actors:
		if a != player and a.health.alive(): enemy = a; break
	if enemy == null:
		print("CAPTURE no enemy"); quit(1); return
	# 把敌人放到玩家正前方，打一套三连
	enemy.global_position = player.global_position + Vector3(0, 0, -1.6)
	player.facing = Vector3(0, 0, -1)
	var shots := 0
	var hp0: float = enemy.health.current
	for i in 3:
		player.request_attack()
		for f in 40:
			await physics_frame
			player.facing = (enemy.global_position - player.global_position).normalized() if enemy.health.alive() else player.facing
			if player.runner.phase() == "active" and arena.feel.in_hitstop() and shots == i:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_ruin_combat_%d.png" % i)
				shots += 1
		await create_timer(0.05).timeout
	print("CAPTURE shots=%d damage=%.0f" % [shots, hp0 - enemy.health.current])
	quit(0)
