"""Build the approved Manny + Nodachi with independent in-place game clips.
Run with Blender --background --factory-startup --python this_script.
Review source blends are read only. Gameplay timing lives in Godot JSON/Resources.
"""
import bpy,json,math,struct
from pathlib import Path
from mathutils import Matrix,Vector

PROJECT=Path('E:/ShopGame')
ROOT=PROJECT/'source_assets/characters/ue_manny_nodachi'
SOURCE=PROJECT/'source_assets/animations/nodachi'
OUT=PROJECT/'game/assets/characters/ue_manny_nodachi'
for p in (ROOT/'blender',ROOT/'reports',OUT):p.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'review_v001/blender/nodachi_animation_review_attack01_and_05.blend'))
s=bpy.context.scene
rig=bpy.data.objects['Nodachi_Manny_Rig'];body=bpy.data.objects['Nodachi_Manny_Preview'];sword=bpy.data.objects['Nodachi_Sword_SourceSocket']
rig.animation_data_clear()
for o in list(bpy.data.objects):
 if o not in (rig,body,sword):bpy.data.objects.remove(o,do_unlink=True)
for text in list(bpy.data.texts):bpy.data.texts.remove(text)

def curves(action):
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    yield from bag.fcurves

mapping={'Nodachi_00_Combat_Idle':('idle',600),
 'Nodachi_01_Combo_Attack_01_01':('attack_1',110),
 'Nodachi_02_Combo_Attack_01_02':('attack_2',90),
 'Nodachi_03_Combo_Attack_01_03':('attack_3',90),
 'Nodachi_Combo_Attack_05_01':('heavy',145),
 'Nodachi_04_Combo_Attack_01_04':('cast',105)}
selected=[];report=[]
for source,(name,intervals) in mapping.items():
 a=bpy.data.actions[source];selected.append(a)
 report.append({'clip':name,'source_action':source,'source_blend':'review_v001/blender/nodachi_animation_review_attack01_and_05.blend','seconds':intervals/60})
 a.name=name;a.use_frame_range=True;a.frame_start=1;a.frame_end=1+intervals
for a in list(bpy.data.actions):
 if a not in selected:bpy.data.actions.remove(a)
directions=['forward','forward_right','right','back_right','back','back_left','left','forward_left']
suffixes=['F_0','F_R_45','F_R_90','B_R_45','B_180','B_L_45','F_L_90','F_L_45']
manifest=json.loads((SOURCE/'review_v001/reports/locomotion_blender_library.json').read_text())
lookup={r['action']:r for r in manifest['imports']}
names={f'Nodachi_{mode}_Combat_Loop_{suf}':f'{mode.lower()}_{d}' for mode in ('Walk','Run') for d,suf in zip(directions,suffixes)}
with bpy.data.libraries.load(str(SOURCE/'review_v001/blender/nodachi_character_animation_library.blend'),link=False) as (src,dst):
 dst.actions=list(names)
for a in dst.actions:
 source=a.name;row=lookup[source];a.name=names[source]
 a.use_frame_range=True;a.frame_start=1;a.frame_end=1+round(row['sequence_length']*60)
 selected.append(a);report.append({'clip':a.name,'source_action':source,'source_blend':'review_v001/blender/nodachi_character_animation_library.blend','seconds':(a.frame_end-1)/60})
with bpy.data.libraries.load(str(SOURCE/'roll_8dir_v001/blender/nodachi_roll_8dir.blend'),link=False) as (src,dst):
 dst.actions=['roll_'+d for d in directions]
for a in dst.actions:
 a.use_frame_range=True;a.frame_start=1;a.frame_end=71
 selected.append(a);report.append({'clip':a.name,'source_action':a.name,'source_blend':'roll_8dir_v001/blender/nodachi_roll_8dir.blend','seconds':70/60})
