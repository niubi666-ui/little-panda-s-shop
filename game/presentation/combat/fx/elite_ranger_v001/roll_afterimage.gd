extends Node3D
## Frozen GPU-skinned silhouettes. Shared immutable meshes/skins; independent poses.
var profile: Resource
var source: Node3D
var source_skeleton: Skeleton3D
var source_meshes: Array[MeshInstance3D]=[]
var pool: Array[Dictionary]=[]
var cursor:=0
var elapsed:=0.0
var was_rolling:=false
var last_position:=Vector3.ZERO
var enabled:=true
var emitted:=0
func configure(model: Node3D, settings: Resource) -> void:
	source=model;profile=settings
	assert(profile!=null and profile.valid())
	var skeletons:=source.find_children("*","Skeleton3D",true,false)
	assert(skeletons.size()==1,"Ranger afterimage expects the validated single skeleton")
	source_skeleton=skeletons[0]
	for mesh in source.find_children("*","MeshInstance3D",true,false):source_meshes.append(mesh)

func _create_image() -> Dictionary:
	var root:=Node3D.new();add_child(root);root.top_level=true;root.hide()
	var skeleton:=Skeleton3D.new();root.add_child(skeleton)
	for i in source_skeleton.get_bone_count():
		skeleton.add_bone(source_skeleton.get_bone_name(i))
		skeleton.set_bone_parent(i,source_skeleton.get_bone_parent(i))
		skeleton.set_bone_rest(i,source_skeleton.get_bone_rest(i))
	var material: ShaderMaterial=profile.material.duplicate()
	var meshes: Array[MeshInstance3D]=[]
	for original in source_meshes:
		var mesh:=MeshInstance3D.new();root.add_child(mesh)
		mesh.mesh=original.mesh;mesh.skin=original.skin
		mesh.skeleton=mesh.get_path_to(skeleton)
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		meshes.append(mesh)
	return {"root":root,"skeleton":skeleton,"meshes":meshes,"material":material,"age":0.0,"active":false}

func _snapshot() -> void:
	if pool.size()<profile.max_images:pool.append(_create_image())
	var image: Dictionary=pool[cursor]
	cursor=(cursor+1)%profile.max_images
	image.root.global_transform=source.global_transform
	image.skeleton.global_transform=source_skeleton.global_transform
	for i in source_skeleton.get_bone_count():
		image.skeleton.set_bone_pose_position(i,source_skeleton.get_bone_pose_position(i))
		image.skeleton.set_bone_pose_rotation(i,source_skeleton.get_bone_pose_rotation(i))
		image.skeleton.set_bone_pose_scale(i,source_skeleton.get_bone_pose_scale(i))
	image.skeleton.force_update_all_bone_transforms()
	for i in source_meshes.size():image.meshes[i].global_transform=source_meshes[i].global_transform
	image.age=0.0;image.active=true;image.root.show()
	image.material.set_shader_parameter("life",1.0)
	last_position=source.global_position
	emitted+=1

func refresh(delta: float, rolling: bool, alive: bool) -> void:
	if not enabled or not alive:
		clear();return
	if delta<=0.0:return
	for image in pool:
		if not image.active:continue
		image.age+=delta
		var life: float=maxf(0.0,1.0-image.age/profile.lifetime_sec)
		image.material.set_shader_parameter("life",life)
		if life<=0.0:image.active=false;image.root.hide()
	if rolling:
		elapsed+=delta
		if not was_rolling or (elapsed>=profile.interval_sec and source.global_position.distance_to(last_position)>=profile.minimum_distance_m):
			_snapshot();elapsed=0.0
	else:elapsed=0.0
	was_rolling=rolling

func clear() -> void:
	for image in pool:image.root.hide();image.active=false
	elapsed=0.0;was_rolling=false
func set_enabled(value: bool) -> void:
	enabled=value
	if not enabled:clear()
