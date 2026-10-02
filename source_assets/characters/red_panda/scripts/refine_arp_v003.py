"""Anatomical cleanup after the actual ARP heat-map bind; no topology changes."""
import bpy,json
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
mesh=bpy.data.objects['RedPanda_ARP_Mesh_v003']
source=bpy.data.objects['RedPanda_Mesh_v002']
rig=bpy.data.objects['RedPanda_ARP_Rig_v003']
assert max((a.co-b.co).length for a,b in zip(mesh.data.vertices,source.data.vertices))<1e-7
tail=set(json.loads((BASE/'reports/rig_v002_changes.json').read_text())['tail_vertex_ids'])
report={'protected_head':[],'neck_transition':[],'palm':[],'arm_domains':[],'rigid_accessories':[],'tail':sorted(tail)}

def smooth(t):
    t=max(0.,min(1.,t));return t*t*(3-2*t)

def assign(vertex,weights):
    weights={n:w for n,w in weights.items() if w>1e-7 and n in rig.data.bones and rig.data.bones[n].use_deform}
    assert weights, f'No anatomical weights for vertex {vertex.index}'
    weights=dict(sorted(weights.items(),key=lambda v:-v[1])[:4])
    total=sum(weights.values())
    for g in list(vertex.groups):mesh.vertex_groups[g.group].remove([vertex.index])
    for name,w in weights.items():
        vg=mesh.vertex_groups.get(name) or mesh.vertex_groups.new(name=name)
        vg.add([vertex.index],w/total,'REPLACE')

for v in mesh.data.vertices:
    x,y,z=v.co
    weights={mesh.vertex_groups[g.group].name:g.weight for g in v.groups}
    if v.index in tail:
        assign(v,{source.vertex_groups[g.group].name:g.weight for g in source.data.vertices[v.index].groups})
        continue
    # No tail influence outside its identified connected component.
    weights={n:w for n,w in weights.items() if not n.startswith('Tail_')}
    # Large stylized head must not borrow the neighboring arm's influences.
    if z>=.65:
        assign(v,{'Head':1.});report['protected_head'].append(v.index);continue
    if x>0 and .48<z<.64 and abs(y)>.355:
        side='L' if y>0 else 'R'
        allowed={side+'_Hand',side+'_ForearmTwist01',side+'_ForearmTwist02'}
        weights={n:w for n,w in weights.items() if n in allowed}
        if not weights:weights={side+'_ForearmTwist02':1.}
        total=sum(weights.values());weights={n:w/total for n,w in weights.items()}
        t=smooth((abs(y)-.355)/(.427-.355))
        weights={n:w*(1-t) for n,w in weights.items()}
        weights[side+'_Hand']=weights.get(side+'_Hand',0)+t
        report['palm'].append(v.index)
    elif .44<z<.64 and abs(y-.015)>.22:
        side='L' if y>.015 else 'R'
        keep={n:w for n,w in weights.items() if n.startswith(side+'_') and any(k in n for k in ('Hand','arm','Clavicle'))}
        if keep:weights=keep;report['arm_domains'].append(v.index)
    if not weights:weights={'Waist':1.}
    assign(v,weights)

# Accessory islands on the belt are rigid objects, not skin that should stretch with thighs.
adj=[[] for v in mesh.data.vertices]
for e in mesh.data.edges:
    a,b=e.vertices;adj[a].append(b);adj[b].append(a)
for seed in (2419,19,68,2575,37,2639):
    seen={seed};stack=[seed]
    while stack:
        for j in adj[stack.pop()]:
            if j not in seen:seen.add(j);stack.append(j)
    for i in seen:assign(mesh.data.vertices[i],{'Waist':1.})
    report['rigid_accessories'].extend(sorted(seen))

report['binding_method']='Auto-Rig Pro 3.78.46 arp.bind_to_rig HEAT_MAP split parts, then anatomical cleanup'
report['skeleton_method']='Existing animation-compatible 46-bone skeleton retained; not an ARP control-rig template'
(BASE/'reports/arp_v003_regions.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
rig.data.pose_position='POSE'
bpy.context.scene.frame_set(9)
print(json.dumps({k:len(v) for k,v in report.items() if isinstance(v,list)}))
