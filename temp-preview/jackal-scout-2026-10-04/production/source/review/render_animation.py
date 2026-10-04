"""Render actual approved rig actions to frames without changing the source blend."""
import argparse
import bpy
import json
import math
from pathlib import Path
import sys

p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--fps', type=int, default=12)
p.add_argument('--samples', type=int, default=16)
p.add_argument('--width', type=int, default=960)
p.add_argument('--height', type=int, default=720)
args = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
args.out.mkdir(parents=True, exist_ok=True)
s = bpy.context.scene
assert s.camera, 'Asset must have an actual presentation camera'
s.render.engine = 'CYCLES'
s.cycles.device = 'CPU'
s.cycles.samples = args.samples
s.cycles.use_denoising = False
s.render.resolution_x = args.width
s.render.resolution_y = args.height
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
arm = next(o for o in s.objects if o.type == 'ARMATURE')
arm.animation_data_create()
for track in arm.animation_data.nla_tracks:
    track.mute = True
clips = []
frame_id = 0
source_fps = s.render.fps / s.render.fps_base
for action_name in ('Run', 'Attack', 'Hit'):
    action = bpy.data.actions.get(action_name)
    assert action is not None, f'Missing {action_name} action'
    arm.animation_data.action = action
    lo, hi = action.frame_range
    duration = (hi - lo) / source_fps
    assert duration > 0
    repeats = 2 if action.name.lower().startswith('run') else 1
    count = max(2, round(duration * args.fps))
    clips.append({'name': action.name, 'first_output_frame': frame_id,
                  'duration_seconds': repeats * count / args.fps,
                  'original_frame_range': [lo, hi]})
    for repeat in range(repeats):
        for i in range(count):
            source_frame = lo + (hi - lo) * i / count
            s.frame_set(math.floor(source_frame), subframe=source_frame % 1)
            s.render.filepath = str(args.out / f'frame-{frame_id:04}.png')
            bpy.ops.render.render(write_still=True)
            frame_id += 1
    # Hold final recovery briefly so distinct clips remain readable.
    for i in range(round(.4 * args.fps)):
        source_frame = hi
        s.frame_set(math.floor(source_frame), subframe=source_frame % 1)
        s.render.filepath = str(args.out / f'frame-{frame_id:04}.png')
        bpy.ops.render.render(write_still=True)
        frame_id += 1
assert len(clips) >= 3, 'Required Run/Attack/Hit actions missing'
(args.out / 'sequence.json').write_text(json.dumps({'fps': args.fps, 'frames': frame_id, 'clips': clips}, indent=2) + '\n')
print('ANIMATION_RENDER_FINISHED', frame_id, 'frames')
