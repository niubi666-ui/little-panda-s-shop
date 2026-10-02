import bpy,bmesh,json
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
ob=bpy.data.objects['RedPanda_ARP_Mesh_v003']
backup=ob.data.copy();backup.name='ARP_v003_before_head_seam'
info=json.loads((BASE/'reports/arp_v003_head_faces.json').read_text())
regions=json.loads((BASE/'reports/arp_v003_regions.json').read_text())
bm=bmesh.new();bm.from_mesh(ob.data)
bm.verts.ensure_lookup_table();bm.faces.ensure_lookup_table()
orig=bm.verts.layers.int.new('source_vertex_index')
flag=bm.faces.layers.int.new('head_region')
for v in bm.verts:v[orig]=v.index
ids=set(info['faces'])
for f in bm.faces:f[flag]=int(f.index in ids)
seams=[e for e in bm.edges if any(f[flag] for f in e.link_faces) and any(not f[flag] for f in e.link_faces)]
bmesh.ops.split_edges(bm,edges=seams)
bm.verts.index_update();bm.faces.index_update()
head={v.index for f in bm.faces if f[flag] for v in f.verts}
body={v.index for f in bm.faces if not f[flag] for v in f.verts}
assert not head.intersection(body)
for k,values in list(regions.items()):
    if isinstance(values,list):
        old=set(values);regions[k]=[v.index for v in bm.verts if v[orig] in old]
regions['protected_head']=sorted(head)
regions['head_seam_edges_split']=len(seams)
bm.to_mesh(ob.data);bm.free();ob.data.update()
for v in ob.data.vertices:
    weights={ob.vertex_groups[g.group].name:g.weight for g in v.groups}
    if v.index in head:weights={'Head':1.}
    elif v.co.z>.48:
        weights={n:w for n,w in weights.items() if n!='Head'}
        if not weights:weights={'Neck':1.}
    else:continue
    for g in list(v.groups):ob.vertex_groups[g.group].remove([v.index])
    total=sum(weights.values())
    for name,w in weights.items():ob.vertex_groups[name].add([v.index],w/total,'REPLACE')
(BASE/'reports/arp_v003_regions.json').write_text(json.dumps(regions,indent=2),encoding='utf-8')
print({'head_vertices':len(head),'vertices':len(ob.data.vertices),'split_edges':len(seams)})
bpy.context.scene.frame_set(57)
