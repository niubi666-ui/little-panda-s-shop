import bpy, json
from mathutils import Vector
from pathlib import Path
src=Path('E:/ShopGame/source_assets/characters/red_panda/blender/jingling.blend')
bpy.ops.wm.open_mainfile(filepath=str(src),load_ui=False,use_scripts=False)
items=[]
for o in bpy.data.objects:
    d={'name':o.name,'type':o.type,'location':list(o.location),'rotation':list(o.rotation_euler),'scale':list(o.scale),'dimensions':list(o.dimensions),'parent':o.parent.name if o.parent else None,'hidden':o.hide_render}
    if o.type=='MESH':
        coords=[o.matrix_world@Vector(c) for c in o.bound_box]
        d.update(vertices=len(o.data.vertices),polygons=len(o.data.polygons),bounds=[[min(c[i] for c in coords) for i in range(3)],[max(c[i] for c in coords) for i in range(3)]],materials=[m.name if m else None for m in o.data.materials],groups=[g.name for g in o.vertex_groups],modifiers=[(m.name,m.type) for m in o.modifiers])
    items.append(d)
report={'version':bpy.app.version_string,'objects':items,'images':[{'name':im.name,'path':im.filepath,'packed':bool(im.packed_file),'size':list(im.size)} for im in bpy.data.images]}
print('SOURCE_INSPECT '+json.dumps(report,ensure_ascii=False))
out=Path('E:/ShopGame/source_assets/characters/elf_archer/reports');out.mkdir(parents=True,exist_ok=True)
(out/'source_inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
