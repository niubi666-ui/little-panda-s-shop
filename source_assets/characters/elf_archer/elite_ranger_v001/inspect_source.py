"""Read-only audit of the archived longbow source."""
import bpy, json
from pathlib import Path
root = Path('E:/ShopGame/source_assets/characters/elf_archer')
bpy.ops.wm.open_mainfile(filepath=str(root/'original/desktop_final_v001/Enemy_v4_ProLongbow39_BowString.blend'))
out = {'objects': [], 'actions': [], 'images': [], 'fps': bpy.context.scene.render.fps}
for o in bpy.data.objects:
    out['objects'].append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'location':list(o.location),'scale':list(o.scale),'dimensions':list(o.dimensions),'action':o.animation_data.action.name if o.animation_data and o.animation_data.action else None,'modifiers':[(m.type,getattr(getattr(m,'object',None),'name',None)) for m in o.modifiers]})
for a in bpy.data.actions:
    out['actions'].append({'name':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots]})
for i in bpy.data.images:
    out['images'].append({'name':i.name,'path':i.filepath,'packed':bool(i.packed_file),'size':list(i.size)})
(root/'elite_ranger_v001/source_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8')
print('RANGER_SOURCE_AUDIT',len(out['objects']),len(out['actions']))
