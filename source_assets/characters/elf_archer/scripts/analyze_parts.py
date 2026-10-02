import bpy,json,numpy as np
from mathutils import Vector
from pathlib import Path
bpy.ops.wm.open_mainfile(filepath='E:/ShopGame/source_assets/characters/red_panda/blender/jingling.blend',load_ui=False,use_scripts=False)
out={}
for o in [o for o in bpy.data.objects if o.type=='MESH']:
    pts=np.array([o.matrix_world@v.co for v in o.data.vertices])
    samples=[]
    for z in np.arange(.05,1,.05):
        a=pts[np.abs(pts[:,2]-z)<.008]
        if len(a):samples.append({'z':round(float(z),3),'count':len(a),'xmin':float(a[:,0].min()),'xmax':float(a[:,0].max()),'ymin':float(a[:,1].min()),'ymax':float(a[:,1].max())})
    out[o.name]=samples
print(json.dumps(out))
Path('E:/ShopGame/source_assets/characters/elf_archer/reports/sections.json').write_text(json.dumps(out,indent=2))
