"""Encode the real Godot Movie Maker recording with Blender's native sequencer.

Usage: blender -b --factory-startup --python capture_encode.py -- [input.avi] [output.mp4]
No changes to footage or simulation are made during encoding.
"""
import json
import sys
from pathlib import Path

import bpy

base = Path(__file__).resolve().parents[1] / "previews"
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
source = Path(args[0]) if args else base / "golden_combat.avi"
destination = Path(args[1]) if len(args) > 1 else base / "golden_combat.mp4"
if not source.is_file():
    raise FileNotFoundError(source)
destination.parent.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
editor = scene.sequence_editor_create()
strips = editor.strips if hasattr(editor, "strips") else editor.sequences
movie = strips.new_movie("ActualGodotCombat", str(source), channel=1, frame_start=1)
scene.frame_start = 1
scene.frame_end = movie.frame_final_end - 1
scene.render.resolution_x = movie.elements[0].orig_width
scene.render.resolution_y = movie.elements[0].orig_height
scene.render.resolution_percentage = 100
scene.render.fps = round(movie.fps)
scene.render.fps_base = 1.0
scene.render.use_sequencer = True
scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
scene.render.ffmpeg.audio_codec = "NONE"
scene.render.filepath = str(destination)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.sequencer_colorspace_settings.name = "sRGB"
bpy.ops.render.render(animation=True)
print("ENCODED", json.dumps({
    "source": str(source), "output": str(destination),
    "frames": scene.frame_end, "fps": scene.render.fps,
    "width": scene.render.resolution_x, "height": scene.render.resolution_y,
}, ensure_ascii=False))
