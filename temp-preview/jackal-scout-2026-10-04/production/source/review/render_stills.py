"""Render final model and genuine authored poses for GitHub review."""
import argparse
import bpy
from mathutils import Vector
from pathlib import Path
import sys

p = argparse.ArgumentParser()
p.add_argument('--out', type=Path, required=True)
p.add_argument('--samples', type=int, default=64)
args = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
args.out.mkdir(parents=True, exist_ok=True)
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.device = 'CPU'
s.cycles.samples = args.samples
s.cycles.use_denoising = False
s.render.resolution_x = 1024
s.render.resolution_y = 1024
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
rig = next(o for o in s.objects if o.type == 'ARMATURE')
rig.animation_data_create()
for track in rig.animation_data.nla_tracks:
    track.mute = True
camera = s.camera
target = Vector((0, 0, 1.15))

def shot(name, action_name, fraction, position, scale=2.85, point=None):
    action = bpy.data.actions[action_name]
    rig.animation_data.action = action
    start, end = action.frame_range
    frame = start + fraction * (end - start)
    s.frame_set(int(frame), subframe=frame % 1)
    camera.location = position
    camera.rotation_euler = ((point or target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = scale
    s.render.filepath = str(args.out / (name + '.png'))
    bpy.ops.render.render(write_still=True)

shot('hero', 'Idle', 0, (-3.5, -6.5, 2.9))
shot('run', 'Run', .25, (-3.5, -6.5, 2.9))
shot('attack', 'Attack', .53, (-3.5, -6.5, 2.9))
shot('hit', 'Hit', .33, (-3.5, -6.5, 2.9))
print('REVIEW_STILLS_FINISHED')
