"""Run in a background Blender on the approved v006; never save the source blend.
Bake procedural surface color/normal only. Lighting remains dynamic in Godot.
"""
import bpy, math, json, re
from pathlib import Path
from mathutils import Vector
ROOT=Path('E:/ShopGame')
OUT=ROOT/'game/assets/environments/shop';OUT.mkdir(parents=True,exist_ok=True)
BUILD=ROOT/'builds/inspection';BUILD.mkdir(parents=True,exist_ok=True)
s=bpy.context.scene
dg=bpy.context.evaluated_depsgraph_get()
metadata={'source':'shop_interior_v006.blend','objects':[],'lights':[],'camera':{}}
def slug(text):return re.sub('[^a-z0-9_]+','_',text.lower()).strip('_')
for o in list(s.objects):
    if o.type=='LIGHT':
        d=o.data
        metadata['lights'].append({'name':o.name,'type':d.type,'matrix':[list(r) for r in o.matrix_world],'energy':d.energy,'color':list(d.color),'size':getattr(d,'size',0),'radius':getattr(d,'shadow_soft_size',0)})
if s.camera:metadata['camera']={'matrix':[list(r) for r in s.camera.matrix_world],'ortho_scale':s.camera.data.ortho_scale}
meshes=[]
for o in list(s.objects):
    groups=[c.name for c in o.users_collection]
    if o.type not in {'MESH','CURVE'} or 'Presentation_Only' in groups or o.hide_render:continue
    # Evaluate bevels and curves into private export meshes; retain all source object boundaries.
    me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
    replacement=bpy.data.objects.new('export_'+o.name,me);s.collection.objects.link(replacement)
    replacement.matrix_world=o.matrix_world.copy()
    source_name=o.name
    o.hide_render=True;o.hide_set(True)
    replacement.name=slug(source_name)
    replacement['source_name']=source_name
    replacement['instance_id']='shop.initial.'+slug(source_name)
    replacement['collection']=groups[0] if groups else 'Other'
    bounds=[replacement.matrix_world@Vector(v) for v in replacement.bound_box]
    metadata['objects'].append({'name':replacement.name,'source_name':source_name,'collection':replacement['collection'],'instance_id':replacement['instance_id'],'bounds':[[min(v[i] for v in bounds) for i in range(3)],[max(v[i] for v in bounds) for i in range(3)]]})
    meshes.append(replacement)
proc=[o for o in meshes if any(m and m.use_nodes and any(n.type=='TEX_NOISE' for n in m.node_tree.nodes) for m in o.data.materials)]
print('EXPORT_MESHES',len(meshes),'PROCEDURAL',len(proc),flush=True)
# Individual cube-projected UV islands retain each object's original Generated coordinates.
grid=math.ceil(math.sqrt(len(proc)))
for i,o in enumerate(proc):
    uv=o.data.uv_layers.new(name='BakedSurface')
    verts=[v.co for v in o.data.vertices]
    lo=Vector([min(v[a] for v in verts) for a in range(3)])
    span=Vector([max(v[a] for v in verts)-lo[a] for a in range(3)])
    for p in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]));side=axis*2+(p.normal[axis]<0)
        ax=[a for a in range(3) if a!=axis]
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            a=(v[ax[0]]-lo[ax[0]])/max(span[ax[0]],1e-8)
            b=(v[ax[1]]-lo[ax[1]])/max(span[ax[1]],1e-8)
            u=(side%3+.05+.9*a)/3;w=(side//3+.05+.9*b)/2
            uv.data[li].uv=((i%grid+.01+.98*u)/grid,(i//grid+.01+.98*w)/grid)
    o.data.uv_layers.active=uv
    uv.active_render=True
    attr=o.data.attributes.new('original_generated','FLOAT_VECTOR','CORNER')
    for li,loop in enumerate(o.data.loops):
        v=o.data.vertices[loop.vertex_index].co
        attr.data[li].vector=tuple((v[a]-lo[a])/max(span[a],1e-8) for a in range(3))
materials=set(m for o in proc for m in o.data.materials if m)
base=bpy.data.images.new('shop_surface_color',width=4096,height=4096,alpha=False)
normal=bpy.data.images.new('shop_surface_normal',width=4096,height=4096,alpha=False)
normal.colorspace_settings.name='Non-Color'
for m in materials:
    # Preserve per-object Generated coordinates when temporarily joining the bake mesh.
    attr_node=m.node_tree.nodes.new('ShaderNodeAttribute');attr_node.attribute_name='original_generated'
    for tc in [n for n in m.node_tree.nodes if n.type=='TEX_COORD']:
        for link in list(tc.outputs['Generated'].links):
            dest=link.to_socket;m.node_tree.links.remove(link)
            m.node_tree.links.new(attr_node.outputs['Vector'],dest)
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.name='EXPORT_BAKE';n.image=base;m.node_tree.nodes.active=n
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for o in proc:
    dup=o.copy();dup.data=o.data.copy();s.collection.objects.link(dup);dup.select_set(True);copies.append(dup)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
bake_object=bpy.context.object
bake_object.name='TemporaryBakeAtlas'
try:s.render.engine='CYCLES'
except TypeError as e:raise RuntimeError(str(e))
s.cycles.samples=8
s.cycles.device='CPU'
try:
    pref=bpy.context.preferences.addons['cycles'].preferences
    pref.compute_device_type='OPTIX';pref.refresh_devices()
    if any(d.type=='OPTIX' for d in pref.devices):
        for d in pref.devices:d.use=d.type=='OPTIX'
        s.cycles.device='GPU'
except Exception as e:print('CPU_FALLBACK',e)
s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True
s.render.bake.margin=2
print('BAKE_COLOR',flush=True)
bpy.ops.object.bake(type='DIFFUSE')
base.filepath_raw=str(OUT/'shop_surface_color.png');base.file_format='PNG';base.save()
for m in materials:m.node_tree.nodes.get('EXPORT_BAKE').image=normal
print('BAKE_NORMAL',flush=True)
bpy.ops.object.bake(type='NORMAL')
normal.filepath_raw=str(OUT/'shop_surface_normal.png');normal.file_format='PNG';normal.save()
bpy.data.objects.remove(bake_object,do_unlink=True)
for m in materials:
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for socket in ('Base Color','Normal'):
        for link in list(p.inputs[socket].links):m.node_tree.links.remove(link)
    tex=m.node_tree.nodes.get('EXPORT_BAKE');tex.image=base
    uvn=m.node_tree.nodes.new('ShaderNodeUVMap');uvn.uv_map='BakedSurface'
    m.node_tree.links.new(uvn.outputs['UV'],tex.inputs['Vector'])
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    nt=m.node_tree.nodes.new('ShaderNodeTexImage');nt.image=normal
    m.node_tree.links.new(uvn.outputs['UV'],nt.inputs['Vector'])
    nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.uv_map='BakedSurface'
    m.node_tree.links.new(nt.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],p.inputs['Normal'])
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
props=bpy.ops.export_scene.gltf.get_rna_type().properties
kwargs={'filepath':str(OUT/'shop_interior_v006.glb'),'use_selection':True,'export_extras':True,'export_animations':False,'export_cameras':False,'export_lights':False}
# The dynamic exporter enum is not enumerated by RNA in this Blender build.
# Its registered default is the binary format; use the operator default.
print('EXPORT_FORMAT_DEFAULT',props['export_format'].default,flush=True)
print('GLB_EXPORT',flush=True)
bpy.ops.export_scene.gltf(**kwargs)
(BUILD/'shop_export.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print('SHOP_EXPORT_DONE',flush=True)