for row in json.loads((ROOT/'reactions.json').read_text()) + json.loads((ROOT/'roll_slash.json').read_text()):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=row['file'],use_anim=True,automatic_bone_orientation=False)
 imported=set(bpy.data.objects)-before;arm=next(o for o in imported if o.type=='ARMATURE');a=arm.animation_data.action
 delta=max(abs(x-y) for b in arm.data.bones for r1,r2 in zip(b.matrix_local,rig.data.bones[b.name].matrix_local) for x,y in zip(r1,r2))
 assert delta<.001
 fps=s.render.fps/s.render.fps_base
 if fps!=60:
  for fc in curves(a):
   for key in fc.keyframe_points:
    for co in (key.co,key.handle_left,key.handle_right):co.x=1+(co.x-1)*60/fps
   fc.update()
 a.name=row['name'];a.use_frame_range=True;a.frame_start=1;a.frame_end=1+round(row['seconds']*60)
 selected.append(a);report.append({'clip':a.name,'source_asset':row['source'],'seconds':(a.frame_end-1)/60})
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)
s.render.fps=60;s.render.fps_base=1
rig.animation_data_create()
for a,row in zip(selected,report):
 a.use_fake_user=True;a.use_cyclic=False
 # Unreal FBX root motion is on the armature object. CharacterMotor owns XY
 # displacement; preserve pelvis/feet/weapon poses and the source vertical motion.
 for fc in curves(a):
  if fc.data_path=='location' and fc.array_index<2:
   for key in fc.keyframe_points:key.co.y=key.handle_left.y=key.handle_right.y=0
   fc.update()
 rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
 samples=[]
 for f in (1,round(a.frame_end*.35),round(a.frame_end*.7),round(a.frame_end)):
  s.frame_set(f);samples.append(list(rig.matrix_world.translation))
 assert max(abs(p[k]) for p in samples for k in (0,1))<.0001,(a.name,samples)
 row['root_xy_in_place']=True;row['frames']=[1,round(a.frame_end)]
 a['source_record']=json.dumps(row)
 if not a.asset_data:a.asset_mark()
 a.asset_data.description='Approved Nodachi game clip; XY root motion removed; source poses retained.'
# Exact blade anchors drive elemental VFX, instead of the old procedural sword path.
for name,y in [('WeaponFX_Base',8.0),('WeaponFX_Tip',163.6)]:
 o=bpy.data.objects.new(name,None);s.collection.objects.link(o);o.parent=sword;o.location=(0,y,0);o.empty_display_size=4
s.name='Manny_Nodachi_Game';s.frame_start=1;s.frame_end=601
rig.animation_data.action=selected[0];rig.animation_data.action_slot=selected[0].slots[0];s.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/manny_nodachi_game.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'manny_nodachi.glb'),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_anim_single_armature=True,
 export_merge_animation='ACTION',export_frame_range=False,export_anim_slide_to_zero=True,
 export_reset_pose_bones=True,export_skins=True,export_def_bones=False,export_leaf_bone=False,
 export_extras=True,export_yup=True,export_cameras=False,export_lights=False,export_influence_nb=8)
with (OUT/'manny_nodachi.glb').open('rb') as f:
 f.read(12);length,kind=struct.unpack('<II',f.read(8));g=json.loads(f.read(length))
assert {a['name'] for a in g['animations']}=={a.name for a in selected}
for a in g['animations']:
 dur=max(g['accessors'][sampler['input']]['max'][0] for sampler in a['samplers'])
 expected=next(r['seconds'] for r in report if r['clip']==a['name'])
 assert abs(dur-expected)<.02,(a['name'],dur,expected)
(ROOT/'reports/runtime_export.json').write_text(json.dumps({'clips':report,'bone_count':len(rig.data.bones),'mesh_vertices':sum(len(o.data.vertices) for o in (body,sword)),'glb':str(OUT/'manny_nodachi.glb')},indent=2),encoding='utf8')
print('RUNTIME_EXPORT_OK',len(selected),flush=True)
