# 把 Godot Movie Maker 录的 PNG 序列拼成一个 mp4（用 Blender 自带的 ffmpeg）。
# 用法：blender --background --factory-startup --python encode_video.py -- <输出.mp4> <帧目录1> [帧目录2 ...]
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
out_path, folders = args[0], args[1:]

scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.fps = 60
scene.sequence_editor_create()
seq = scene.sequence_editor

frame = 1
for i, folder in enumerate(folders):
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith(".png"))
    if not files:
        continue
    strips = seq.strips if hasattr(seq, "strips") else seq.sequences
    strip = strips.new_image(name=f"part{i}", filepath=os.path.join(folder, files[0]), channel=1, frame_start=frame)
    for f in files[1:]:
        strip.elements.append(f)
    frame += len(files)

scene.frame_start = 1
scene.frame_end = frame - 1
if hasattr(scene.render.image_settings, "media_type"):
    scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
scene.render.ffmpeg.ffmpeg_preset = "GOOD"
scene.render.filepath = out_path
bpy.ops.render.render(animation=True)
print("encoded", out_path, frame - 1, "frames")
