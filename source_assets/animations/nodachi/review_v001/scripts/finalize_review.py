import bpy, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
scene=bpy.context.scene
rig=bpy.data.objects['Nodachi_Manny_Rig']
follow=bpy.data.objects.new('Review_Camera_Follow_Pelvis_XY',None)
scene.collection.objects.link(follow)
follow.empty_display_size=.15
for f in range(scene.frame_start,scene.frame_end+1):
    scene.frame_set(f)
    p=rig.matrix_world @ rig.pose.bones['pelvis'].matrix.translation
    follow.location=(p.x,p.y,0)
    follow.keyframe_insert(data_path='location',frame=f)
cam=scene.camera
cam.parent=follow
cam.location=(4.2,6.5,3.0)
cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=5.1
scene.sync_mode='FRAME_DROP'
scene.frame_set(1)
scene.render.resolution_x=960
scene.render.resolution_y=640
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/nodachi_animation_review_v001.blend'))
report=json.loads((ROOT/'reports/blender_review.json').read_text())
for i,e in enumerate(report['clips']):
    a,b=e['timeline']
    scene.frame_set(a+round((b-a)*.4))
    scene.render.filepath=str(ROOT/'previews'/f'review_{i:02}.png')
    bpy.ops.render.render(write_still=True)
print('VIDEO_SETTINGS',[(p.identifier,str(p.type)) for p in scene.render.bl_rna.properties if any(x in p.identifier for x in ('ffmpeg','media'))])
print('FORMATS',[e.identifier for e in scene.render.image_settings.bl_rna.properties['file_format'].enum_items])
print('FINALIZE_DONE')
