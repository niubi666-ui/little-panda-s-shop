import bpy, json
from pathlib import Path
from mathutils import Vector
root = Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
bpy.ops.wm.read_factory_settings(use_empty=True)
report = []
for name in ['00_Combat_Idle', '01_Combo_Attack_01_01', 'Nodachi_Sword']:
    before = set(bpy.data.objects)
    actions_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(root/'fbx'/f'{name}.fbx'), use_anim=True, automatic_bone_orientation=False)
    objs = list(set(bpy.data.objects)-before)
    entry = {'file':name, 'objects': [], 'actions':[]}
    for obj in objs:
        data = {'name': obj.name, 'type':obj.type, 'location':list(obj.location), 'rotation':list(obj.rotation_euler),
                'scale':list(obj.scale),'dimensions':list(obj.dimensions), 'parent':obj.parent.name if obj.parent else None}
        if obj.type == 'ARMATURE':
            data['bones'] = [{'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local),
                              'matrix':[list(row) for row in b.matrix_local]} for b in obj.data.bones]
        if obj.type == 'MESH':
            data['vertices'] = len(obj.data.vertices)
            data['materials'] = [m.name if m else None for m in obj.data.materials]
            data['local_bounds'] = [list(v) for v in obj.bound_box]
        entry['objects'].append(data)
    for a in set(bpy.data.actions)-actions_before:
        entry['actions'].append({'name':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots]})
    report.append(entry)
    for obj in objs:
        bpy.data.objects.remove(obj,do_unlink=True)
(root/'reports/fbx_inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('NODACHI_INSPECT_DONE')
