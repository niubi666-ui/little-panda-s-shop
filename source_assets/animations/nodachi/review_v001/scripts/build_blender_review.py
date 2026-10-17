import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Nodachi_Animation_Review_v001'
source = json.loads((ROOT/'reports/ue_export.json').read_text(encoding='utf-8'))
clips = [e for e in source['exports'] if e['class']=='AnimSequence' and e.get('ok')]
report = {'clips': [], 'target_fps': 60, 'source_skeleton': clips[0]['skeleton']}
rig = None
actions = []

def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves

for entry in clips:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=entry['file'],use_anim=True,automatic_bone_orientation=False)
    objs = set(bpy.data.objects)-before
    arm = next(o for o in objs if o.type=='ARMATURE')
    action = arm.animation_data.action
    fps = scene.render.fps / scene.render.fps_base
    original_range = list(action.frame_range)
    action.name = 'Nodachi_' + entry['label']
    action.use_fake_user = True
    factor = 60/fps
    for fc in curves(action):
        for k in fc.keyframe_points:
            for co in (k.co,k.handle_left,k.handle_right):
                co.x = 1+(co.x-1)*factor
    seconds = float(entry['sequence_length'])
    action['source_asset'] = entry['asset']
    action['source_seconds'] = seconds
    action['import_fps'] = fps
    report['clips'].append({'name':action.name,'source_seconds':seconds,'import_fps':fps,'import_frames':original_range,
                            'review_action_end': 1+round(seconds*60)})
    if rig is None:
        rig = arm
        rig.name = 'Nodachi_Manny_Rig'
        body = next(o for o in objs if o.type=='MESH')
        body.name = 'Nodachi_Manny_Preview'
    else:
        mismatches = [b.name for b in arm.data.bones if b.name not in rig.data.bones or
                      max(abs(x-y) for row1,row2 in zip(b.matrix_local,rig.data.bones[b.name].matrix_local) for x,y in zip(row1,row2)) > 0.001]
        if mismatches:
            raise RuntimeError('Rest pose differs: '+str(mismatches))
        for obj in objs:
            bpy.data.objects.remove(obj,do_unlink=True)
    actions.append(action)

scene.render.fps=60
scene.render.fps_base=1
rig.animation_data.action = None
track=rig.animation_data.nla_tracks.new()
track.name='REVIEW | Idle / Attacks 1-4 / Full Combo'
start=1
for i,(action,entry) in enumerate(zip(actions,report['clips'])):
    clip_end=entry['review_action_end'] if i else 121
    strip=track.strips.new(action.name,start,action)
    strip.action_slot=action.slots[0]
    strip.action_frame_start=1
    strip.action_frame_end=clip_end
    strip.frame_end=start+clip_end-1
    strip.extrapolation='HOLD_FORWARD'
    strip.blend_type='REPLACE'
    strip.use_auto_blend=False
    strip.blend_in=0
    strip.blend_out=0
    entry['timeline']=[start,int(strip.frame_end)]
    scene.timeline_markers.new(('00 IDLE' if i==0 else ('05 FULL COMBO' if i==5 else f'0{i} ATTACK {i}')),frame=start)
    start=int(strip.frame_end)+19
scene.frame_start=1
scene.frame_end=int(track.strips[-1].frame_end)
scene.use_preview_range=False

# The source pack supplies a dedicated animated weapon bone and an identity socket.
bpy.ops.import_scene.fbx(filepath=str(ROOT/'fbx/Nodachi_Sword.fbx'), use_anim=False)
sword=bpy.context.selected_objects[0]
sword.name='Nodachi_Sword_SourceSocket'
bone=rig.data.bones['Nodachi_Weapon_R']
sword.parent=rig
sword.parent_type='BONE'
sword.parent_bone=bone.name
sword.matrix_parent_inverse=Matrix.Translation((0,-bone.length,0))
sword.matrix_basis=Matrix.Identity(4)
sword['attachment']='UE Nodachi_Weapon_RSocket / Nodachi_Weapon_R, identity transform; bone-tail offset removed'
scene.render.fps=60
scene.render.fps_base=1

def mat(name,color,metal=0,rough=.45):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough
    return m

armor=mat('Review | muted teal armour',(.13,.24,.24),.65,.29)
joints=mat('Review | dark joints',(.025,.04,.045),.15,.5)
for i in range(len(body.data.materials)):
    body.data.materials[i]=armor if i%2==0 else joints
