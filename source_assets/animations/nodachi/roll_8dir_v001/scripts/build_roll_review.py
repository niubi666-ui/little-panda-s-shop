import bpy,json,math,csv,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/roll_8dir_v001')
src=json.loads((ROOT/'reports/ue_export.json').read_text(encoding='utf-8'))
assert len(src['exports'])==8 and not src['errors']
s=bpy.context.scene
s.name='Nodachi_Roll_8_Directions_IP'
rig=bpy.data.objects['Nodachi_Manny_Rig']
body=bpy.data.objects['Nodachi_Manny_Preview']
sword=bpy.data.objects['Nodachi_Sword_SourceSocket']
follow=bpy.data.objects['Review_Camera_Follow_Pelvis_XY']
rig.animation_data_clear()
follow.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
for m in list(s.timeline_markers): s.timeline_markers.remove(m)
for text in list(bpy.data.texts): bpy.data.texts.remove(text)
for c in list(follow.constraints): follow.constraints.remove(c)
follow.location=(0,0,0)
# Fixed camera makes the original in-place body trajectory visible.
s.camera.location=(-4.2,-6.5,3.0)
s.camera.rotation_euler=(Vector((0,0,1.05))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=5.4
report={'variant':'IP','fps':60,'source_skeleton':src['exports'][0]['skeleton'],'clips':[],
        'godot_note':'CharacterBody3D/gameplay drives translation; animation uses source IP variant. UE Manny skeleton, retarget required for a different rig.'}
actions=[]
def curves(a):
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves
for e in src['exports']:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=e['file'],use_anim=True,automatic_bone_orientation=False)
    objects=set(bpy.data.objects)-before
    arm=next(o for o in objects if o.type=='ARMATURE')
    a=arm.animation_data.action
    fps=s.render.fps/s.render.fps_base
    assert all(b.name in rig.data.bones for b in arm.data.bones)
    delta=max(abs(x-y) for b in arm.data.bones for row1,row2 in zip(b.matrix_local,rig.data.bones[b.name].matrix_local) for x,y in zip(row1,row2))
    assert delta<.001
    if fps!=60:
        for fc in curves(a):
            for key in fc.keyframe_points:
                for co in (key.co,key.handle_left,key.handle_right): co.x=1+(co.x-1)*60/fps
            fc.update()
    a.name=e['action']
    a.use_fake_user=True
    end=1+round(e['sequence_length']*60)
    a.use_frame_range=True
    a.frame_start=1
    a.frame_end=end
    a.use_cyclic=False
    a['source_asset']=e['asset']
    a['source_seconds']=e['sequence_length']
    a['direction']=e['direction']
    a['variant']='IP'
    a.asset_mark()
    a.asset_data.description=f"{e['label_zh']}翻滚 | {e['sequence_length']:.3f}s | source in-place combat roll | 60 FPS"
    for tag in ('Nodachi','Roll','IP',e['direction']): a.asset_data.tags.new(tag,skip_if_exists=True)
    arm_data=arm.data
    for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
    if arm_data.users==0: bpy.data.armatures.remove(arm_data)
    actions.append(a)
    report['clips'].append({'action':a.name,'direction':e['direction'],'label_zh':e['label_zh'],
          'source_seconds':e['sequence_length'],'duration_seconds_60fps':(end-1)/60,'source_fps':fps,'action_frames':[1,end],
          'source_asset':e['asset'],'source_fbx':e['file'],'max_rest_matrix_delta':delta})

s.render.fps=60
s.render.fps_base=1
rig.animation_data_create()
for a,r in zip(actions,report['clips']):
    rig.animation_data.action=a
    rig.animation_data.action_slot=a.slots[0]
    samples=[]
    root_points=[]
    start,end=r['action_frames']
    for f in range(start,end+1):
        s.frame_set(f)
        # UE FBX root is imported as this armature object, not a pose bone.
        root=rig.matrix_world.translation
        root_points.append(list(root))
        if f in {start,start+round((end-start)*.25),start+round((end-start)*.5),start+round((end-start)*.75),end}:
            ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            verts=[list(ev.matrix_world@ev.data.vertices[k].co) for k in (0,5000,20000,40000)]
            assert all(math.isfinite(x) for v in verts for x in v)
            samples.append({'frame':f,'vertices':verts,'sword_origin':list(sword.matrix_world.translation),
                           'pelvis':list(rig.matrix_world@rig.pose.bones['pelvis'].matrix.translation)})
    root_span=[max(p[k] for p in root_points)-min(p[k] for p in root_points) for k in range(3)]
    assert max(root_span[:2])<.05,(a.name,root_span)
    movement=max((Vector(p['vertices'][k])-Vector(samples[0]['vertices'][k])).length for p in samples[1:] for k in range(4))
    assert movement>.05,(a.name,movement)
    r.update(root_xyz_span_m=root_span,root_node='Nodachi_Manny_Rig (FBX root object)',skin_motion_m=movement,samples=samples)
