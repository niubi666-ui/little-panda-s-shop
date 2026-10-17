import bpy,json
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
scene=bpy.context.scene
rig=bpy.data.objects['Nodachi_Manny_Rig']
body=bpy.data.objects['Nodachi_Manny_Preview']
track=rig.animation_data.nla_tracks[0]
source=json.loads((ROOT/'reports/attack05_ue_export.json').read_text())
assert len(source['exports'])==5 and not source['errors']
assert all(e['ok'] and e['bytes']>1000 for e in source['exports'])
report={'added_group':'Attack05','clips':[],'old_timeline_end':scene.frame_end}
start=scene.frame_end+19
new_start=start
for entry in source['exports']:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=entry['file'],use_anim=True,automatic_bone_orientation=False)
    objs=set(bpy.data.objects)-before
    arm=next(o for o in objs if o.type=='ARMATURE')
    action=arm.animation_data.action
    fps=scene.render.fps/scene.render.fps_base
    action.name=entry['name'].replace('AS_','Nodachi_').replace('_Seq','')
    action.use_fake_user=True
    for layer in action.layers:
        for ast in layer.strips:
            for bag in ast.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:
                        for co in (k.co,k.handle_left,k.handle_right):
                            co.x=1+(co.x-1)*60/fps
    mismatches=[b.name for b in arm.data.bones if b.name not in rig.data.bones or
                max(abs(x-y) for r1,r2 in zip(b.matrix_local,rig.data.bones[b.name].matrix_local) for x,y in zip(r1,r2))>.001]
    assert not mismatches,mismatches
    action['source_asset']=entry['asset']
    action['source_seconds']=entry['sequence_length']
    action['import_fps']=fps
    for obj in objs:
        bpy.data.objects.remove(obj,do_unlink=True)
    end=1+round(entry['sequence_length']*60)
    strip=track.strips.new(action.name,start,action)
    strip.action_slot=action.slots[0]
    strip.action_frame_start=1
    strip.action_frame_end=end
    strip.frame_end=start+end-1
    strip.extrapolation='HOLD_FORWARD'
    strip.blend_type='REPLACE'
    strip.use_auto_blend=False
    strip.blend_in=strip.blend_out=0
    row={'name':action.name,'source_seconds':entry['sequence_length'],'import_fps':fps,
         'timeline':[start,int(strip.frame_end)],'rest_pose_matches':True}
    report['clips'].append(row)
    suffix=entry['name'].split('_')[-2]
    scene.timeline_markers.new('ATTACK05 / '+('FULL' if suffix=='All' else suffix),frame=start)
    start=int(strip.frame_end)+19
scene.render.fps=60
scene.render.fps_base=1
scene.frame_end=int(track.strips[-1].frame_end)
scene.use_preview_range=False
scene.sync_mode='FRAME_DROP'
follow=bpy.data.objects['Review_Camera_Follow_Pelvis_XY']
for f in range(report['old_timeline_end']+1,scene.frame_end+1):
    scene.frame_set(f)
    p=rig.matrix_world @ rig.pose.bones['pelvis'].matrix.translation
    follow.location=(p.x,p.y,0)
    follow.keyframe_insert(data_path='location',frame=f)
for entry in report['clips']:
    a,b=entry['timeline']
    positions=[]
    for f in [a,a+(b-a)//3,a+2*(b-a)//3,b]:
        scene.frame_set(f)
        ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        positions.append({'frame':f,'vertex_sample':list(ev.matrix_world@ev.data.vertices[5000].co),
                          'hand_r':list(rig.matrix_world@rig.pose.bones['hand_r'].matrix.translation)})
    entry['motion_samples']=positions
    assert max((__import__('mathutils').Vector(p['vertex_sample'])-__import__('mathutils').Vector(positions[0]['vertex_sample'])).length for p in positions[1:])>.001
report['frame_end']=scene.frame_end
report['total_clips']=len(track.strips)
report['blend_file']=str(ROOT/'blender/nodachi_animation_review_attack01_and_05.blend')
(ROOT/'reports/attack05_blender_review.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.name='Nodachi_Attack01_and_Attack05_Review'
track.name='REVIEW | Attack01 + Attack05'
scene.frame_set(new_start)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
text=bpy.data.texts.get('START_HERE.txt')
text.write('\n\nADDED ATTACK05:\n'+'\n'.join(f"{r['timeline'][0]}–{r['timeline'][1]}: {r['name']}" for r in report['clips']))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=report['blend_file'])
scene.frame_set(report['clips'][-1]['timeline'][0]+30)
scene.render.filepath=str(ROOT/'previews/attack05_pose.png')
bpy.ops.render.render(write_still=True)
# Render a short original-speed full-combo video without altering saved review settings.
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH'
scene.display.render_aa='16'
scene.render.resolution_x=840
scene.render.resolution_y=560
scene.frame_start,scene.frame_end=report['clips'][-1]['timeline']
scene.render.image_settings.media_type='VIDEO'
scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4'
scene.render.ffmpeg.codec='H264'
scene.render.ffmpeg.constant_rate_factor='HIGH'
scene.render.ffmpeg.ffmpeg_preset='GOOD'
scene.render.filepath=str(ROOT/'previews/nodachi_attack05_full_combo.mp4')
bpy.ops.render.render(animation=True)
print('ATTACK05_REVIEW_DONE')
