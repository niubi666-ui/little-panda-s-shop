"""Export the approved master without saving it. Bake material response, never lights.

Repeated UV assets/leaf veins use shared material swatches; spatial procedural stone
and pottery are baked on their actual geometry. Keep interactive props independent.
"""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path('E:/ShopGame')
BASE=ROOT/'source_assets/environments/dungeon/room_compositions/v004'
OUT=ROOT/'game/assets/environments/room_compositions_v004'
OUT.mkdir(parents=True,exist_ok=True)
TEXTURES=BASE/'textures/runtime_bakes'
TEXTURES.mkdir(parents=True,exist_ok=True)
SOURCE=BASE/'blender/forest_compositions_review_v004.blend'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert bpy.app.background
scenes=list(bpy.data.scenes)
def select(obs):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
def principled(m):return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def save_image(im,name):
 im.filepath_raw=str(TEXTURES/(name+'.png'));im.file_format='PNG';im.save()
def bake_material(ob,original,label,size,spatial=False):
 """Non-overlapping active UV is the bake destination; source UV remains explicit."""
 mat=original.copy();ob.data.materials.clear();ob.data.materials.append(mat)
 n,l=mat.node_tree.nodes,mat.node_tree.links;p=principled(mat)
 out=next(n for n in n if n.type=='OUTPUT_MATERIAL')
 original_surface=out.inputs['Surface'].links[0].from_socket
 albedo=bpy.data.images.new(label+'_albedo',width=size,height=size,alpha=False)
 target=n.new('ShaderNodeTexImage');target.image=albedo;n.active=target
 emission=n.new('ShaderNodeEmission')
 if p.inputs['Base Color'].is_linked:l.new(p.inputs['Base Color'].links[0].from_socket,emission.inputs['Color'])
 else:emission.inputs['Color'].default_value=p.inputs['Base Color'].default_value
 l.new(emission.outputs[0],out.inputs['Surface'])
 select([ob]);bpy.ops.object.bake(type='EMIT',use_clear=True,margin=8)
 save_image(albedo,label+'_albedo')
 l.new(p.outputs[0],out.inputs['Surface'])
 normal=None
 if p.inputs['Normal'].is_linked:
  normal=bpy.data.images.new(label+'_normal',width=size,height=size,alpha=False)
  normal.colorspace_settings.name='Non-Color';target.image=normal;n.active=target
  bpy.ops.object.bake(type='NORMAL',use_clear=True,margin=8)
  save_image(normal,label+'_normal')
 # Stable glTF-supported PBR material. Source lighting is intentionally excluded.
 result=bpy.data.materials.new(label);result.use_nodes=True
 rn,rl=result.node_tree.nodes,result.node_tree.links;rp=principled(result)
 tex=rn.new('ShaderNodeTexImage');tex.image=albedo;rl.new(tex.outputs['Color'],rp.inputs['Base Color'])
 rp.inputs['Roughness'].default_value=p.inputs['Roughness'].default_value
 rp.inputs['Metallic'].default_value=p.inputs['Metallic'].default_value
 if normal:
  tx=rn.new('ShaderNodeTexImage');tx.image=normal;nm=rn.new('ShaderNodeNormalMap')
  rl.new(tx.outputs['Color'],nm.inputs['Color']);rl.new(nm.outputs[0],rp.inputs['Normal'])
 result.use_backface_culling=False
 ob.data.materials.clear();ob.data.materials.append(result)
 print('BAKED',label,flush=True)
 return result

# Isolated swatch scene; no stage, indirect lighting, or world in any bake.
bake_scene=bpy.data.scenes.new('EXPORT_BAKE');bpy.context.window.scene=bake_scene
bake_scene.render.engine='CYCLES';bake_scene.cycles.samples=1
bake_scene.render.bake.use_selected_to_active=False
pref=bpy.context.preferences.addons['cycles'].preferences
try:
 pref.compute_device_type='OPTIX';pref.refresh_devices()
 for device in pref.devices:device.use=device.type=='OPTIX'
 bake_scene.cycles.device='GPU'
