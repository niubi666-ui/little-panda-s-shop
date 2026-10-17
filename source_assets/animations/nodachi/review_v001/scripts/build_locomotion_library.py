import bpy, json, math, csv, time
from pathlib import Path
from mathutils import Vector

ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
base_scene=bpy.context.scene
base_rig=bpy.data.objects['Nodachi_Manny_Rig']
base_body=bpy.data.objects['Nodachi_Manny_Preview']
base_sword=bpy.data.objects['Nodachi_Sword_SourceSocket']
base_camera=base_scene.camera
source=json.loads((ROOT/'reports/locomotion_ue_export.json').read_text())
assert len(source['exports'])==194 and not source['errors']
report={'target_fps':60,'source_count':194,'imports':[],'scenes':[], 'new_unique_actions':0,
        'source_skeleton':source['exports'][0]['skeleton'],
        'scope':'Source Manny review. Movement uses supplied IP variants. No retarget or Godot integration.'}

def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves

def write_report():
    (ROOT/'reports/locomotion_blender_library.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

actions={}
entries={e['name']:e for e in source['exports']}
for i,entry in enumerate(source['exports']):
    assert entry['ok'] and Path(entry['file']).is_file()
    row={k:entry[k] for k in ('name','asset','category','variant','file','sequence_length')}
    if entry['name']=='AS_Idle_Combat_Seq':
        action=bpy.data.actions['Nodachi_00_Combat_Idle']
        row.update(reused_existing=True,rest_pose_matches=True)
    else:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=entry['file'],use_anim=True,automatic_bone_orientation=False)
        objects=set(bpy.data.objects)-before
        arm=next(o for o in objects if o.type=='ARMATURE')
        action=arm.animation_data.action
        source_fps=base_scene.render.fps/base_scene.render.fps_base
        original_range=list(action.frame_range)
        action.name=entry['name'].replace('AS_','Nodachi_',1).removesuffix('_Seq')
        action.use_fake_user=True
        missing=[b.name for b in arm.data.bones if b.name not in base_rig.data.bones]
        assert not missing,(entry['name'],missing)
        max_delta=max(abs(x-y) for b in arm.data.bones for r1,r2 in zip(b.matrix_local,base_rig.data.bones[b.name].matrix_local) for x,y in zip(r1,r2))
        assert max_delta<.001,(entry['name'],max_delta)
        if abs(source_fps-60)>.0001:
            for fc in curves(action):
                for key in fc.keyframe_points:
                    for co in (key.co,key.handle_left,key.handle_right):
                        co.x=1+(co.x-1)*60/source_fps
                fc.update()
        action['source_asset']=entry['asset']
        action['source_seconds']=entry['sequence_length']
        action['import_fps']=source_fps
        # Sample real skin deformation using the imported rig before discarding it.
        check_body=base_body.copy()
        check_body.name='TEMP_SKIN_VALIDATION'
        base_scene.collection.objects.link(check_body)
        check_body.parent=arm
        for modifier in check_body.modifiers:
            if modifier.type=='ARMATURE': modifier.object=arm
        end=1+round(entry['sequence_length']*60)
        poses=[]
        for factor in (0,.29,.63,.91):
            f=1+round((end-1)*factor)
            base_scene.frame_set(f)
            dg=bpy.context.evaluated_depsgraph_get()
            ev=check_body.evaluated_get(dg)
            samples=[list(ev.matrix_world@ev.data.vertices[k].co) for k in (0,5000,20000,40000)]
            bones={n:list(arm.matrix_world@arm.pose.bones[n].matrix.translation) for n in ('pelvis','head','hand_r','foot_l')}
            assert all(math.isfinite(x) for p in samples for x in p)
            poses.append({'frame':f,'vertices':samples,'bones':bones})
        movement=max((Vector(p['vertices'][k])-Vector(poses[0]['vertices'][k])).length for p in poses[1:] for k in range(4))
        assert movement>1e-6,(entry['name'],'No skin deformation')
        bpy.data.objects.remove(check_body,do_unlink=True)
        arm_data=arm.data
        for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
        if arm_data.users==0: bpy.data.armatures.remove(arm_data)
        row.update(reused_existing=False,import_fps=source_fps,original_frame_range=original_range,
                   rest_pose_matches=True,max_rest_matrix_delta=max_delta,skin_motion_m=movement,motion_samples=poses)
        report['new_unique_actions']+=1
    action.use_fake_user=True
    action['category']=entry['category']
    action['movement_variant']=entry['variant']
    if not action.asset_data: action.asset_mark()
    action.asset_data.description=f"Nodachi {entry['category']}; {entry['variant']}; {entry['sequence_length']:.3f}s at 60 FPS. {entry['asset']}"
    for tag in ('Nodachi',entry['category'],entry['variant']):
        action.asset_data.tags.new(tag,skip_if_exists=True)
    actions[entry['name']]=action
    row['action']=action.name
    row['action_range']=list(action.frame_range)
    row['playback_range']=[1,1+round(entry['sequence_length']*60)]
    report['imports'].append(row)
    if (i+1)%10==0 or i==193:
        write_report()
        print(f'LOCOMOTION_IMPORTED {i+1}/194',flush=True)

