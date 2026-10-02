import bpy, json, hashlib, math
from pathlib import Path
base=Path(bpy.data.filepath).parent.parent
build=json.loads((base/'reports/build_report.json').read_text(encoding='utf-8'))
source=Path(build['source'])
expected='f9b39aae420fb8e8d2a7a6dd2f3e590dc1d779aa558158067561ba374dfab7e2'
images=[{'name':i.name,'packed':bool(i.packed_file),'path':bpy.path.abspath(i.filepath),'local_exists':Path(bpy.path.abspath(i.filepath)).is_file()} for i in bpy.data.images if i.source=='FILE']
meshes={o.data.name:o.data for o in bpy.context.scene.objects if o.type=='MESH'}
for m in meshes.values():m.calc_loop_triangles()
checks={
 'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==expected,
 'all_15_source_roles_used':len(build['item2_roles_used'])==15 and all(build['item2_roles_used'].values()),
 'all_images_embedded':bool(images) and all(i['packed'] for i in images),
 'all_texture_copies_resolve':all(i['local_exists'] for i in images),
 'finite_vertices':all(math.isfinite(c) for m in meshes.values() for v in m.vertices for c in v.co),
 'hero_camera_exists':bpy.context.scene.camera.name=='Camera_Hero_Daylight',
}
report={'checks':checks,'objects':len(bpy.context.scene.objects),'unique_mesh_triangles':sum(len(m.loop_triangles) for m in meshes.values()),'instanced_mesh_triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'images':images,'scope':'Blender source-art checks only; no Godot performance, collisions or navigation validation.'}
(base/'reports/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='images'},ensure_ascii=False))
assert all(checks.values()),checks