except Exception:pass
bpy.ops.mesh.primitive_plane_add();plane=bpy.context.object
materials={m for s in scenes for c in s.collection.children if c.name.endswith('__complete_prefab') for o in c.objects if o.type=='MESH' for m in o.data.materials if m}
shared={}
spatial_names=('Weathered limestone','Sculpted mossy','Old olive glazed')
for i,mat in enumerate(sorted(materials,key=lambda m:m.name)):
 if mat.name.startswith(spatial_names):continue
 p=principled(mat)
 if not p.inputs['Base Color'].is_linked and not p.inputs['Normal'].is_linked:
  shared[mat.name]=mat;continue
 shared[mat.name]=bake_material(plane,mat,'shared_%02d'%i,512 if mat.name.startswith('Botanical') else 2048)
bpy.data.objects.remove(plane,do_unlink=True)
report={'source':str(SOURCE),'source_sha256':source_hash,'compositions':[]}
ids=['long_wall','treasure_wall','column_crates','rock_corner']
for scene,cid in zip(scenes,ids):
 bpy.context.window.scene=scene;bpy.context.view_layer.update()
 col=next(c for c in scene.collection.children if c.name.endswith('__complete_prefab'))
 objects=[o for o in col.objects if o.type in {'MESH','CURVE'}]
 members=[];static=[];interactive=[]
 for ob in objects:
  world=ob.matrix_world.copy();old_name=ob.name
  select([ob]);bpy.ops.object.convert(target='MESH');ob=bpy.context.object
  ob.parent=None;ob.matrix_world=world;ob.data=ob.data.copy()
  # Source texture/leaf UV must keep driving the source shader during atlas baking.
  if ob.data.uv_layers:ob.data.uv_layers.active.name='UVMap'
  original_mats=list(ob.data.materials)
  spatial=any(m.name.startswith(spatial_names) for m in original_mats if m)
  if spatial:
   assert len(original_mats)==1,old_name
   scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device=bake_scene.cycles.device
   bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
   bpy.ops.uv.smart_project(island_margin=0.025);bpy.ops.object.mode_set(mode='OBJECT')
   bake_material(ob,original_mats[0],cid+'_'+old_name,1024 if 'boulder' in old_name else 512,True)
  else:
   for index,m in enumerate(original_mats):
    if m:ob.data.materials[index]=shared[m.name]
  # Smart Project may create a localized UV layer name in this Blender install.
  # Join matches layers by NAME; all surfaces must address one shared channel.
  if ob.data.uv_layers:
   active=ob.data.uv_layers.active
   for layer in list(ob.data.uv_layers):
    if layer!=active:ob.data.uv_layers.remove(layer)
   active.name='UVMap';active.active_render=True
  # Store exact world bounds after the scene depsgraph is evaluated.
  points=[ob.matrix_world@Vector(corner) for corner in ob.bound_box]
  lo=Vector([min(v[i] for v in points) for i in range(3)])
  hi=Vector([max(v[i] for v in points) for i in range(3)])
  is_interactive=bool(ob.get('interaction_part',False))
  physical=is_interactive or bool(ob.get('source_object')) and ob.get('source_object')!='35ad7ced-c425-407b-be98-e37dc3bd5d60' or old_name.startswith('Column_plinth_lower') or old_name=='Mossy_boulder' or old_name=='Ancient_garden_urn'
  if physical:
   # Bake rotation into individual mesh. AABB proxies/visuals share the same origin.
   origin=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
   pid='chest1' if old_name=='Treasure_chest' else cid+'_'+old_name.lower()
   members.append({'id':old_name.lower(),'prop_id':pid,'position':[origin.x,origin.z,-origin.y],'bounds':[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y],'interactive':is_interactive,'source':ob.get('source_object','')})
   if is_interactive:
    ob.data.transform(Matrix.Translation(-origin)@ob.matrix_world);ob.matrix_world=Matrix.Identity(4)
    select([ob]);bpy.ops.export_scene.gltf(filepath=str(OUT/(pid+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
    interactive.append(ob);continue
  static.append(ob)
 # Consolidate draw submission without merging any breakable/searchable mesh.
 select(static);bpy.ops.object.join();merged=bpy.context.object;merged.name=cid+'_approved_static'
 select([merged]);bpy.ops.export_scene.gltf(filepath=str(OUT/(cid+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
 merged.data.calc_loop_triangles()
 report['compositions'].append({'id':cid,'members':members,'static_triangles':len(merged.data.loop_triangles)})
 print('EXPORTED_COMPOSITION',cid,flush=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(BASE/'reports/runtime_export.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('RUNTIME_EXPORT_COMPLETE',flush=True)
