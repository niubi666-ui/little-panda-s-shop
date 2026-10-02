import bpy,json
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
ob=bpy.data.objects['RedPanda_ARP_Mesh_v003']
regions=json.loads((BASE/'reports/arp_v003_regions.json').read_text())
protected=set(regions['protected_head'])|set(regions['tail'])|set(regions['rigid_accessories'])
for v in ob.data.vertices:
    if v.index in protected or v.co.z<.47:continue
    side='L' if v.co.y>.015 else 'R';other='R' if side=='L' else 'L'
    weights={ob.vertex_groups[g.group].name:g.weight for g in v.groups if not ob.vertex_groups[g.group].name.startswith(other+'_')}
    d=abs(v.co.y-.015)
    if d<.23:
        t=max(0.,min(1.,(d-.105)/.125));t=t*t*(3-2*t)
        total=sum(weights.values())
        weights={n:w/total*t for n,w in weights.items()} if total else {}
        weights['Spine02']=weights.get('Spine02',0)+1-t
    if not weights:weights={'Spine02':1.}
    weights=dict(sorted(weights.items(),key=lambda p:-p[1])[:4]);total=sum(weights.values())
    for g in list(v.groups):ob.vertex_groups[g.group].remove([v.index])
    for n,w in weights.items():
        if w>1e-7:ob.vertex_groups[n].add([v.index],w/total,'REPLACE')
print('Cleaned torso and opposite-arm influences')
