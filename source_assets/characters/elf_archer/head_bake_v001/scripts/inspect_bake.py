import bpy, json, numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
bpy.ops.wm.open_mainfile(filepath=str(B/'original/head_body_session_source.blend'),load_ui=False,use_scripts=False)
hi=bpy.data.objects['elf character 3d model'];lo=bpy.data.objects['elf character 3d model_Clone1']
def bounds(o):
    vs=[v.co for v in o.data.vertices]
    return [list(map(float,[min(v[i] for v in vs) for i in range(3)])),list(map(float,[max(v[i] for v in vs) for i in range(3)]))]
hb,lb=bounds(hi),bounds(lo)
shift=(Vector(hb[0])+Vector(hb[1])-Vector(lb[0])-Vector(lb[1]))*.5
print('BOUNDS',hb,lb,'SHIFT',list(shift),flush=True)
tree=BVHTree.FromPolygons([v.co for v in hi.data.vertices],[p.vertices[:] for p in hi.data.polygons],all_triangles=True)
dist=[];signed=[]
for v in lo.data.vertices:
    hit,n,idx,d=tree.find_nearest(v.co+shift)
    dist.append(d);signed.append((hit-v.co-shift).dot(v.normal))
report={'high_bounds':hb,'low_bounds':lb,'alignment_shift':list(shift),'distance_quantiles':np.quantile(dist,[0,.5,.9,.95,.99,1]).tolist(),'signed_quantiles':np.quantile(signed,[0,.5,.9,.95,.99,1]).tolist(),'images':[{'name':im.name,'size':list(im.size),'packed':bool(im.packed_file)} for im in bpy.data.images if im.type=='IMAGE']}
(B/'reports/inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report),flush=True)
