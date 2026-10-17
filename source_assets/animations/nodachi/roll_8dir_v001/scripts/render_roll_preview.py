import bpy,json
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/roll_8dir_v001')
s=bpy.context.scene
report=json.loads((ROOT/'reports/blender_validation.json').read_text(encoding='utf-8'))
for i in (0,2,4,6):
    r=report['clips'][i]
    start,end=r['review_frames']
    s.frame_set(start+round((end-start)*.4))
    s.render.resolution_x=900
    s.render.resolution_y=600
    s.cycles.samples=24
    s.render.filepath=str(ROOT/'previews'/(r['action']+'.png'))
    bpy.ops.render.render(write_still=True)
s.render.engine='BLENDER_WORKBENCH'
s.display.shading.light='STUDIO'
s.display.shading.color_type='MATERIAL'
s.display.shading.show_shadows=True
s.display.shading.show_cavity=True
s.display.shading.cavity_type='BOTH'
s.display.render_aa='16'
s.render.resolution_x=900
s.render.resolution_y=600
s.frame_step=2
s.render.fps=30
s.render.image_settings.media_type='VIDEO'
s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4'
s.render.ffmpeg.codec='H264'
s.render.ffmpeg.constant_rate_factor='HIGH'
s.render.ffmpeg.ffmpeg_preset='GOOD'
s.render.filepath=str(ROOT/'previews/nodachi_roll_8dir_preview.mp4')
bpy.ops.render.render(animation=True)
print('ROLL_PREVIEW_DONE',flush=True)
