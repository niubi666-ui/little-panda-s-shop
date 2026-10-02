"""Smooth the ARP shoulder/neck weights while pinning protected face and paws."""
import bpy,json,numpy as np
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
mesh=bpy.data.objects['RedPanda_ARP_Mesh_v003']
regions=json.loads((BASE/'reports/arp_v003_regions.json').read_text())
pinned=set(regions['protected_head'])|set(regions['tail'])|set(regions['rigid_accessories'])
count=len(mesh.data.vertices);groups=len(mesh.vertex_groups)
weights=np.zeros((count,groups))
for v in mesh.data.vertices:
    for g in v.groups:weights[v.index,g.group]=g.weight
original=weights.copy()
neighbors=[[] for _ in range(count)]
for e in mesh.data.edges:
    a,b=e.vertices
    length=max((mesh.data.vertices[a].co-mesh.data.vertices[b].co).length,.003)
    neighbors[a].append((b,1/length));neighbors[b].append((a,1/length))
editable=[v.index for v in mesh.data.vertices if v.index not in pinned and .42<v.co.z<.65 and abs(v.co.y)<.40]
for _ in range(24):
    previous=weights.copy()
    for i in editable:
        pairs=neighbors[i]
        if not pairs:continue
        neighbor_avg=sum(previous[j]*w for j,w in pairs)/sum(w for j,w in pairs)
        weights[i]=.50*previous[i]+.48*neighbor_avg+.02*original[i]
for i in editable:
    vertex=mesh.data.vertices[i]
    for g in list(vertex.groups):mesh.vertex_groups[g.group].remove([i])
    indices=np.argsort(weights[i])[-4:]
    total=sum(weights[i,j] for j in indices)
    for j in indices:
        if weights[i,j]>1e-7:mesh.vertex_groups[int(j)].add([i],float(weights[i,j]/total),'REPLACE')
regions['smoothed_neck_shoulders']=editable
(BASE/'reports/arp_v003_regions.json').write_text(json.dumps(regions,indent=2),encoding='utf-8')
print('Smoothed vertices:',len(editable))
