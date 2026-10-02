"""Background-only export of the saved art scene; source .blend is never saved.
Bake procedural base colors, retain original image textures and shared meshes.
Lighting is reconstructed from metadata in the Godot room presentation.
"""
import bpy, json, math, re, hashlib, argparse, sys, importlib.util
from pathlib import Path
ROOT=Path('E:/ShopGame'); BASE=ROOT/'source_assets/environments/dungeon/forest_courtyard/v001'
parser=argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path, default=ROOT/'game/assets/environments/forest_courtyard_v001')
parser.add_argument('--report', type=Path, default=BASE/'reports/godot_export.json')
parser.add_argument('--foliage-config', type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.output_dir; OUT.mkdir(parents=True,exist_ok=True)
assert bpy.app.background
scene=bpy.context.scene
source_hash=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
def slug(s): return re.sub('[^a-zA-Z0-9_]+','_',s)
def principal(m): return next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
meta={'source_sha256':source_hash,'lights':[],'camera':{},'objects':[],'bakes':[]}
for o in scene.objects:
 if o.type=='LIGHT': meta['lights'].append({'name':o.name,'type':o.data.type,'energy':o.data.energy,'color':list(o.data.color),'matrix':[list(r) for r in o.matrix_world]})
cam=scene.camera
meta['camera']={'matrix':[list(r) for r in cam.matrix_world],'lens':cam.data.lens,'sensor_width':cam.data.sensor_width}
# Bake only surface colour (not illumination) on an isolated material swatch scene.
materials=[m for m in bpy.data.materials if m.users and m.use_nodes and principal(m)]
bake_scene=bpy.data.scenes.new('ExportColorSwatches'); bpy.context.window.scene=bake_scene
bake_scene.render.engine='CYCLES'; bake_scene.cycles.samples=1; bake_scene.cycles.device='CPU';bake_scene.render.bake.margin=8
bpy.ops.mesh.primitive_plane_add(size=2); plane=bpy.context.object
for original in materials:
 p=principal(original)
 # Original model images export directly. World-space wet masking is recreated in Godot.
 if original.name.startswith('Item2_'):
  if 'paving_dry' in original.name:
   color=p.inputs['Base Color'].links[0].from_node
   original.node_tree.links.new(color.inputs[1].links[0].from_socket,p.inputs['Base Color'])
   for link in list(p.inputs['Roughness'].links): original.node_tree.links.remove(link)
   p.inputs['Roughness'].default_value=.72
   for link in list(p.inputs['Coat Weight'].links): original.node_tree.links.remove(link)
   p.inputs['Coat Weight'].default_value=0
  continue
 if not p.inputs['Base Color'].is_linked: continue
 mat=original.copy(); plane.data.materials.clear();plane.data.materials.append(mat)
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;mp=principal(mat)
 output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');emit=nodes.new('ShaderNodeEmission')
 links.new(mp.inputs['Base Color'].links[0].from_socket,emit.inputs[0]);links.new(emit.outputs[0],output.inputs['Surface'])
 im=bpy.data.images.new('Baked_'+slug(original.name),width=512,height=512,alpha=False)
 target=nodes.new('ShaderNodeTexImage');target.image=im;nodes.active=target
 bpy.ops.object.bake(type='EMIT')
 im.filepath_raw=str(OUT/(slug(original.name)+'_color.png')); im.file_format='PNG';im.save()
 tex=original.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
 original.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 meta['bakes'].append(original.name); print('COLOR_BAKED',original.name,flush=True)
 bpy.data.materials.remove(mat)
bpy.context.window.scene=scene
bpy.data.scenes.remove(bake_scene)
for mat in materials:
 p=principal(mat); nodes=mat.node_tree.nodes;links=mat.node_tree.links
 output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');links.new(p.outputs[0],output.inputs['Surface'])
 normal=next((n for n in nodes if n.type=='NORMAL_MAP'),None)
 if normal: links.new(normal.outputs[0],p.inputs['Normal'])
 else:
  for link in list(p.inputs['Normal'].links): links.remove(link)
 # Roughness scanner chains are not supported by glTF; preserve the authored scalar.
 if p.inputs['Roughness'].is_linked:
  for link in list(p.inputs['Roughness'].links): links.remove(link)
 # Emission mask on lantern supplied as runtime light, do not turn whole lantern white.
 if p.inputs['Emission Strength'].is_linked:
  for link in list(p.inputs['Emission Strength'].links): links.remove(link)
  p.inputs['Emission Strength'].default_value=0
# Volume and Fresnel-only materials require explicit Godot counterparts.
water=bpy.data.materials.get('Rainwater_thin_Fresnel_film')
if water:
 water.node_tree.nodes.clear();out=water.node_tree.nodes.new('ShaderNodeOutputMaterial');p=water.node_tree.nodes.new('ShaderNodeBsdfPrincipled');water.node_tree.links.new(p.outputs[0],out.inputs['Surface']);p.inputs['Base Color'].default_value=(.08,.14,.12,1);p.inputs['Roughness'].default_value=.08;p.inputs['Metallic'].default_value=.7
if args.foliage_config:
 spec=importlib.util.spec_from_file_location('optimize_foliage', BASE/'scripts/optimize_foliage.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 meta['foliage_optimization']=module.optimize(scene, json.loads(args.foliage_config.read_text(encoding='utf-8')), OUT)
bpy.ops.object.select_all(action='DESELECT')
exports=[]; evaluated={}; dg=bpy.context.evaluated_depsgraph_get()
for o in list(scene.objects):
 if o.type not in {'MESH','CURVE'} or o.hide_render or any(c.name=='Atmosphere' for c in o.users_collection):continue
 name=o.name;matrix=o.matrix_world.copy()
 if o.type=='CURVE' or len(o.modifiers):
  mesh=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
  replacement=bpy.data.objects.new('Export_'+name,mesh);scene.collection.objects.link(replacement);replacement.matrix_world=matrix
  o.hide_render=True;o.hide_set(True);o=replacement
 o.name=slug(name);o['source_name']=name
 o.select_set(True);exports.append(o)
 if not o.data.uv_layers:
  uv=o.data.uv_layers.new(name='SurfaceUV')
  for loop in o.data.loops:
   co=o.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(co.x,co.y)
 meta['objects'].append({'name':o.name,'source_name':name,'matrix':[list(r) for r in matrix],'groups':[c.name for c in o.users_collection]})
bpy.context.view_layer.objects.active=exports[0]
print('EXPORT_START',len(exports),flush=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'forest_courtyard.glb'),use_selection=True,export_extras=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=False)
meta['export_meshes']=len(exports)
if args.foliage_config:
 module.finalize_glb(OUT/'forest_courtyard.glb')
args.report.parent.mkdir(parents=True,exist_ok=True)
args.report.write_text(json.dumps(meta,indent=2),encoding='utf-8')
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==source_hash
print('FOREST_EXPORT_DONE',flush=True)
