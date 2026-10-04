"""Read production .blend and evaluate real posed mesh geometry without modifying it."""
import bpy
import json
import math
from pathlib import Path
import sys

target = Path(sys.argv[sys.argv.index('--') + 1])
scene = bpy.context.scene
armatures = [o for o in scene.objects if o.type == 'ARMATURE']
assert armatures, 'No actual armature found'
meshes = [o for o in scene.objects if o.type == 'MESH']
characters = [o for o in meshes if any(m.type == 'ARMATURE' for m in o.modifiers)]
assert characters, 'No mesh uses an armature modifier'
actions = list(bpy.data.actions)
assert len(actions) >= 3, 'Fewer than three actual animation actions'
report = {'blender': bpy.app.version_string, 'armatures': [], 'actions': [], 'mesh_skinning': []}
for arm in armatures:
    report['armatures'].append({'name': arm.name, 'bones': len(arm.data.bones),
                               'bone_names': [b.name for b in arm.data.bones]})
    arm.animation_data_create()
    old = arm.animation_data.action
    tracks = list(arm.animation_data.nla_tracks)
    mutes = [t.mute for t in tracks]
    for t in tracks:
        t.mute = True
    for action in actions:
        if not action.fcurves:
            continue
        arm.animation_data.action = action
        start, end = action.frame_range
        sample_frames = [start, (2 * start + end) / 3, (start + 2 * end) / 3, end]
        bbox = []
        geometry_hashes = []
        for frame in sample_frames:
            scene.frame_set(int(frame), subframe=frame % 1)
            graph = bpy.context.evaluated_depsgraph_get()
            coords = []
            for obj in characters:
                evaluated = obj.evaluated_get(graph)
                mesh = evaluated.to_mesh()
                coords.extend([tuple(evaluated.matrix_world @ vertex.co) for vertex in mesh.vertices])
                evaluated.to_mesh_clear()
            assert coords and all(math.isfinite(c) for xyz in coords for c in xyz)
            lo = [min(xyz[k] for xyz in coords) for k in range(3)]
            hi = [max(xyz[k] for xyz in coords) for k in range(3)]
            bbox.append({'frame': round(frame, 3), 'min': lo, 'max': hi})
            geometry_hashes.append(hash(tuple(round(c, 5) for xyz in coords[::17] for c in xyz)))
        assert len(set(geometry_hashes)) > 1, f'Action {action.name} does not deform character meshes'
        report['actions'].append({'armature': arm.name, 'name': action.name,
                                  'frame_range': [start, end], 'fcurves': len(action.fcurves),
                                  'pose_samples': bbox, 'deformation_observed': True})
    arm.animation_data.action = old
    for t, mute in zip(tracks, mutes):
        t.mute = mute
for obj in characters:
    zero = sum(not vertex.groups for vertex in obj.data.vertices)
    sums = [sum(g.weight for g in vertex.groups) for vertex in obj.data.vertices]
    assert zero == 0, f'Unweighted vertices in {obj.name}'
    assert max(abs(total - 1) for total in sums) < .002, f'Non-normalized weights in {obj.name}'
    report['mesh_skinning'].append({'name': obj.name, 'vertices': len(obj.data.vertices),
                                    'groups': len(obj.vertex_groups), 'unweighted_vertices': zero,
                                    'weight_sum_range': [min(sums), max(sums)]})
report['result'] = 'PASS'
target.write_text(json.dumps(report, indent=2) + '\n')
print('BLEND_AUDIT_PASS', len(report['actions']), 'actions evaluated,', len(characters), 'skinned meshes')
