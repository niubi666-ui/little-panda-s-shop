"""Read-only, count each shared evaluated mesh once (not per placed object)."""
import bpy,json,collections,hashlib
from pathlib import Path
assert bpy.app.background
BASE=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
def category(o):
 n=o.name;role=o.get('asset_role','')
 if n.startswith('LIGHTING_ONLY'):return 'lighting_gobo'
 if n=='Small_fallen_oak_leaves':return 'small_fallen_leaves'
 if o.get('tree_source'):return 'sacred_trees'
 if n.startswith('Fern_clump'):return 'ferns'
 if n.startswith('White_meadow_flower_spray'):return 'bellflowers'
 if n.startswith('Bronze_votive'):return 'bronze_lamps'
 if n.startswith('Medallion_') and '_tessera_' in n:return 'mosaic_border_tesserae'
 if role:return role
 return 'other'
def mesh_info(me):
 me.calc_loop_triangles()
 return {'mesh':me.name,'vertices':len(me.vertices),'faces':len(me.polygons),'triangles':len(me.loop_triangles)}
def collect(objects):
 records={};nonmesh=collections.Counter()
 for o,source in objects:
  if o.type!='MESH':nonmesh[o.type]+=1;continue
  me=o.data;key=me.as_pointer()
  if key not in records:records[key]={**mesh_info(me),'category':category(source),'objects':0,'example':source.name,'camera_visible_example':source.visible_camera,'source_data_users':source.data.users if source.type=='MESH' else None,'modifiers':[m.type for m in source.modifiers]}
  records[key]['objects']+=1
 return list(records.values()),dict(nonmesh)
raw,raw_nonmesh=collect((o,o) for o in scene.objects)
dg=bpy.context.evaluated_depsgraph_get()
evaluated,eval_nonmesh=collect((i.object,i.object.original) for i in dg.object_instances)
def summary(records):
 return {k:sum(r[k] for r in records) for k in ['vertices','faces','triangles']}|{'unique_meshes':len(records),'mesh_occurrences':sum(r['objects'] for r in records)}
group={}
for r in evaluated:
 g=group.setdefault(r['category'],{'unique_meshes':0,'mesh_occurrences':0,'vertices':0,'faces':0,'triangles':0})
 g['unique_meshes']+=1;g['mesh_occurrences']+=r['objects']
 for k in ['vertices','faces','triangles']:g[k]+=r[k]
curves=[]
for o in dg.objects:
 if o.type in ['CURVE','FONT','SURFACE','META']:
  me=o.to_mesh()
  if me:curves.append({'object':o.name,'type':o.type,**mesh_info(me)})
  o.to_mesh_clear()
report={'date':'2026-10-02','file':bpy.data.filepath,'file_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'scope':'Count each actual Mesh datablock pointer once; no multiplication by objects. Evaluated list uses existing dependency-graph mesh data, never copies meshes for deduplication.','raw':summary(raw),'evaluated_meshes':summary(evaluated),'blender_statistics':scene.statistics(bpy.context.view_layer),'groups':dict(sorted(group.items(),key=lambda kv:-kv[1]['triangles'])),'evaluated_records':sorted(evaluated,key=lambda r:-r['triangles']),'raw_records':sorted(raw,key=lambda r:-r['triangles']),'nonmesh_raw':raw_nonmesh,'nonmesh_evaluated':eval_nonmesh,'converted_nonmesh_diagnostic':curves}
(BASE/'reports/unique_geometry_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['raw','evaluated_meshes','blender_statistics','groups','nonmesh_evaluated','converted_nonmesh_diagnostic']},ensure_ascii=False))
