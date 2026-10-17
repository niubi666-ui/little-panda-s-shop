import bpy,json,csv
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
report=json.loads((ROOT/'reports/locomotion_blender_library.json').read_text(encoding='utf-8'))
source_files={r['action']:r['file'] for r in report['imports']}
for report_name in ('ue_export.json','attack05_ue_export.json'):
    r=json.loads((ROOT/'reports'/report_name).read_text())
    for e in r['exports']:
        if 'label' in e: source_files['Nodachi_'+e['label']]=e['file']
        elif e.get('name','').startswith('AS_'): source_files[e['name'].replace('AS_','Nodachi_',1).removesuffix('_Seq')]=e['file']
rows=[]
for sr in report['scenes']:
    s=bpy.data.scenes[sr['name']]
    rig=next(o for o in s.objects if o.type=='ARMATURE')
    for st in rig.animation_data.nla_tracks[0].strips:
        a=st.action
        rows.append({'scene':s.name,'category':sr['label'],'action':a.name,'start_frame':round(st.frame_start),
                     'end_frame':round(st.frame_end),'source_seconds':a.get('source_seconds'),
                     'preview_repeat':st.repeat,'source_fbx':source_files.get(a.name,''),
                     'source_asset':a.get('source_asset','')})
with (ROOT/'reports/animation_library_manifest.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
assert len({r['action'] for r in rows})==204
samples=[
 ('02_Idle_and_Stance','Nodachi_Idle','locomotion_idle'),
 ('04_Walk_Combat','Nodachi_Walk_Combat_Loop_F_0','locomotion_combat_walk'),
 ('08_Run_Combat_and_Sprint','Nodachi_Run_Combat_Loop_F_0','locomotion_combat_run'),
 ('08_Run_Combat_and_Sprint','Nodachi_Run_Combat_Fast_Loop','locomotion_combat_sprint'),
]
renders=[]
for scene_name,action_name,label in samples:
    s=bpy.data.scenes[scene_name]
    bpy.context.window.scene=s
    rig=next(o for o in s.objects if o.type=='ARMATURE')
    st=next(st for t in rig.animation_data.nla_tracks for st in t.strips if st.action.name==action_name)
    f=round(st.frame_start+(st.action_frame_end-st.action_frame_start)*.22)
    s.frame_set(f)
    s.render.filepath=str(ROOT/'previews'/(label+'.png'))
    bpy.ops.render.render(write_still=True)
    renders.append({'scene':scene_name,'frame':f,'path':s.render.filepath})
(ROOT/'reports/locomotion_render_check.json').write_text(json.dumps(renders,indent=2))
print('LOCOMOTION_STILLS_DONE',flush=True)
# A short real Blender animation preview of forward combat walking then running.
s=bpy.data.scenes['00_Overview']
bpy.context.window.scene=s
rig=next(o for o in s.objects if o.type=='ARMATURE')
track=rig.animation_data.nla_tracks[0]
first=next(st for st in track.strips if st.action.name=='Nodachi_Walk_Combat_Start_F_0')
last=next(st for st in track.strips if st.action.name=='Nodachi_Run_Combat_Stop_F_0')
s.frame_start=round(first.frame_start)
s.frame_end=round(last.frame_end)
s.frame_step=2
s.render.fps=30
s.render.engine='BLENDER_WORKBENCH'
s.display.shading.light='STUDIO'
s.display.shading.color_type='MATERIAL'
s.display.shading.show_shadows=True
s.display.shading.show_cavity=True
s.display.shading.cavity_type='BOTH'
s.display.render_aa='16'
s.render.resolution_x=840
s.render.resolution_y=560
s.render.image_settings.media_type='VIDEO'
s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4'
s.render.ffmpeg.codec='H264'
s.render.ffmpeg.constant_rate_factor='HIGH'
s.render.ffmpeg.ffmpeg_preset='GOOD'
s.render.filepath=str(ROOT/'previews/nodachi_locomotion_preview.mp4')
bpy.ops.render.render(animation=True)
print('LOCOMOTION_VIDEO_DONE',flush=True)
