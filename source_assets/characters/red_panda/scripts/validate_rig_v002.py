"""Numerical comparison of original and repaired skinning for every animation frame."""
import bpy
import json
import numpy as np
from pathlib import Path

BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
change=json.loads((BASE/'reports/rig_v002_changes.json').read_text())
tail=set(change['tail_vertex_ids'])
fixed=bpy.data.objects['RedPanda_Mesh_v002']
coords=np.array([list(v.co) for v in fixed.data.vertices])
edges=np.array([list(e.vertices) for e in fixed.data.edges])
rest_length=np.linalg.norm(coords[edges[:,0]]-coords[edges[:,1]],axis=1)
tail_mask=np.array([int(a) in tail and int(b) in tail for a,b in edges])
palm=set(v.index for v in fixed.data.vertices if v.co.x>0 and abs(v.co.y)>.427 and .48<v.co.z<.66)
palm_mask=np.array([int(a) in palm and int(b) in palm for a,b in edges])
hand=set(v.index for v in fixed.data.vertices if v.co.x>0 and abs(v.co.y)>.355 and .48<v.co.z<.66)
hand_mask=np.array([int(a) in hand and int(b) in hand for a,b in edges])
report={}
for label in ('idle','walk','run','jump','agree'):
    report[label]={}
    for kind,scene_name,rig_name,mesh_name,prefix in (
        ('before','RedPanda_Source_v002','RedPanda_Source_Rig_v002','RedPanda_Source_Mesh_v002','SRC_TRIPO_'),
        ('after','RedPanda_Rig_v002','RedPanda_Rig_v002','RedPanda_Mesh_v002','RP_')):
        scene=bpy.data.scenes[scene_name]
        bpy.context.window.scene=scene
        rig=bpy.data.objects[rig_name]
        mesh=bpy.data.objects[mesh_name]
        action=bpy.data.actions[prefix+label]
        rig.animation_data.action=action
        rig.animation_data.action_slot=action.slots[0]
        start,end=[int(v) for v in action.frame_range]
        maxima={'tail':(0,None),'hand':(0,None),'palm':(0,None)}
        min_xyz=np.full(3,np.inf)
        max_xyz=np.full(3,-np.inf)
        nonfinite=0
        for frame in range(start,end+1):
            scene.frame_set(frame)
            obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            result=obj.to_mesh()
            v=np.array([list(v.co) for v in result.vertices])
            obj.to_mesh_clear()
            nonfinite+=int(not np.isfinite(v).all())
            ratio=np.linalg.norm(v[edges[:,0]]-v[edges[:,1]],axis=1)/np.maximum(rest_length,1e-8)
            for group,mask in (('tail',tail_mask),('hand',hand_mask),('palm',palm_mask)):
                stretch=float(ratio[mask].max())
                if stretch>maxima[group][0]: maxima[group]=(stretch,frame)
            min_xyz=np.minimum(min_xyz,v.min(axis=0))
            max_xyz=np.maximum(max_xyz,v.max(axis=0))
        report[label][kind]={'frames_checked':end-start+1,'max_edge_stretch':maxima,
                             'nonfinite_frames':nonfinite,'bounds_min':min_xyz.tolist(),'bounds_max':max_xyz.tolist()}

rig=bpy.data.objects['RedPanda_Rig_v002']
bone_error=max(abs(b.matrix_local[i][j]-change['original_bones'][b.name]['matrix'][i][j])
               for b in rig.data.bones if b.name in change['original_bones'] for i in range(4) for j in range(4))
parent_preserved=all((rig.data.bones[n].parent.name if rig.data.bones[n].parent else None)==d['parent'] for n,d in change['original_bones'].items())
deform={g.index for g in fixed.vertex_groups if g.name in rig.data.bones and rig.data.bones[g.name].use_deform}
sums=[sum(g.weight for g in v.groups if g.group in deform) for v in fixed.data.vertices]
tail_names={fixed.vertex_groups[g.group].name for i in tail for g in fixed.data.vertices[i].groups if g.weight>0}
report['integrity']={'old_bone_matrix_max_error':bone_error,'old_parents_preserved':parent_preserved,
                     'unweighted_vertices':sum(w<1e-6 for w in sums),'weight_sum_min':min(sums),'weight_sum_max':max(sums),
                     'tail_weight_groups':sorted(tail_names),'original_actions_preserved':all('SRC_TRIPO_'+n in bpy.data.actions for n in ('idle','walk','run','jump','agree'))}
(BASE/'reports/rig_v002_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.context.window.scene=bpy.data.scenes['RedPanda_Rig_v002']
action=bpy.data.actions['RP_run']
rig.animation_data.action=action
rig.animation_data.action_slot=action.slots[0]
bpy.context.scene.frame_set(8)
print(json.dumps(report))
