# Read-only copy of the actual game protagonist, using its current visual scale.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='E:/ShopGame/game/assets/characters/red_panda/red_panda_v008.glb')
imported=[o for o in bpy.data.objects if o not in before]
player_root=kit.root('Player_scale_reference',(1.3,-2.7,.03),'Scale_Reference');player_root.scale=(1.20058629,)*3;player_root.rotation_euler.z=.35
for o in imported:
 for col in list(o.users_collection):col.objects.unlink(o)
 kit.collection('Scale_Reference').objects.link(o)
 if not o.parent:o.parent=player_root
 if o.animation_data:
  for track in o.animation_data.nla_tracks:track.mute=True
  action=next((a for a in bpy.data.actions if a.name.lower().startswith('idle')),None)
  if action:
   o.animation_data.action=action
   if action.slots:o.animation_data.action_slot=action.slots[0]
s.frame_set(1)
bpy.context.view_layer.update()
rig=next(o for o in imported if o.type=='ARMATURE')
hand_position=rig.matrix_world@rig.pose.bones['R_Hand'].head
# Bake just the preview actor's evaluated meshes; retain sources elsewhere untouched.
player_meshes=[]
for o in imported:
 if o.type=='MESH' and o.name.startswith('RedPandaMesh'):
  dep=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(dep);me=bpy.data.meshes.new_from_object(ev,depsgraph=dep)
  clone=bpy.data.objects.new('Player_reference_'+o.name,me);kit.collection('Scale_Reference').objects.link(clone);clone.matrix_world=o.matrix_world.copy();player_meshes.append(clone)
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.objects.remove(player_root,do_unlink=True)
points=[o.matrix_world@v.co for o in player_meshes for v in o.data.vertices]
player_min=min(v.z for v in points);player_max=max(v.z for v in points)
for o in player_meshes:o.location.z+=.035-player_min
player_height=player_max-player_min
hand_position.z+=.035-player_min
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='E:/ShopGame/game/assets/weapons/longsword_v001/longsword.glb')
weapon_objects=[o for o in bpy.data.objects if o not in before]
rotation=Vector((0,1,0)).rotation_difference(Vector((.72,-.58,-.38)).normalized()).to_matrix().to_4x4()
transform=Matrix.Translation(hand_position)@rotation@Matrix.Translation((0,.675,0))
for o in weapon_objects:
 for c in list(o.users_collection):c.objects.unlink(o)
 kit.collection('Scale_Reference').objects.link(o);o.matrix_world=transform@o.matrix_world;o.name='Player_sword_'+o.name
 o['source_file']='game/assets/weapons/longsword_v001/longsword.glb';o['purpose']='Read-only visual scale reference'

