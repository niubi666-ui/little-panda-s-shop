"""Run inside Blender via MCP on the imported RedPanda_Rig_v002 scene.
Asset-specific repair; abort on mismatched topology, never modify source FBX.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion

BASE = Path('E:/ShopGame/source_assets/characters/red_panda')
cfg = json.loads((BASE / 'scripts/rig_v002_config.json').read_text(encoding='utf-8'))
scene = bpy.data.scenes['RedPanda_Rig_v002']
rig = bpy.data.objects['RedPanda_Rig_v002']
mesh = bpy.data.objects['RedPanda_Mesh_v002']
assert len(mesh.data.vertices) == cfg['source_vertex_count']
assert not any(b.name.startswith('Tail_') for b in rig.data.bones), 'Already repaired; do not apply twice'
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()

# Keep imported meshes, weights, bone matrices and all five original actions.
raw_scene = bpy.data.scenes.new('RedPanda_Source_v002')
raw_rig = rig.copy()
raw_rig.data = rig.data.copy()
raw_rig.name = 'RedPanda_Source_Rig_v002'
raw_scene.collection.objects.link(raw_rig)
raw_mesh = mesh.copy()
raw_mesh.data = mesh.data.copy()
raw_mesh.name = 'RedPanda_Source_Mesh_v002'
raw_scene.collection.objects.link(raw_mesh)
raw_mesh.parent = raw_rig
for modifier in raw_mesh.modifiers:
    if modifier.type == 'ARMATURE':
        modifier.object = raw_rig
originals = {}
for action in list(bpy.data.actions):
    if action.name.startswith('Armature.001|'):
        label = action.name.split('|')[1].split('.')[0]
        originals[label] = action
        action.name = 'SRC_TRIPO_' + label
        action.use_fake_user = True
assert set(originals) == set(cfg['sway'])
original_bones = {b.name: {'matrix': [list(row) for row in b.matrix_local],
                          'parent': b.parent.name if b.parent else None}
                  for b in rig.data.bones}

adj = [[] for v in mesh.data.vertices]
for edge in mesh.data.edges:
    a, b = edge.vertices
    adj[a].append(b)
    adj[b].append(a)
tail = {cfg['tail_component_seed']}
todo = list(tail)
while todo:
    for neighbor in adj[todo.pop()]:
        if neighbor not in tail:
            tail.add(neighbor)
            todo.append(neighbor)
assert len(tail) == cfg['tail_component_count']

rig.data.pose_position = 'REST'
for obj in scene.objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
points = [Vector(p) for p in cfg['tail_points']]
names = []
for i, (head, end) in enumerate(zip(points, points[1:])):
    name = f'Tail_{i+1:02d}'
    bone = rig.data.edit_bones.new(name)
    bone.head = head
    bone.tail = end
    bone.parent = rig.data.edit_bones[names[-1] if names else cfg['tail_parent']]
    bone.use_connect = bool(names)
    bone.use_deform = True
    names.append(name)
bpy.ops.object.mode_set(mode='OBJECT')
groups = {name: mesh.vertex_groups.new(name=name) for name in names}
anchor = mesh.vertex_groups.get(cfg['tail_parent']) or mesh.vertex_groups.new(name=cfg['tail_parent'])
lengths = [(b-a).length for a,b in zip(points, points[1:])]
cumulative = [0.0]
for length in lengths:
    cumulative.append(cumulative[-1] + length)
centers = [(a+b)*0.5 for a,b in zip(cumulative,cumulative[1:])]

def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3.0-2.0*t)

def clear_weights(vertex):
    for weight in list(vertex.groups):
        mesh.vertex_groups[weight.group].remove([vertex.index])

for index in tail:
    vertex = mesh.data.vertices[index]
    candidates = []
    for i, (a,b) in enumerate(zip(points,points[1:])):
        direction = b-a
        fraction = max(0.0,min(1.0,(vertex.co-a).dot(direction)/direction.length_squared))
        candidates.append(((vertex.co-(a+fraction*direction)).length_squared,
                           cumulative[i]+fraction*lengths[i]))
    along = min(candidates)[1]
    weights = {}
    if along <= centers[0]:
        weights[names[0]] = 1.0
    elif along >= centers[-1]:
        weights[names[-1]] = 1.0
    else:
        for i in range(len(centers)-1):
            if centers[i] <= along <= centers[i+1]:
                t = (along-centers[i])/(centers[i+1]-centers[i])
                weights[names[i]] = 1-t
                weights[names[i+1]] = t
                break
    tail_blend = smooth(along / cfg['tail_anchor_blend_length'])
    clear_weights(vertex)
    if tail_blend < 1.0:
        anchor.add([index],1-tail_blend,'REPLACE')
    for name,weight in weights.items():
        if weight*tail_blend > 0:
            groups[name].add([index],weight*tail_blend,'REPLACE')

# Preserve wrist pivots and animation channels, stabilize paws/pads at the tip.
hand_counts = {'L':0, 'R':0}
for vertex in mesh.data.vertices:
    x,y,z = vertex.co
    if vertex.index in tail or x <= cfg['hand_region_x_min'] or not cfg['hand_region_z_min'] < z < cfg['hand_region_z_max']:
        continue
    if abs(y) <= cfg['wrist_blend_start_abs_y']:
        continue
    side = 'L' if y > 0 else 'R'
    hand = side+'_Hand'
    distal = side+'_ForearmTwist02'
    proximal = side+'_ForearmTwist01'
    allowed = {hand, distal, proximal}
    before = {mesh.vertex_groups[g.group].name:g.weight for g in vertex.groups}
    # Only edit vertices already strongly assigned to the corresponding arm.
    if sum(w for name,w in before.items() if name.startswith(side+'_')) < 0.95:
        continue
    kept = {name:w for name,w in before.items() if name in allowed}
    total = sum(kept.values())
    if total <= 0:
        continue
    blend = smooth((abs(y)-cfg['wrist_blend_start_abs_y']) /
                   (cfg['palm_rigid_start_abs_y']-cfg['wrist_blend_start_abs_y']))
    after = {name:(w/total)*(1-blend) for name,w in kept.items()}
    after[hand] = after.get(hand,0)+blend
    clear_weights(vertex)
    for name,weight in after.items():
        if weight > 0:
            mesh.vertex_groups[name].add([vertex.index],weight,'REPLACE')
    hand_counts[side] += 1

rig.data.pose_position = 'POSE'
for label, original in originals.items():
    action = original.copy()
    action.name = 'RP_'+label
    action.use_fake_user = True
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    start,end = [int(v) for v in action.frame_range]
    profile = cfg['sway'][label]
    for frame in range(start,end+1):
        scene.frame_set(frame)
        t = (frame-start)/(end-start)
        phase = math.tau*profile['cycles']*t
        envelope = math.sin(math.pi*t)**2 if label=='jump' else 1.0
        for i,name in enumerate(names):
            pb = rig.pose.bones[name]
            pb.rotation_mode = 'QUATERNION'
            inv = pb.bone.matrix_local.to_3x3().inverted()
            yaw_axis = (inv @ Vector((0,0,1))).normalized()
            side_axis = (inv @ (Vector((0,0,1)).cross((points[i+1]-points[i]).normalized()))).normalized()
            yaw = math.radians(profile['yaw_deg'][i])*math.sin(phase-i*profile['phase_lag'])*envelope
            pitch = math.radians(profile['pitch_deg'][i])*math.sin(phase*2-i*profile['phase_lag'])*envelope
            pb.rotation_quaternion = Quaternion(yaw_axis,yaw) @ Quaternion(side_axis,pitch)
            pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=name)

run = bpy.data.actions['RP_run']
rig.animation_data.action = run
rig.animation_data.action_slot = run.slots[0]
scene.frame_start,scene.frame_end = [int(v) for v in run.frame_range]
scene.frame_set(8)
raw_rig.data.pose_position = 'POSE'
raw_rig.animation_data.action = originals['run']
raw_rig.animation_data.action_slot = originals['run'].slots[0]
raw_scene.frame_set(8)
audit = {'original_bones':original_bones, 'tail_vertex_ids':sorted(tail),
         'tail_bones':names,'hand_vertices_updated':hand_counts,
         'source_actions':[a.name for a in originals.values()],
         'repaired_actions':['RP_'+label for label in originals]}
(BASE/'reports/rig_v002_changes.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps({'tail_vertices':len(tail),'bones':len(rig.data.bones),
                  'hand_vertices_updated':hand_counts,'actions':audit['repaired_actions']}))
