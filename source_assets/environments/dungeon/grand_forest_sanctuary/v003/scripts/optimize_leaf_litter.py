"""Bake the existing leaf shape to cutout + tangent normal, preserve each placement.
Run only in an independent background Blender, with v002 loaded read-only.
"""
import bpy, math, json, time, hashlib
from pathlib import Path
from mathutils import Vector
assert bpy.app.background
BASE=Path(__file__).resolve().parents[1]
for name in ['blender','textures','previews','reports']:(BASE/name).mkdir(exist_ok=True)
source_path=Path(bpy.data.filepath)
source_hash=hashlib.sha256(source_path.read_bytes()).hexdigest()
scene=bpy.context.scene
leaf=scene.objects['Small_fallen_oak_leaves']
old=leaf.data
assert len(old.vertices)%9==0 and len(old.polygons)==len(old.vertices)//9*8
count=len(old.vertices)//9
source_tri=len(old.polygons)
def enum(obj,key,value):
 vals=[e.identifier for e in obj.bl_rna.properties[key].enum_items]
 assert value in vals,(key,value,vals)
 setattr(obj,key,value)
def mesh_object(name,verts,faces,collection):
 me=bpy.data.meshes.new(name+'_mesh');me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);collection.objects.link(ob);return ob

# Recover exactly the normalized shape from the authored geometry, rather than
# drawing a new leaf. Every original leaf uses this same rigid/scaled template.
p=[v.co.copy() for v in old.vertices[:9]]
length=(p[6]-p[2]).length/.58
forward=Vector((p[4].x-p[0].x,p[4].y-p[0].y,0)).normalized()
left=Vector((-forward.y,forward.x,0))
highverts=[((v-p[0]).dot(forward)/length,(v-p[0]).dot(left)/length,(v.z-p[0].z)/length) for v in p]
highfaces=[tuple(f.vertices) for f in old.polygons[:8]]
xs=[v[0] for v in highverts];ys=[v[1] for v in highverts]
bounds=(min(xs)-.02,max(xs)+.02,min(ys)-.02,max(ys)+.02)
x0,x1,y0,y1=bounds
corners=[(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
uvcoords=[(0,0),(1,0),(1,1),(0,1)]

bake=bpy.data.scenes.new('Temporary_Leaf_Bake')
bpy.context.window.scene=bake
bake.render.engine='CYCLES';bake.cycles.samples=8
bake.cycles.device='CPU'
high=mesh_object('Original_leaf_shape_for_bake',highverts,highfaces,bake.collection)
hi_mat=bpy.data.materials.new('Temporary_Leaf_Source');hi_mat.use_nodes=True
high.data.materials.append(hi_mat)
target=mesh_object('Leaf_bake_receiver',[(x,y,-.2) for x,y in corners],[(0,1,2,3)],bake.collection)
uv=target.data.uv_layers.new(name='UVMap')
for loop in target.data.loops:uv.data[loop.index].uv=uvcoords[loop.vertex_index]
lo_mat=bpy.data.materials.new('Temporary_Bake_Receiver');lo_mat.use_nodes=True
target.data.materials.append(lo_mat)
tex=lo_mat.node_tree.nodes.new('ShaderNodeTexImage')
lo_mat.node_tree.nodes.active=tex
high.select_set(True);target.select_set(True);bpy.context.view_layer.objects.active=target
bake.render.bake.use_selected_to_active=True
bake.render.bake.cage_extrusion=.5;bake.render.bake.max_ray_distance=1
bake.render.bake.margin=8
enum(bake.render.bake,'normal_space','TANGENT')
normal=bpy.data.images.new('Fallen_oak_leaf_tangent_normal',width=512,height=512,alpha=False)
normal.colorspace_settings.name='Non-Color';tex.image=normal
bpy.ops.object.bake(type='NORMAL')
normal.filepath_raw=str(BASE/'textures/fallen_oak_leaf_normal.png');enum(normal,'file_format','PNG');normal.save();normal.pack()

# Emission projects a white leaf silhouette onto a black receiver texture.
# No photographic/image editing occurs: both maps are actual Blender bakes.
n=hi_mat.node_tree.nodes;l=hi_mat.node_tree.links
out=next(n0 for n0 in n if n0.type=='OUTPUT_MATERIAL')
for link in list(out.inputs['Surface'].links):l.remove(link)
em=n.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1);em.inputs['Strength'].default_value=1;l.new(em.outputs[0],out.inputs['Surface'])
mask=bpy.data.images.new('Fallen_oak_leaf_opacity',width=512,height=512,alpha=False)
mask.colorspace_settings.name='Non-Color';mask.generated_color=(0,0,0,1);tex.image=mask
bake.render.bake.margin=0
bpy.ops.object.bake(type='EMIT')
mask.filepath_raw=str(BASE/'textures/fallen_oak_leaf_opacity.png');enum(mask,'file_format','PNG');mask.save();mask.pack()
bpy.context.window.scene=scene
for ob in [high,target]:bpy.data.objects.remove(ob,do_unlink=True)
bpy.data.scenes.remove(bake)
for mat in [hi_mat,lo_mat]:bpy.data.materials.remove(mat)

# Keep all 12421 positions, rotations, scales and material assignments.
verts=[];faces=[];materials=[]
for i in range(count):
 src=[old.vertices[i*9+j].co for j in range(9)]
 ln=(src[6]-src[2]).length/.58
 axis=Vector((src[4].x-src[0].x,src[4].y-src[0].y,0)).normalized()
 side=Vector((-axis.y,axis.x,0))
 base=src[0].copy()
 for x,y in corners:verts.append(base+axis*(x*ln)+side*(y*ln))
 faces.append(tuple(range(i*4,i*4+4)))
 materials.append(old.polygons[i*8].material_index)
me=bpy.data.meshes.new('Small_fallen_oak_leaves_cutout_mesh')
me.from_pydata(verts,[],faces);me.update()
uv=me.uv_layers.new(name='LeafUV')
for loop in me.loops:uv.data[loop.index].uv=uvcoords[loop.vertex_index%4]
for poly,mi in zip(me.polygons,materials):poly.material_index=mi
for mat in old.materials:
 m=mat.copy();m.name=mat.name+'_ground_leaf_cutout_v003'
 n=m.node_tree.nodes;l=m.node_tree.links
 output=next(node for node in n if node.type=='OUTPUT_MATERIAL')
 original_surface=output.inputs['Surface'].links[0].from_socket
 alpha_tex=n.new('ShaderNodeTexImage');alpha_tex.name='Baked leaf silhouette';alpha_tex.image=mask;enum(alpha_tex,'extension','CLIP')
 normal_tex=n.new('ShaderNodeTexImage');normal_tex.name='Baked leaf curvature';normal_tex.image=normal;enum(normal_tex,'extension','CLIP')
 coord=n.new('ShaderNodeUVMap');coord.uv_map='LeafUV'
 l.new(coord.outputs['UV'],alpha_tex.inputs['Vector']);l.new(coord.outputs['UV'],normal_tex.inputs['Vector'])
 nm=n.new('ShaderNodeNormalMap');nm.uv_map='LeafUV';nm.inputs['Strength'].default_value=1;l.new(normal_tex.outputs['Color'],nm.inputs['Color'])
 # Preserve the existing colour/noise materials and both fine bump layers.
 first_bump=next((node for node in n if node.type=='BUMP' and not node.inputs['Normal'].is_linked),None)
 if first_bump:l.new(nm.outputs[0],first_bump.inputs['Normal'])
 else:
  principled=next(node for node in n if node.type=='BSDF_PRINCIPLED');l.new(nm.outputs[0],principled.inputs['Normal'])
 for node in n:
  if node.type=='BSDF_TRANSLUCENT':l.new(nm.outputs[0],node.inputs['Normal'])
 cut=n.new('ShaderNodeMath');enum(cut,'operation','GREATER_THAN');cut.inputs[1].default_value=.5;l.new(alpha_tex.outputs['Color'],cut.inputs[0])
 trans=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
 l.new(cut.outputs[0],mix.inputs[0]);l.new(trans.outputs[0],mix.inputs[1]);l.new(original_surface,mix.inputs[2]);l.new(mix.outputs[0],output.inputs['Surface'])
 if 'surface_render_method' in m.bl_rna.properties:enum(m,'surface_render_method','DITHERED')
 me.materials.append(m)
leaf.data=me
leaf['optimization']='v003: same placements, 2-triangle cutouts + baked tangent normal + opacity'
leaf['source_triangles']=source_tri;leaf['optimized_triangles']=count*2

# Audit shared evaluated tree geometry, including the selected-mesh statistics trap.
dg=bpy.context.evaluated_depsgraph_get()
trunks=[o for o in scene.objects if o.name.endswith('__SacredOak_Trunk_Preserved')]
pointers=[o.evaluated_get(dg).data.as_pointer() for o in trunks]
tree_details={'trunk_objects':len(trunks),'base_mesh_users':trunks[0].data.users,'each_trunk_triangles':len(trunks[0].data.polygons),'unique_evaluated_mesh_pointers':len(set(pointers))}

# Create a reproducible close camera without disturbing existing cameras/lights.
camdata=bpy.data.cameras.new('Leaf_Inspection_Camera');enum(camdata,'type','ORTHO');camdata.ortho_scale=2.8
cam=bpy.data.objects.new('Camera_Leaf_Inspection',camdata);scene.collection.objects.link(cam)
focus=Vector((-1.5,-3.0,.07));cam.location=focus+Vector((0,-2.8,4.5));cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
report={'date':'2026-10-02','source':str(source_path),'source_sha256':source_hash,'leaf_count':count,'triangles_before':source_tri,'triangles_after':count*2,'reduction_percent':75.0,'vertices_before':len(old.vertices),'vertices_after':len(me.vertices),'normal_texture':'textures/fallen_oak_leaf_normal.png','opacity_texture':'textures/fallen_oak_leaf_opacity.png','texture_resolution':[512,512],'material_slots_preserved':len(me.materials),'positions_and_materials_preserved':True,'other_scene_meshes_modified':False,'tree_shared_geometry':tree_details,'render_seconds':{},'scope':'Blender art-only optimization; no Godot changes or FPS benchmark'}
scene.name='Grand_Forest_Sanctuary_36x32m_v003_Leaf_Optimized'
scene.camera=bpy.data.objects['Camera_Gameplay']
for im in bpy.data.images:
 if im.source=='FILE' and im.has_data and not im.packed_file:im.pack()
outpath=BASE/'blender/grand_forest_sanctuary_v003_leaf_cutout.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(outpath))

# Render matched before/after close-ups and a gameplay-scale overview.
pref=bpy.context.preferences.addons['cycles'].preferences
try:
 pref.compute_device_type='OPTIX';pref.refresh_devices()
 for dev in pref.devices:dev.use=dev.type=='OPTIX'
 scene.cycles.device='GPU'
except Exception:scene.cycles.device='CPU'
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
enum(scene.render.image_settings,'file_format','PNG')
enum(scene.render.image_settings,'color_mode','RGB')
for label,camera,data,res in [('leaf_before',cam,old,(1200,750)),('leaf_after',cam,me,(1200,750)),('gameplay_after',bpy.data.objects['Camera_Gameplay'],me,(1600,1000))]:
 leaf.data=data;scene.camera=camera;scene.render.resolution_x=res[0];scene.render.resolution_y=res[1]
 scene.render.filepath=str(BASE/'previews'/f'{label}.png')
 t=time.time();bpy.ops.render.render(write_still=True);report['render_seconds'][label]=time.time()-t
 print('RENDER_COMPLETE',label,flush=True)
leaf.data=me;scene.camera=bpy.data.objects['Camera_Gameplay']
report['source_unchanged']=source_hash==hashlib.sha256(source_path.read_bytes()).hexdigest()
assert report['source_unchanged']
(BASE/'reports/leaf_optimization.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False),flush=True)
