import bpy,json,hashlib,array
from pathlib import Path
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
path=Path('D:/Users/陈旭辉/Desktop/临时建模/头部_烘焙结果_v001.blend')
bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
report=json.loads((B/'reports/bake_report.json').read_text(encoding='utf-8'))
for name,original in report['original_signatures'].items():
 o=bpy.data.objects[name];a=array.array('f',[0])*len(o.data.vertices)*3;o.data.vertices.foreach_get('co',a)
 current=[hashlib.sha256(a.tobytes()).hexdigest(),len(o.data.polygons),[list(r) for r in o.matrix_world],[m.name if m else None for m in o.data.materials]]
 assert current==original,name
ob=bpy.data.objects['04_Head_Low_Baked'];ob.data.calc_loop_triangles();assert len(ob.data.loop_triangles)==26208
assert ob.data.uv_layers.active.name=='Head_BakeUV'
mat=ob.data.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
normal=bs.inputs['Normal'].links[0].from_node
assert normal.type=='NORMAL_MAP' and normal.uv_map=='Head_BakeUV'
ni=normal.inputs['Color'].links[0].from_node.image;bi=bs.inputs['Base Color'].links[0].from_node.image
assert ni.packed_file and bi.packed_file and ni.colorspace_settings.name=='Non-Color'
assert list(ni.size)==[4096,4096] and list(bi.size)==[4096,4096]
(B/'reports/verification.json').write_text(json.dumps({'desktop_reopen':True,'original_objects_unchanged':list(report['original_signatures']),'triangles':26208,'normal_packed':True,'basecolor_packed':True,'bake_uv':'Head_BakeUV','godot_tested':False,'rig_tested':False},ensure_ascii=False,indent=2),encoding='utf-8')
print('VERIFIED: desktop output reopens, original bodies/heads unchanged, packed 4K maps connected to baked head.')
