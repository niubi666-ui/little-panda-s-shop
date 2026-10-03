"""Export one archived archer, baking armature constraints into a small action library."""
import bpy, json, math
from mathutils import Matrix, Vector
from pathlib import Path
root=Path('E:/ShopGame/source_assets/characters/elf_archer')
bpy.ops.wm.open_mainfile(filepath=str(root/'original/desktop_final_v001/Enemy_v4_ProLongbow39_BowString.blend'))
rig=bpy.data.objects['Enemy_v4_Rig_05']
keep={rig,*rig.children_recursive}
scene=bpy.data.scenes.new('EliteRangerRuntime')
bpy.context.window.scene=scene
for o in keep:scene.collection.objects.link(o)
rig.location=(0,0,0)
for o in keep:o.hide_set(False);o.hide_render=False
scene.render.fps=30
audit={'bones':[b.name for b in rig.pose.bones],'actions':{},'meshes':{},'images':[]}
specs={'idle':('Longbow_standing_idle_01',1,154),'move':('Longbow_standing_run_forward_InPlace',1,27),'draw':('Longbow_standing_draw_arrow',1,31),'aim':('Longbow_standing_aim_overdraw',1,60),'release':('Longbow_standing_aim_recoil',1,22),'roll':('Longbow_standing_dive_forward_InPlace',1,50),'hit':('Longbow_standing_react_small_from_front',1,39),'death':('Longbow_standing_death_backward_01',1,91),'rain':('Longbow_standing_aim_overdraw',1,60)}
specs['rain_release']=('Longbow_standing_aim_recoil',1,22)
actions=[]
for name,(source,start,end) in specs.items():
    print('BAKE_BEGIN',name,flush=True)
    original=bpy.data.actions[source]
    rig.animation_data.action=None
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    rig.animation_data.action=original
    if original.slots:rig.animation_data.action_slot=original.slots[0]
    samples=[]
    for frame in range(start,end+1):
        scene.frame_set(frame)
        pose={b.name:b.matrix.copy() for b in rig.pose.bones}
        # Transform the sampled hierarchy, without feeding overrides back into source evaluation.
        if name.startswith('rain'):
            spine=next((b for b in rig.pose.bones if b.name.endswith('Spine1')),None)
            if spine:
                pivot=spine.head.copy()
                amount=math.radians(-55)*min(1,(frame-start)/max(1,(end-start)*.45))
                if name=='rain_release':amount=math.radians(-55)*(1-(frame-start)/(end-start))
                lift=Matrix.Translation(pivot) @ Matrix.Rotation(amount,4,'X') @ Matrix.Translation(-pivot)
                for b in [spine,*spine.children_recursive]:pose[b.name]=lift @ pose[b.name]
        samples.append(pose)
    rig.animation_data.action=None
    new=bpy.data.actions.new(name);new.use_fake_user=True;rig.animation_data.action=new
    # Parent first. Existing bow skin/bones remain on this one skeleton.
    for index,pose in enumerate(samples,1):
        for b in rig.pose.bones:
            kwargs={'parent_matrix':pose[b.parent.name],'parent_matrix_local':b.parent.bone.matrix_local} if b.parent else {}
            b.matrix_basis=b.bone.convert_local_to_pose(pose[b.name],b.bone.matrix_local,invert=True,**kwargs)
            b.keyframe_insert('location',frame=index,group=b.name)
            b.keyframe_insert('rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler',frame=index,group=b.name)
            b.keyframe_insert('scale',frame=index,group=b.name)
    actions.append(new)
    audit['actions'][name]={'source':source,'frames':len(samples)}
for b in rig.pose.bones:
    for c in list(b.constraints):b.constraints.remove(c)
# Unassign showcase rigs before removing their unused source clips.
for o in bpy.data.objects:
    if o != rig and o.animation_data:o.animation_data_clear()
for a in list(bpy.data.actions):
    if a not in actions:bpy.data.actions.remove(a)
rig.animation_data.action=actions[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
scene.frame_set(1)
for o in keep:
    o.select_set(True)
    if o.type=='MESH':
        o.data.calc_loop_triangles();audit['meshes'][o.name]={'triangles':len(o.data.loop_triangles),'shape_keys':list(o.data.shape_keys.key_blocks.keys()) if o.data.shape_keys else []}
for img in bpy.data.images:
    if img.packed_file:audit['images'].append(img.name)
work=root/'blender/elite_ranger_v001.blend';work.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(work))
dest=Path('E:/ShopGame/game/assets/characters/elf_archer/elite_ranger_v001');dest.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(dest/'elite_ranger.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_apply=False,export_materials='EXPORT')
(root/'elite_ranger_v001/export_report.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf8')
print('RANGER_EXPORT',json.dumps(audit))