base_scene.render.fps=60
base_scene.render.fps_base=1
base_scene.name='01_Attacks_Attack01_Attack05'
base_scene.use_preview_range=False
base_scene.sync_mode='FRAME_DROP'
base_scene['category_zh']='原有攻击：Attack01、Attack05'
base_scene['instructions_zh']='空格播放暂停；右上场景下拉切换类别。NLA 分段仅用于浏览；源动作保存在 Actions。'
base_scene.frame_set(1)
attack_rows=[]
for strip in base_rig.animation_data.nla_tracks[0].strips:
    action=strip.action
    action.use_fake_user=True
    if not action.asset_data: action.asset_mark()
    attack_rows.append({'action':action.name,'timeline':[round(strip.frame_start),round(strip.frame_end)],
                        'source_seconds':action.get('source_seconds'),'repeat':1})
report['scenes'].append({'name':base_scene.name,'label':'Attack01 和 Attack05 原有攻击','clips':attack_rows,'frame_end':base_scene.frame_end})

category_specs=[
 ('01_idle','02_Idle_and_Stance','待机与战斗姿态切换'),
 ('02_walk_normal','03_Walk_Normal','普通姿态多方向步行'),
 ('03_walk_combat','04_Walk_Combat','战斗姿态多方向步行'),
 ('04_walk_block','05_Walk_Block','格挡姿态多方向步行'),
 ('05_walk_transitions','06_Walk_Transitions','步行姿态切换'),
 ('06_run_normal','07_Run_Normal_and_Sprint','普通跑步与冲刺'),
 ('07_run_combat','08_Run_Combat_and_Sprint','战斗跑步与冲刺'),
 ('08_run_transitions','09_Run_Transitions','跑步姿态切换'),
 ('09_turn_normal','10_Turn_Normal','普通姿态原地转身'),
 ('10_turn_combat','11_Turn_Combat','战斗姿态原地转身'),
 ('11_turn_block','12_Turn_Block','格挡姿态原地转身'),
]
static_objects=[o for o in base_scene.objects if o.type=='LIGHT' or o.name=='Review_Ground']
new_rigs={}
manifest=[]

