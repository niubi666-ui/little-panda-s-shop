"""Read back the MP4 written by Blender without touching a live scene."""
import bpy
import json
from pathlib import Path

path = Path(__file__).resolve().parent / 'previews' / 'presets_01_06.mp4'
scene = bpy.context.scene
editor = scene.sequence_editor_create()
strips = editor.strips if hasattr(editor, 'strips') else editor.sequences
movie = strips.new_movie('ReadBack', str(path), channel=1, frame_start=1)
report = {
    'path': str(path),
    'frames': movie.frame_duration,
    'width': movie.elements[0].orig_width,
    'height': movie.elements[0].orig_height,
    'fps': movie.fps,
}
assert report['frames'] == 834, report
assert (report['width'], report['height']) == (1280, 800), report
assert abs(report['fps'] - 60.0) < 0.01, report
(path.parent / 'video_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('VIDEO_VERIFIED', json.dumps(report))