rig.animation_data.action=None
track=rig.animation_data.nla_tracks.new()
track.name='八方向翻滚 | 前 右前 右 右后 后 左后 左 左前'
start=1
for a,r in zip(actions,report['clips']):
    st=track.strips.new(a.name,start,a)
    st.action_slot=a.slots[0]
    st.action_frame_start=1
    st.action_frame_end=r['action_frames'][1]
    st.frame_end=start+r['action_frames'][1]-1
    st.extrapolation='HOLD_FORWARD'
    st.blend_type='REPLACE'
    st.use_auto_blend=False
    st.blend_in=st.blend_out=0
    r['review_frames']=[start,round(st.frame_end)]
    s.timeline_markers.new(r['label_zh']+' | '+a.name,frame=start)
    start=round(st.frame_end)+31
s.frame_start=1
s.frame_end=round(track.strips[-1].frame_end)
s.use_preview_range=False
s.sync_mode='FRAME_DROP'
s.frame_set(1)
report['review_frames']=[s.frame_start,s.frame_end]
report['blend_file']=str(ROOT/'blender/nodachi_roll_8dir.blend')
report['glb_file']=str(ROOT/'godot/nodachi_roll_8dir.glb')
instructions='八方向战斗翻滚 / NODACHI ROLL 8 DIRECTIONS\n\n空格播放/暂停。时间轴依次：前 → 右前 → 右 → 右后 → 后 → 左后 → 左 → 左前。\n'
instructions+='\n'.join(f"{r['review_frames'][0]}–{r['review_frames'][1]} | {r['label_zh']} | {r['action']} | {r['duration_seconds_60fps']:.3f}s" for r in report['clips'])
instructions+='\n\n8 个非循环 Action，统一 60 FPS，保持原始速度。NLA 间隔只供预览。\n采用源动作包 IP 原地版：Godot 的角色控制器负责翻滚位移与碰撞，动画负责姿势。\n不要仅靠动画决定无敌时段、消耗和冷却，数值需由玩法 JSON 配置。\nGLB 中仅有角色骨架、预览人形和武器，以及 8 个独立动画，不含预览相机地面灯光。\n源骨架为 UE Manny；如目标角色骨架不同，需要先重定向。\n本轮未修改 game/ 或接入现有角色。\nFBX 源文件见 fbx/；方向与时长清单见 reports/directions.csv。\n'
bpy.data.texts.new('START_HERE.txt').write(instructions)
(ROOT/'README.txt').write_text(instructions,encoding='utf-8-sig')
with (ROOT/'reports/directions.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.writer(f)
    w.writerow(['direction','label_zh','action','source_seconds','review_start','review_end','variant','source_asset'])
    for r in report['clips']: w.writerow([r['direction'],r['label_zh'],r['action'],r['duration_seconds_60fps'],*r['review_frames'],'IP',r['source_asset']])
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.overlay.show_overlays=False
            ar.spaces.active.region_3d.view_perspective='CAMERA'
        elif ar.type=='NLA_EDITOR': ar.spaces.active.dopesheet.show_only_selected=True
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=report['blend_file'],compress=True)

# Export actions independently, not the combined review timeline.
rig.animation_data_clear()
rig.animation_data_create()
rig.animation_data.action=actions[0]
rig.animation_data.action_slot=actions[0].slots[0]
for obj in (rig,body,sword): obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=report['glb_file'],export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,
    export_merge_animation='ACTION',export_frame_range=False,export_anim_slide_to_zero=True,
    export_reset_pose_bones=True,export_skins=True,export_def_bones=False,export_leaf_bone=False,
    export_extras=True,export_yup=True,export_cameras=False,export_lights=False,
    export_influence_nb=8)
with open(report['glb_file'],'rb') as f:
    header=f.read(12)
    assert header[:4]==b'glTF'
    length,kind=struct.unpack('<II',f.read(8))
    doc=json.loads(f.read(length))
animations=doc.get('animations',[])
assert {x['name'] for x in animations}=={a.name for a in actions},[x['name'] for x in animations]
for a in animations:
    duration=max(doc['accessors'][sampler['input']]['max'][0] for sampler in a['samplers'])
    expected=next(r['duration_seconds_60fps'] for r in report['clips'] if r['action']==a['name'])
    assert abs(duration-expected)<.002,(a['name'],duration,expected)
report['glb_animations']=[{'name':a['name'],'channels':len(a['channels'])} for a in animations]
report['glb_node_count']=len(doc['nodes'])
report['glb_skin_joints']=[len(skin['joints']) for skin in doc['skins']]
(ROOT/'reports/blender_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('ROLL_BUILD_DONE',json.dumps({'blend':report['blend_file'],'glb':report['glb_file'],'actions':len(animations)}),flush=True)