def make_scene(name,label,sequence):
    s=bpy.data.scenes.new(name)
    s.world=base_scene.world
    s.render.engine='CYCLES'
    s.cycles.samples=24
    s.cycles.use_denoising=True
    s.render.resolution_x=960
    s.render.resolution_y=640
    s.render.resolution_percentage=100
    s.render.fps=60
    s.render.fps_base=1
    s.view_settings.view_transform=base_scene.view_settings.view_transform
    s.view_settings.look=base_scene.view_settings.look
    s.view_settings.exposure=base_scene.view_settings.exposure
    s.use_preview_range=False
    s.sync_mode='FRAME_DROP'
    s['category_zh']=label
    s['instructions_zh']='空格播放暂停；右上场景下拉切换类别。循环动作在预览中重复两次，源 Action 保持原时长。'
    for o in static_objects: s.collection.objects.link(o)
    rig=base_rig.copy()
    rig.name=name+' | Manny_Rig'
    rig.animation_data_clear()
    s.collection.objects.link(rig)
    body=base_body.copy()
    body.name=name+' | Manny_Body'
    s.collection.objects.link(body)
    body.parent=rig
    for m in body.modifiers:
        if m.type=='ARMATURE': m.object=rig
    sword=base_sword.copy()
    sword.name=name+' | Nodachi_Sword'
    s.collection.objects.link(sword)
    sword.parent=rig
    follower=bpy.data.objects.new(name+' | Camera_Follow',None)
    s.collection.objects.link(follower)
    con=follower.constraints.new('COPY_LOCATION')
    con.target=rig
    con.subtarget='pelvis'
    con.use_x=True
    con.use_y=True
    con.use_z=False
    con.target_space='WORLD'
    con.owner_space='WORLD'
    cam=base_camera.copy()
    cam.name=name+' | Camera'
    cam.animation_data_clear()
    cam.parent=follower
    s.collection.objects.link(cam)
    s.camera=cam
    rig.animation_data_create()
    track=rig.animation_data.nla_tracks.new()
    track.name=label
    start=1
    clip_rows=[]
    for spec in sequence:
        key=spec['key']
        action=actions[key] if key in actions else bpy.data.actions[key]
        source_seconds=float(action.get('source_seconds',0))
        frames=round(source_seconds*60)
        if spec.get('seconds') is not None: frames=min(frames,round(spec['seconds']*60))
        repeats=spec.get('repeat',2 if '_Loop_' in key else 1)
        st=track.strips.new(action.name,start,action)
        st.action_slot=action.slots[0]
        st.action_frame_start=1
        st.action_frame_end=1+frames
        st.scale=1
        st.repeat=repeats
        st.extrapolation='HOLD_FORWARD'
        st.blend_type='REPLACE'
        st.use_auto_blend=False
        st.blend_in=st.blend_out=0
        label_short=action.name.removeprefix('Nodachi_')
        s.timeline_markers.new(label_short,frame=start)
        r={'action':action.name,'source':key,'source_seconds':source_seconds,'action_frames':[1,1+frames],
           'repeat':repeats,'timeline':[start,round(st.frame_end)]}
        clip_rows.append(r)
        manifest.append({'scene':name,'category':label,'action':action.name,'start_frame':start,'end_frame':round(st.frame_end),
                         'source_seconds':source_seconds,'preview_repeat':repeats,
                         'source_fbx':entries[key]['file'] if key in entries else '',
                         'source_asset':action.get('source_asset','')})
        start=round(st.frame_end)+13
    s.frame_start=1
    s.frame_end=clip_rows[-1]['timeline'][1]
    s.frame_set(1)
    s.view_layers[0].objects.active=rig
    rig.select_set(True,view_layer=s.view_layers[0])
    new_rigs[name]=rig
    report['scenes'].append({'name':name,'label':label,'frame_end':s.frame_end,'clips':clip_rows})
    return s

idle_order=['AS_Idle_Seq','AS_Idle_to_Idle_Combat_Seq','AS_Idle_Combat_Seq','AS_Idle_Combat_to_Idle_Seq']
def order_key(entry):
    phase=0 if '_Start_' in entry['name'] else 1 if '_Loop_' in entry['name'] else 2 if '_Stop_' in entry['name'] else 3
    return (entry['asset'].rsplit('/',1)[0],phase,entry['name'])

for category,name,label in category_specs:
    es=sorted((e for e in source['exports'] if e['category']==category),key=order_key)
    if category=='01_idle': es=[entries[n] for n in idle_order]
    specs=[{'key':e['name'],'seconds':3 if e['name'] in ('AS_Idle_Seq','AS_Idle_Combat_Seq') else None} for e in es]
    make_scene(name,label,specs)

overview_keys=[
 ('AS_Idle_Seq',2,1),
 ('AS_Idle_to_Idle_Combat_Seq',None,1),
 ('AS_Idle_Combat_Seq',2,1),
 ('AS_Walk_Combat_Start_F_0_Seq',None,1),
 ('AS_Walk_Combat_Loop_F_0_Seq',None,3),
 ('AS_Walk_Combat_Stop_F_0_Seq',None,1),
 ('AS_Walk_Combat_Loop_F_L_90_Seq',None,2),
 ('AS_Walk_Combat_Loop_F_R_90_Seq',None,2),
 ('AS_Walk_Combat_Loop_B_180_Seq',None,2),
 ('AS_Run_Combat_Start_F_0_Seq',None,1),
 ('AS_Run_Combat_Loop_F_0_Seq',None,3),
 ('AS_Run_Combat_Stop_F_0_Seq',None,1),
 ('AS_Run_Combat_Fast_Loop_Seq',None,3),
 ('AS_Turn_Combat_90_L_Seq',None,1),
 ('AS_Turn_Combat_180_R_Seq',None,1),
 ('Nodachi_05_Combo_Attack_01_Full',None,1),
 ('Nodachi_Combo_Attack_05_All',None,1),
 ('AS_Idle_Combat_to_Idle_Seq',None,1),
]
overview=make_scene('00_Overview','常用动作总览：待机 / 步行 / 跑步 / 冲刺 / 转身 / 攻击',
                    [{'key':k,'seconds':seconds,'repeat':repeat} for k,seconds,repeat in overview_keys])

