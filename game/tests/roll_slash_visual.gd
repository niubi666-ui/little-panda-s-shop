extends SceneTree
## Actual runtime mesh, input adapter, pose blending and sword VFX; optionally captures frames.
const Loader = preload("res://content/combat/combat_loader.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const BuildResolver = preload("res://combat/builds/build_resolver.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const OUT := "E:/ShopGame/builds/roll_slash_review/"
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
	for dir in 8:
		for age in [.05,.28,.62]:
			p.cancel();p.runner.tick(5);p.position=Vector3.ZERO;p.dodge_left=0;p.charges=p.dodge.charges;p.facing=Vector3.FORWARD;p.movement=Vector3.ZERO
			view.refresh(.3)
			p.movement=Vector3(sin(dir*TAU/8),0,-cos(dir*TAU/8))
			p.request_dodge()
			while p.dodge_age < age or p.dodge_left <= 0:
				await physics_frame;p.step(DT);view.refresh(DT)
			p.movement=Vector3.ZERO
			if capture_enabled and dir in [0,2] and age==.28: await capture("d%d_roll"%dir)
			p.facing=Vector3.RIGHT if dir==2 else Vector3.FORWARD
			var press := InputEventAction.new();press.action="combat_attack";press.pressed=true;input.event(press)
			p.step(DT)
			var skeleton: Skeleton3D = view.visual.skeleton
			var head := skeleton.find_bone("head")
			var previous: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head)
			view.refresh(0)
			var now: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head)
			check(previous.origin.distance_to(now.origin)<.001,"zero-time transition preserves head position dir%s age%s"%[dir,age])
			check(view.visual._blend_total>=.16,"roll-specific blend replaces short ordinary attack blend")
			check(view.visual._transition_weight(skeleton.find_bone("spine_02"),.1,.17)>view.visual._transition_weight(skeleton.find_bone("thigh_l"),.1,.17),"upper/lower body use independent convergence")
			for frame in 58:
				await physics_frame
				p.step(DT);view.refresh(DT)
				if frame==11:
					check(view.visual._blend_left==0,"pose fully settled before active slash")
					check(view.visual._clip==&"roll_slash","requested UE counter clip active")
				if p.runner.phase()=="active":
					check(view.blade.global_transform.is_equal_approx(view.visual.weapon_fx_transform()),"trail follows real weapon during dash")
				if capture_enabled and dir in [0,2] and age==.28 and frame in [0,2,4,6,8,10,13,17,21,25,34,48]:
					await capture("d%d_%02d"%[dir,frame])
			check(not p.runner.busy(),"counter recovers to locomotion")
			p.dodge_age=0
	print("ROLL_SLASH_VISUAL ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func capture(label: String) -> void:
	camera.position=p.position+Vector3(4,3,-6)
	camera.look_at(p.position+Vector3.UP*.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
