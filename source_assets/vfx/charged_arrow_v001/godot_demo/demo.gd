extends Node3D
## Dedicated art playground: no main-game imports, services, combat actors or saves.
@export var art: Resource
const Rules = preload("res://rules.gd")
const Effect = preload("res://fx/lightseeker.gd")
var rules
var effect
var camera: Camera3D
var elf: Node3D
var target: Node3D
var elf_anim: AnimationPlayer
var target_anim: AnimationPlayer
var elf_clip := ""
var target_clip := ""
var target_previous := Vector3.ZERO
var font: Font
var texts: Dictionary
var language := "zh_CN"
var labels: Dictionary = {}
var buttons: Dictionary = {}
var hp_bar: ProgressBar
var charge_bar: ProgressBar
var slow_button: CheckButton
var floating: Label3D
var feedback_kind := ""
var feedback_damage := 0.0
var paused := false
var slow := false
var playback_scale := 1.0
var demo_mode := "stand"
var canvas: CanvasLayer

func _ready() -> void:
	art.validate()
	rules = Rules.new()
	rules.configure(Rules.load_config("res://data/demo_rules.json"), art.muzzle_offset)
	texts = JSON.parse_string(FileAccess.get_file_as_string("res://data/text.json"))
	font = load("res://assets/NotoSerifSC-VF.ttf")
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = art.camera_size
	camera.far = 180.0
	camera.position = art.camera_target+art.camera_offset
	add_child(camera)
	camera.look_at(art.camera_target)
	camera.current = true
	get_viewport().use_taa = true
	elf = art.elf_scene.instantiate()
	elf.scale = Vector3.ONE * art.elf_scale
	add_child(elf)
	elf.position = rules.vec(rules.config.stage.ranger_position)
	target = art.target_scene.instantiate()
	target.scale = Vector3.ONE * art.target_scale
	add_child(target)
	elf_anim = elf.find_child("AnimationPlayer",true,false)
	target_anim = target.find_child("AnimationPlayer",true,false)
	for player in [elf_anim,target_anim]:
		assert(player!=null)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	effect = Effect.new()
	add_child(effect)
	effect.configure(art,rules,camera,get_node("Courtyard"))
	rules.damaged.connect(_damage_feedback)
	floating = get_node("Floating")
	_ui()
	reset("stand")

func text(id: String, values: Dictionary = {}) -> String:
	assert(texts[language].has(id), "Missing translation: " + id)
	return texts[language][id].format(values)

func reset(mode: String) -> void:
	demo_mode = mode
	feedback_kind = ""
	rules.reset(mode)
	paused = false
	effect.pause_audio(false)
	effect.reset()
	target_previous = rules.target
	refresh()

func _process(delta: float) -> void:
	if paused: return
	var axis := Vector3.ZERO
	if demo_mode=="manual":
		axis = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var time_scale: float=art.slow_time_scale if slow else playback_scale
	for voice in effect.voices.values(): voice.pitch_scale=time_scale
	step(delta*time_scale,axis)

func step(delta: float, axis: Vector3 = Vector3.ZERO) -> void:
	rules.step(delta,axis)
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_R: reset(demo_mode)
		KEY_P: _pause()
		KEY_L: _language()
		KEY_SHIFT:
			if not paused:
				var axis := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
				rules.dodge(axis)
		KEY_ESCAPE: get_tree().quit()

func _pause() -> void:
	paused = not paused
	effect.pause_audio(paused)

func _language() -> void:
	language = "en" if language=="zh_CN" else "zh_CN"
	refresh()

func _damage_feedback(kind: String, amount: float, _timestamp: float) -> void:
	feedback_kind = kind
	feedback_damage = amount

func _sample(player: AnimationPlayer, clip: String, progress: float, previous: String) -> String:
	assert(player.has_animation(clip))
	if previous!=clip: player.play(clip)
	player.seek(clampf(progress,0.0,1.0)*player.get_animation(clip).length,true)
	return clip