# Verify NLA assignment and shared meshes after scene construction.
for sr in report['scenes']:
    s=bpy.data.scenes[sr['name']]
    bpy.context.window.scene=s
    if s==base_scene: continue
    rig=new_rigs[s.name]
    body=next(o for o in s.objects if o.parent==rig and o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
    sword=next(o for o in s.objects if o.parent==rig and o.parent_type=='BONE')
    assert body.data==base_body.data and sword.data==base_sword.data and rig.data==base_rig.data
    st=rig.animation_data.nla_tracks[0].strips[0]
    s.frame_set(round(st.frame_start+(st.frame_end-st.frame_start)*.37))
    dg=bpy.context.evaluated_depsgraph_get()
    ev=body.evaluated_get(dg)
    assert all(math.isfinite(v) for v in ev.data.vertices[5000].co)
    sr['shared_meshes_verified']=True
    sr['sample_vertex']=list(ev.matrix_world@ev.data.vertices[5000].co)
    sr['weapon_bone']=sword.parent_bone
    s.frame_set(1)

bpy.context.window.scene=overview
base_scene.render.fps=60
base_scene.render.fps_base=1
overview.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
        elif area.type=='NLA_EDITOR':
            area.spaces.active.dopesheet.show_only_selected=True

character_actions={strip.action for s in bpy.data.scenes for o in s.objects if o.type=='ARMATURE' and o.animation_data for t in o.animation_data.nla_tracks for strip in t.strips}
assert len(character_actions)==204,(len(character_actions),'Expected 194 movement/idle + 10 attack clips')
assert report['new_unique_actions']==193
report['total_unique_character_actions']=len(character_actions)
report['scene_count']=len(report['scenes'])
report['blend_file']=str(ROOT/'blender/nodachi_character_animation_library.blend')
report['overview_seconds']=(overview.frame_end-overview.frame_start)/60
report['unique_body_meshes']=1
report['unique_sword_meshes']=1

help_text='太刀动作库 / NODACHI ANIMATION LIBRARY\n\n最新工程：nodachi_character_animation_library.blend\n空格播放 / 暂停。右上角“场景”下拉选择：\n'
help_text+='\n'.join(f"{s['name']} — {s['label']} ({len(s['clips'])} 段)" for s in sorted(report['scenes'],key=lambda x:x['name']))
help_text+='\n\n共 204 个独立角色 Actions：194 个待机/移动/转身源动作 + 10 个攻击动作。\n本轮导出 194 FBX；其中战斗待机复用已有 Action，因此实际新增 193 Actions。\n统一以 60 FPS 保持源时长播放，循环动作在分类预览中重复两次。\n普通/战斗待机各展示前 3 秒；完整 10 秒源 Action 仍保留。\nIP = 动作包的原地移动版本；RM 版本和 additive 瞄准偏移未重复导入。\n所有场景共享人形网格、骨架数据与太刀网格，动画独立编排。\n使用动作包自带 Manny 人形；尚未重定向到游戏主角或接入 Godot。\n预览的动作切换是分段展示，不是游戏动画状态机。\n清单：reports/animation_library_manifest.csv\n'
text=bpy.data.texts.get('START_HERE.txt') or bpy.data.texts.new('START_HERE.txt')
text.clear()
text.write(help_text)
(ROOT/'ANIMATION_LIBRARY_README.txt').write_text(help_text,encoding='utf-8-sig')
with (ROOT/'reports/animation_library_manifest.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(manifest[0]))
    writer.writeheader()
    writer.writerows(manifest)
write_report()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=report['blend_file'],compress=True)
print('LOCOMOTION_LIBRARY_DONE',json.dumps({'actions':len(character_actions),'scenes':len(report['scenes']),'overview_seconds':report['overview_seconds']},ensure_ascii=False),flush=True)
