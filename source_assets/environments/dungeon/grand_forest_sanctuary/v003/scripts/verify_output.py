import bpy, hashlib, json, array, sys
from pathlib import Path
assert bpy.app.background
BASE=Path(__file__).resolve().parents[1]
SOURCE=BASE.parent/'v002/blender/grand_forest_sanctuary_v002.blend'
method=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'cutout'
assert method in ['cutout','opaque_normal']
TARGET=BASE/'blender'/('grand_forest_sanctuary_v003_leaf_'+method+'.blend')
expected_triangles=24842 if method=='cutout' else 74526
def snapshot():
 mesh_hash={};objects={}
 for o in bpy.context.scene.objects:
  if o.name=='Small_fallen_oak_leaves' or o.name=='Camera_Leaf_Inspection':continue
  me=o.data if o.type=='MESH' else None
  if me and me.name not in mesh_hash:
   v=array.array('f',[0])*(len(me.vertices)*3);me.vertices.foreach_get('co',v)
   ix=array.array('i',[0])*len(me.loops);me.loops.foreach_get('vertex_index',ix)
   mesh_hash[me.name]=hashlib.sha256(v.tobytes()+ix.tobytes()).hexdigest()
  objects[o.name]={'type':o.type,'matrix':[v for row in o.matrix_world for v in row],'parent':o.parent.name if o.parent else None,'mesh':mesh_hash.get(me.name) if me else None,'materials':[m.name for m in me.materials] if me else None}
 return objects
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));before=snapshot()
old_leaf=bpy.context.scene.objects['Small_fallen_oak_leaves']
placements=[tuple(old_leaf.data.vertices[i].co) for i in range(0,len(old_leaf.data.vertices),9)]
material_indices=[old_leaf.data.polygons[i].material_index for i in range(0,len(old_leaf.data.polygons),8)]
bpy.ops.wm.open_mainfile(filepath=str(TARGET));after=snapshot()
o=bpy.context.scene.objects['Small_fallen_oak_leaves'];o.data.calc_loop_triangles()
missing=[]
for im in bpy.data.images:
 if im.source=='FILE' and im.users and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).exists():missing.append(im.name)
unchanged=before==after
checks={'all_other_object_geometry_transforms_and_material_assignments_unchanged':unchanged,'leaf_triangle_count_matches':len(o.data.loop_triangles)==expected_triangles,'leaf_count_12421':len(o.data.polygons)==12421,'leaf_material_assignments_preserved':material_indices==[p.material_index for p in o.data.polygons],'leaf_uv_count_matches_loops':len(o.data.uv_layers['LeafUV'].data)==len(o.data.loops),'normal_and_opacity_images_packed':all(bpy.data.images[n].packed_file is not None for n in ['Fallen_oak_leaf_tangent_normal','Fallen_oak_leaf_opacity']),'textures_resolve':not missing,'no_active_bake_scene':not any(s.name.startswith('Temporary_Leaf_Bake') for s in bpy.data.scenes)}
report={'method':method,'triangles':len(o.data.loop_triangles),'checks':checks,'all_pass':all(checks.values()),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'saved_scene_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),'missing_images':missing,'scope':'Saved Blender data validation, not real-time FPS test'}
(BASE/'reports'/('validation_'+method+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
assert report['all_pass']
