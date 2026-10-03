import bpy, time, json, math, shutil
from pathlib import Path
from mathutils import Vector
assert bpy.app.background
BASE=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
leaf=scene.objects['Small_fallen_oak_leaves'];cutout=leaf.data
SOURCE=BASE.parent/'v002/blender/grand_forest_sanctuary_v002.blend'
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=['Small_fallen_oak_leaves']
source_object=dst.objects[0];original=source_object.data
bpy.data.objects.remove(source_object,do_unlink=True)
count=len(original.vertices)//9
p=[v.co.copy() for v in original.vertices[:9]]
ln=(p[6]-p[2]).length/.58
axis=Vector((p[4].x-p[0].x,p[4].y-p[0].y,0)).normalized();side=Vector((-axis.y,axis.x,0))
rel=[((v-p[0]).dot(axis)/ln,(v-p[0]).dot(side)/ln) for v in p]
x0=min(v[0] for v in rel)-.02;x1=max(v[0] for v in rel)+.02;y0=min(v[1] for v in rel)-.02;y1=max(v[1] for v in rel)+.02
shape_uv=[((x-x0)/(x1-x0),(y-y0)/(y1-y0)) for x,y in rel[:8]]
verts=[];faces=[]
for i in range(count):
 # Same projected eight-point silhouette, one planar n-gon; six triangles.
 src=[original.vertices[i*9+j].co.copy() for j in range(8)]
 for v in src:v.z=src[0].z;verts.append(v)
 faces.append(tuple(i*8+j for j in reversed(range(8))))
opaque=bpy.data.meshes.new('Small_fallen_oak_leaves_opaque_normal_mesh');opaque.from_pydata(verts,[],faces);opaque.update()
uv=opaque.uv_layers.new(name='LeafUV')
for loop in opaque.loops:uv.data[loop.index].uv=shape_uv[loop.vertex_index%8]
normal=bpy.data.images['Fallen_oak_leaf_tangent_normal']
for source_mat in original.materials:
 mat=source_mat.copy();mat.name=source_mat.name+'_ground_leaf_opaque_normal_v003'
 n=mat.node_tree.nodes;l=mat.node_tree.links
 tx=n.new('ShaderNodeTexImage');tx.image=normal;nm=n.new('ShaderNodeNormalMap');nm.uv_map='LeafUV'
 co=n.new('ShaderNodeUVMap');co.uv_map='LeafUV';l.new(co.outputs['UV'],tx.inputs['Vector']);l.new(tx.outputs['Color'],nm.inputs['Color'])
 bump=next(node for node in n if node.type=='BUMP' and not node.inputs['Normal'].is_linked);l.new(nm.outputs[0],bump.inputs['Normal'])
 for node in n:
  if node.type=='BSDF_TRANSLUCENT':l.new(nm.outputs[0],node.inputs['Normal'])
 opaque.materials.append(mat)
for i,poly in enumerate(opaque.polygons):poly.material_index=original.polygons[i*8].material_index
opaque.calc_loop_triangles();assert len(opaque.loop_triangles)==count*6

# The loaded cutout file remains preserved; save opaque geometry separately.
leaf.data=opaque;leaf['optimization']='v003: opaque 8-point silhouette + tangent normal, no alpha';leaf['optimized_triangles']=count*6
scene.camera=bpy.data.objects['Camera_Gameplay']
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/grand_forest_sanctuary_v003_leaf_opaque_normal.blend'))

pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.refresh_devices()
for d in pref.devices:d.use=d.type=='OPTIX'
scene.render.engine='CYCLES';scene.cycles.device='GPU';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=562;scene.render.resolution_percentage=100
scene.render.use_persistent_data=True;scene.camera=bpy.data.objects['Camera_Leaf_Inspection']
timings={}
for name,mesh in [('original',original),('cutout',cutout),('opaque_normal',opaque)]:
 leaf.data=mesh;timings[name]=[]
 for i in range(2):
  scene.render.filepath=str(BASE/'previews'/('benchmark_'+name+'.png'))
  start=time.perf_counter();bpy.ops.render.render(write_still=True);timings[name].append(time.perf_counter()-start)
  print('MEASURE',name,i,timings[name][-1],flush=True)
report={'method':'Two renders per method in one independent Cycles OptiX process; second render after warmup, persistent data enabled. Limited local close-up, not GPU frame-time or Godot benchmark.','samples':32,'resolution':[900,562],'seconds':timings,'triangles':{'original':count*8,'cutout':count*2,'opaque_normal':count*6},'leaf_count':count,'source_geometry_note':'8-point projected silhouette retained by opaque version; ridge supplied by same baked normal map.'}
(BASE/'reports/method_comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
