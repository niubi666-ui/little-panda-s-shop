extends SceneTree
## Actual runtime mesh, input adapter, pose blending and sword VFX; optionally captures frames.
const Loader = preload("res://content/combat/combat_loader.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const BuildResolver = preload("res://combat/builds/build_resolver.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const OUT := "E:/ShopGame/builds/roll_slash_fast_review/"
const DT := 1.0/60
var p
var view
var camera: Camera3D
var failures: Array[String] = []
var checks := 0
var capture_enabled := false
var capture_index := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	capture_enabled = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(OUT)
	var catalog = Loader.new().load_catalog()
	p = Actor.new()
	var attacks: Array[Catalog.Ability] = []
	for id in catalog.player().attacks: attacks.append(catalog.ability(id))
	p.configure(catalog.player(), attacks, catalog.dodge(),1,0)
	root.add_child(p);p.collision_mask=0
	var resolver := BuildResolver.new();resolver.configure(BuildLoader.new().load_catalog())
	var program := resolver.resolve({"selections":[],"revision":0})
	p.set_action_program(program.actions,catalog)
	view=View.new();p.add_child(view)
	view.configure(p,load("res://presentation/combat/training_style.tres"),ThemeDB.fallback_font)
	camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.5
	var world := WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.14,.18,.16)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color(.6,.7,.75);world.environment.ambient_light_energy=.6
	root.add_child(world)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_color=Color(1,.88,.7);light.light_energy=1.6;light.shadow_enabled=true;root.add_child(light)
	var floor_node := MeshInstance3D.new();var mesh := PlaneMesh.new();mesh.size=Vector2(100,100);floor_node.mesh=mesh
	var mat := StandardMaterial3D.new();mat.albedo_color=Color(.25,.3,.26);floor_node.material_override=mat;root.add_child(floor_node)
	await process_frame
	check(view.visual.validate_assets(),"new clip, masks and anchors resolve")
	var input := InputAdapter.new(p,camera)
	# Ordinary rolls: input is free after forced motion; blend to running only after the landing pose.
	for dir in 8:
		p.cancel();p.runner.tick(5);p.position=Vector3.ZERO;p.dodge_left=0;p.dodge_age=0;p.charges=p.dodge.charges;p.facing=Vector3.FORWARD
		view.refresh(.3)
		p.movement=Vector3(sin(dir*TAU/8),0,-cos(dir*TAU/8));p.request_dodge()
		for frame in 44:
			await physics_frame;p.step(DT);view.refresh(DT)
			if p.dodge_age>p.dodge.movement_duration+.001:
				check(is_equal_approx(p.velocity.length(),p.definition.speed),"ordinary roll releases movement during stand-up")
			if p.dodge_age>p.dodge.duration*view.visual.nodachi.roll_locomotion_fraction:
				check(view.visual._clip in view.visual.nodachi.run_directions,"ordinary roll landing blends directly to running")
			if capture_enabled and dir in [0,2,4] and frame in [20,24,29,35,39,43]: await capture("normal_d%d_%02d"%[dir,frame])
	for dir in 8:
		for age in [.05,.28,.62]:
			p.cancel();p.runner.tick(5);p.position=Vector3.ZERO;p.dodge_left=0;p.charges=p.dodge.charges;p.facing=Vector3.FORWARD;p.movement=Vector3.ZERO
			view.refresh(.3)
			p.movement=Vector3(sin(dir*TAU/8),0,-cos(dir*TAU/8))
			p.request_dodge()
			while p.dodge_age < age or p.dodge_left <= 0:
				await physics_frame;p.step(DT);view.refresh(DT)
			p.movement=Vector3.ZERO
			if capture_enabled and ((dir in [0,2,4] and age==.28) or (dir==0 and age in [.05,.62])): await capture("d%d_a%d_roll"%[dir,roundi(age*100)])
			p.facing=Vector3.RIGHT if dir==2 else Vector3.FORWARD
			var press := InputEventAction.new();press.action="combat_attack";press.pressed=true;input.event(press)
			var previous_clip: StringName = view.visual._clip
			p.step(DT);view.refresh(DT)
			var skeleton: Skeleton3D = view.visual.skeleton
			var head := skeleton.find_bone("head")
			var previous: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head)
			p.step(0);view.refresh(0)
			var now: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head)
			check(previous.is_equal_approx(now),"pause preserves the continued roll pose")
			var continued_frames := 0
			var last_source_time := 0.0
			var saw_slash := false
			var exited_frames := 0
			for frame in 90:
				await physics_frame
				p.step(DT);view.refresh(DT)
				if not p.runner.busy():
					exited_frames += 1
					if exited_frames == 1: p.movement = Vector3.RIGHT
					if exited_frames == 2:
						check(is_equal_approx(p.velocity.x,p.definition.speed),"move immediately after slash")
						check(view.visual._clip in view.visual.nodachi.run_directions,"running pose starts without recovery clip")
				if p.roll_attack_finishing_roll():
					continued_frames += 1
					check(view.visual._clip==previous_clip,"retain original roll direction during landing")
					var source_time: float = view.visual.animation.current_animation_position
					check(source_time>last_source_time,"roll rotates forwards, never resets or freezes")
					check(is_equal_approx(source_time,p.roll_attack_roll_age()/p.dodge.duration*view.visual._length(previous_clip)),"sample exact continued native roll phase")
					last_source_time=source_time
				elif p.runner.busy() and not saw_slash:
					saw_slash=true
					check(view.visual._clip==&"roll_slash","requested UE counter starts after landing")
					check(p.roll_attack_roll_age()>=p.dodge.duration*p.dodge.attack_roll_exit_fraction-.001,"body completes at least landing fraction before switch")
				if p.runner.phase()=="active":
					check(view.visual._blend_left<.017,"landing blend settled by slash damage phase")
					check(view.blade.global_transform.is_equal_approx(view.visual.weapon_fx_transform()),"trail follows real weapon during dash")
				if capture_enabled and ((dir in [0,2,4] and age==.28) or (dir==0 and age in [.05,.62])) and frame in [0,2,4,6,8,10,12,14,16,18,20,22,24,27,30,34,40,48,60]:
					await capture("d%d_a%d_%02d"%[dir,roundi(age*100),frame])
			check(continued_frames>0 if age<.5 else continued_frames==0,"early click completes roll; late click goes straight to slash")
			check(not p.runner.busy(),"counter recovers to locomotion")
			p.dodge_age=0
	print("ROLL_SLASH_VISUAL ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func capture(label: String) -> void:
	camera.position=p.position+Vector3(4,3,-6)
	camera.look_at(p.position+Vector3.UP*.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