steel=mat('Review | sword steel',(.48,.57,.64),.85,.25)
handle=mat('Review | sword grip',(.055,.025,.018),.1,.62)
sword.data.materials.clear()
sword.data.materials.append(steel)
sword.data.materials.append(handle)
for poly in sword.data.polygons:
    if poly.center.y < -2.5:
        poly.material_index=1
for obj in [body,sword]:
    for poly in obj.data.polygons:
        poly.use_smooth=True

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04))
floor=bpy.context.object
floor.name='Review_Ground'
floor.data.materials.append(mat('Review | warm slate floor',(.065,.083,.08),.05,.65))
world=bpy.data.worlds.new('Review_World')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.24,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.world=world

def aim(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.color=color
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.location=loc
    aim(obj,(0,0,1))
area('Warm_Key',(-3,-4,6),1100,(1,.82,.62),4)
area('Cool_Fill',(4,-1,3),700,(.58,.78,1),4)
area('Rim',(-1,4,5),1500,(1,.9,.72),3)
camera_data=bpy.data.cameras.new('Review_Camera')
camera=bpy.data.objects.new('Review_Camera',camera_data)
scene.collection.objects.link(camera)
camera.location=(4.2,-6.5,3.0)
aim(camera,(0,-.1,1))
camera_data.type='ORTHO'
camera_data.ortho_scale=5.2
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=960
scene.render.resolution_y=640
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'

# Check actual evaluated mesh and weapon motion, not only presence of keyframes.
samples=[]
for entry in report['clips']:
    a,b=entry['timeline']
    frames=[a,a+(b-a)//4,a+(b-a)//2,a+3*(b-a)//4,b]
    poses=[]
    for f in frames:
        scene.frame_set(f)
        dg=bpy.context.evaluated_depsgraph_get()
        ev=body.evaluated_get(dg)
        coords=[ev.matrix_world @ v.co for v in ev.data.vertices]
        poses.append({'frame':f,'head':list(rig.matrix_world @ rig.pose.bones['head'].matrix.translation),
                      'hand_r':list(rig.matrix_world @ rig.pose.bones['hand_r'].matrix.translation),
                      'sword_origin':list(sword.matrix_world.translation),
                      'vertex_sample':list(coords[5000]),
                      'bbox_min':[min(v[j] for v in coords) for j in range(3)],
                      'bbox_max':[max(v[j] for v in coords) for j in range(3)]})
    samples.append({'clip':entry['name'],'poses':poses})
report['motion_validation']=samples
report['bone_count']=len(rig.data.bones)
report['weapon_bone']=bone.name
report['frame_end']=scene.frame_end
(ROOT/'reports/blender_review.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

scene.frame_set(report['clips'][1]['timeline'][0]+30)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
rig.show_in_front=False
rig.data.display_type='STICK'
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            sp=ar.spaces.active
            sp.region_3d.view_perspective='CAMERA'
            sp.overlay.show_overlays=False
            sp.shading.type='MATERIAL'
        elif ar.type=='DOPESHEET_EDITOR':
            ar.type='NLA_EDITOR'
            ar.spaces.active.dopesheet.show_only_selected=True
scene['Review_Instructions']='Space: play/pause. Whole timeline is enabled. Six clips are stored separately as Actions and sequenced in NLA. Source root motion preserved. Preview mannequin only; no Godot changes.'
text=bpy.data.texts.new('START_HERE.txt')
text.write('NODACHI / UE → BLENDER REVIEW\n\nSpace: play / pause. Full timeline enabled.\nEach source animation is a separate Action. NLA sequences clips for review only.\n\n'+ '\n'.join(f"{e['timeline'][0]}–{e['timeline'][1]}: {e['name']}" for e in report['clips']) + '\n\nSource mannequin and sword from the Nodachi animation pack.\nPreview materials are neutral replacements, not UE shader conversions.\nNext: retarget to game hero, adjust grip/root motion, export GLB.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/nodachi_animation_review_v001.blend'))
for index, entry in enumerate(report['clips'][1:]):
    a,b=entry['timeline']
    frame=a+int((b-a)*(.32 if index<4 else .52))
    scene.frame_set(frame)
    scene.render.filepath=str(ROOT/'previews'/f'pose_{index+1:02}.png')
    bpy.ops.render.render(write_still=True)
print('NODACHI_REVIEW_DONE')
