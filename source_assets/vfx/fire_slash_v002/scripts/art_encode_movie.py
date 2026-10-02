"""Encode actual Blender-rendered animation frames with Blender's own FFmpeg."""
import bpy
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
frames=BASE/'blender_previews/movie_frames'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=960;s.render.resolution_y=600;s.render.resolution_percentage=100;s.render.fps=30;s.frame_start=1;s.frame_end=96
s.view_settings.view_transform='Standard';s.view_settings.look='None'
editor=s.sequence_editor_create();strip=editor.strips.new_image('BlenderRenderedFireSlash',str(frames/'frame_001.png'),channel=1,frame_start=1)
for f in range(2,97):strip.elements.append(f'frame_{f:03d}.png')
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.filepath=str(BASE/'blender_previews/fire_slash_v002_motion.mp4')
bpy.ops.render.render(animation=True)
print('ART_MOVIE_READY',s.render.filepath)
