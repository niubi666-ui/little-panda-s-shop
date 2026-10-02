import bpy,json
from mathutils import Vector
bpy.ops.import_scene.gltf(filepath='E:/ShopGame/game/assets/characters/red_panda/red_panda_v008.glb')
print('PLAYER_OBJECTS',json.dumps([{'name':o.name,'type':o.type,'dimensions':list(o.dimensions),'parent':o.parent.name if o.parent else None,'visible':not o.hide_render,'materials':[m.name for m in o.data.materials] if o.type=='MESH' else [],'vertices':len(o.data.vertices) if o.type=='MESH' else 0} for o in bpy.context.scene.objects],ensure_ascii=False))
print('ACTIONS',[(a.name,[sl.identifier for sl in a.slots]) for a in bpy.data.actions])
for o in bpy.context.scene.objects:
 if o.type=='ARMATURE':print('BONES',o.name,[(b.name,list(b.head_local)) for b in o.data.bones if 'Hand' in b.name or 'Root' in b.name])
