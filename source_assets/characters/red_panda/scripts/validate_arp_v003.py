import bpy,json,numpy as np
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
regions=json.loads((BASE/'reports/arp_v003_regions.json').read_text())
mesh=bpy.data.objects['RedPanda_ARP_Mesh_v003'];rig=bpy.data.objects['RedPanda_ARP_Rig_v003']
scene=bpy.data.scenes['RedPanda_ARP_v003'];bpy.context.window.scene=scene
coords=np.array([list(v.co) for v in mesh.data.vertices]);edges=np.array([list(e.vertices) for e in mesh.data.edges])
lengths=np.linalg.norm(coords[edges[:,0]]-coords[edges[:,1]],axis=1)
head=set(regions['protected_head']);tail=set(regions['tail'])
masks={label:np.array([int(a) in ids and int(b) in ids for a,b in edges]) for label,ids in [('head',head),('tail',tail)]}
report={}
for label in ('idle','walk','run','jump','agree'):
    action=bpy.data.actions['RP3_'+label];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    start,end=map(int,action.frame_range);metrics={'head':(0,0),'tail':(0,0),'whole':(0,0)};worst=[]
    for frame in range(start,end+1):
        scene.frame_set(frame)
        obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());result=obj.to_mesh()
        pts=np.array([list(v.co) for v in result.vertices]);obj.to_mesh_clear()
        assert np.isfinite(pts).all()
        ratio=np.linalg.norm(pts[edges[:,0]]-pts[edges[:,1]],axis=1)/np.maximum(lengths,1e-8)
        for name,mask in masks.items():
            value=float(ratio[mask].max())
            if value>metrics[name][0]:metrics[name]=(value,frame)
        maximum=float(ratio.max())
        if maximum>metrics['whole'][0]:
            metrics['whole']=(maximum,frame)
            worst=[{'vertices':edges[idx].tolist(),'rest_length':float(lengths[idx]),'ratio':float(ratio[idx]),'rest_coords':coords[edges[idx]].tolist()} for idx in np.argsort(ratio)[-5:][::-1]]
    report[label]={'frames_checked':end-start+1,'max_edge_stretch_and_frame':metrics,'worst_edges':worst}

# Isolate the reported failure: arm motion must cause zero movement in the protected face.
rig.animation_data.action=None
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
def evaluated_head():
    ob=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ob.to_mesh()
    values=np.array([list(me.vertices[i].co) for i in sorted(head)]);ob.to_mesh_clear();return values
baseline=evaluated_head()
for side in ('L','R'):
    pb=rig.pose.bones[side+'_Upperarm'];pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(Vector((1,0,0)),.8)
bpy.context.view_layer.update()
report['arm_isolation_max_head_displacement']=float(np.linalg.norm(evaluated_head()-baseline,axis=1).max())
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
report['head_non_head_influence_count']=sum(any(mesh.vertex_groups[g.group].name!='Head' and g.weight>1e-7 for g in mesh.data.vertices[i].groups) for i in head)
weights=[sum(g.weight for g in v.groups if rig.data.bones.get(mesh.vertex_groups[g.group].name) and rig.data.bones[mesh.vertex_groups[g.group].name].use_deform) for v in mesh.data.vertices]
report['weight_check']={'unweighted':sum(w<1e-6 for w in weights),'min':min(weights),'max':max(weights)}
(BASE/'reports/arp_v003_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
a=bpy.data.actions['RP3_run'];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];scene.frame_set(9)
print(json.dumps(report))
