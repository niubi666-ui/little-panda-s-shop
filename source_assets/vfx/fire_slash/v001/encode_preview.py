"""Transcode the actual Godot Movie Maker AVI to a compact MP4 using Blender."""
import bpy
from pathlib import Path
base = Path(__file__).resolve().parent / 'previews'
scene = bpy.context.scene
editor = scene.sequence_editor_create()
strips = editor.strips if hasattr(editor, 'strips') else editor.sequences
movie = strips.new_movie('GodotCapture', str(base / 'fire_slash.avi'), channel=1, frame_start=1)
scene.frame_start = 1
scene.frame_end = movie.frame_final_end - 1
scene.render.resolution_x = 1280
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.fps = 60
scene.render.fps_base = 1
scene.render.use_sequencer = True
scene.render.image_settings.media_type = 'VIDEO'
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.ffmpeg.audio_codec = 'NONE'
scene.render.filepath = str(base / 'fire_slash.mp4')
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.sequencer_colorspace_settings.name = 'sRGB'
bpy.ops.render.render(animation=True)
print('ENCODED', scene.render.filepath, scene.frame_end)
