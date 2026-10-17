import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
s=bpy.context.scene
cam=s.camera
cam.location=(-4.2,-6.5,3)
cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1)
s.render.resolution_x=960
s.render.resolution_y=640
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/nodachi_animation_review_v001.blend'))
s.render.filepath=str(ROOT/'previews/idle_front.png')
bpy.ops.render.render(write_still=True)
# A lightweight, unretimed video of the full combo, using evaluated mesh animation.
s.render.engine='BLENDER_WORKBENCH'
s.display.shading.light='STUDIO'
s.display.shading.studiolight_rotate_z=.4
s.display.shading.color_type='MATERIAL'
s.display.shading.show_shadows=True
s.display.shading.show_cavity=True
s.display.shading.cavity_type='BOTH'
s.display.shading.show_specular_highlight=True
s.display.shading.background_type='WORLD'
s.world.color=(.065,.075,.07)
s.display.render_aa='16'
s.render.resolution_x=840
s.render.resolution_y=560
s.frame_start=611
s.frame_end=811
s.render.fps=60
s.render.image_settings.media_type='VIDEO'
s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4'
s.render.ffmpeg.codec='H264'
s.render.ffmpeg.constant_rate_factor='HIGH'
s.render.ffmpeg.ffmpeg_preset='GOOD'
s.render.filepath=str(ROOT/'previews/nodachi_full_combo.mp4')
bpy.ops.render.render(animation=True)
print('MOTION_PREVIEW_DONE')