func refresh() -> void:
	var p := clampf(rules.clock/rules.config.skill.charge_sec,0.0,1.0)
	var release_age: float = rules.clock-rules.fire_time if rules.fire_time>=0.0 else 0.0
	var clip := "idle"
	var progress: float = fmod(rules.clock/elf_anim.get_animation("idle").length,1.0)
	if rules.fire_time < 0.0:
		if p<art.draw_fraction:
			clip="draw";progress=p/art.draw_fraction
		else:
			clip="aim";progress=(p-art.draw_fraction)/(1.0-art.draw_fraction)
	elif release_age<art.release_sec:
		clip="release";progress=release_age/art.release_sec
	elf_clip = _sample(elf_anim,clip,progress,elf_clip)
	elf.basis = (Basis.looking_at(rules.direction,Vector3.UP)*Basis(Vector3.UP,PI)).scaled(Vector3.ONE*art.elf_scale)
	var movement: Vector3 = rules.target-target_previous
	target.position = rules.target
	var target_name := "run" if movement.length_squared()>0.000001 else "idle"
	var target_progress: float = fmod(rules.clock/target_anim.get_animation(target_name).length,1.0)
	target_clip = _sample(target_anim,target_name,target_progress,target_clip)
	var facing: Vector3 = movement.normalized() if movement.length_squared()>0.000001 else -rules.direction
	target.basis = (Basis.looking_at(facing,Vector3.UP)*Basis(Vector3.UP,PI/2.0)).scaled(Vector3.ONE*art.target_scale)
	target_previous = rules.target
	effect.refresh()
	floating.global_position = rules.target + Vector3.UP*art.label_height_m
	var hit_age: float = rules.clock-rules.last_damage_time
	floating.visible = feedback_kind!="" and hit_age<art.damage_flash_sec*3.0
	floating.text = text("arrow_hit" if feedback_kind=="arrow" else "pulse",{"damage":int(feedback_damage)})
	floating.modulate = art.arrow_label_color if feedback_kind=="arrow" else art.scar_label_color
	if rules.dodge_started and rules.arrow_count==0 and rules.clock>rules.config.skill.charge_sec and rules.clock<rules.dodge_ready:
		floating.visible=true;floating.text=text("avoided");floating.modulate=art.dodge_label_color
	_update_ui()

func _ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	var ui: Control = art.ui_scene.instantiate()
	canvas.add_child(ui)
	for id in ["title","subtitle","speed","phase","health","hits","note","help"]:
		labels[id] = ui.find_child(id,true,false)
		assert(labels[id]!=null, "Missing UI node: " + id)
	hp_bar = ui.get_node("Status/Values/Health")
	hp_bar.max_value = rules.config.target.health
	charge_bar = ui.get_node("Status/Values/Charge")
	for id in ["stand","walk","dodge","trail","manual","replay","pause","language"]:
		var button: Button = ui.find_child(id,true,false)
		buttons[id] = button
		if id in ["stand","walk","dodge","trail","manual"]: button.pressed.connect(reset.bind(id))
		elif id=="replay": button.pressed.connect(func():reset(demo_mode))
		elif id=="pause": button.pressed.connect(_pause)
		else: button.pressed.connect(_language)
	slow_button = ui.get_node("Footer/Rows/Hints/Slow")
	slow_button.toggled.connect(func(value: bool):slow=value)

func _update_ui() -> void:
	for id in ["title","subtitle","help"]: labels[id].text=text(id)
	var distance: float=rules.vec(rules.config.stage.target_position).distance_to(rules.vec(rules.config.stage.ranger_position))
	labels.speed.text=text("speed",{"speed":int(rules.config.skill.speed_mps),"distance":"%.1f"%distance,"travel":"%.2f"%(distance/rules.config.skill.speed_mps)})
	labels.note.text=text("note",{"duration":int(rules.config.skill.trail_duration_sec)})
	labels.health.text=text("health",{"hp":int(rules.health),"max":int(rules.config.target.health)})
	labels.hits.text=text("hits",{"arrow":rules.arrow_count,"ticks":rules.scar_count})
	var phase := "charge"
	if rules.fire_time>=0.0:
		phase="flight" if rules.clock-rules.fire_time<rules.config.skill.range_m/rules.config.skill.speed_mps else ("residue" if rules.scar_active() else "finished")
	elif rules.locked: phase="lock"
	labels.phase.text=text(phase,{"interval":rules.config.skill.trail_tick_sec})
	charge_bar.value=clampf(rules.clock/rules.config.skill.charge_sec,0.0,1.0)
	hp_bar.value=rules.health
	for id in buttons:
		buttons[id].text=text(id)
		if id in ["stand","walk","dodge","trail","manual"]: buttons[id].button_pressed=id==demo_mode
	slow_button.text=text("slow",{"scale":art.slow_time_scale})
