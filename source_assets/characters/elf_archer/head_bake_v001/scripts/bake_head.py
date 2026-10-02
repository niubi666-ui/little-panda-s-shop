import bpy,bmesh,json,hashlib,array,time,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
bpy.ops.wm.open_mainfile(filepath=str(B/'original/head_body_session_source.blend'),load_ui=False,use_scripts=False)
main=bpy.context.scene
hi=bpy.data.objects['elf character 3d model'];lo=bpy.data.objects['elf character 3d model_Clone1']
def signature(o):
    a=array.array('f',[0])*len(o.data.vertices)*3;o.data.vertices.foreach_get('co',a)
    return [hashlib.sha256(a.tobytes()).hexdigest(),len(o.data.polygons),[list(r) for r in o.matrix_world],[m.name if m else None for m in o.data.materials]]
original={o.name:signature(o) for o in main.objects if o.type=='MESH'}
scene=bpy.data.scenes.new('Head_Bake_Work');bpy.context.window.scene=scene
high=hi.copy();high.name='Head_High_Bake_Source';scene.collection.objects.link(high);high.matrix_world=Matrix.Identity(4)
low=lo.copy();low.data=lo.data.copy();low.name='04_Head_Low_Baked';scene.collection.objects.link(low);low.matrix_world=Matrix.Identity(4)
shift=Vector((0,0,.00032782554626464844));low.data.transform(Matrix.Translation(shift));low.data.update()
# Close the source retopology's isolated missing-face loops on the new head only.
bm=bmesh.new();bm.from_mesh(low.data)
old_uv=bm.loops.layers.uv.active;new_uv=bm.loops.layers.uv.new('Head_BakeUV')
for f in bm.faces:
    for loop in f.loops:loop[new_uv].uv=(loop[old_uv].uv.x*.84,loop[old_uv].uv.y)
seen=set();loops=[]
for edge in bm.edges:
    if not edge.is_boundary or edge in seen:continue
    todo=[edge];seen.add(edge);group=[]
    while todo:
        e=todo.pop();group.append(e)
        for v in e.verts:
            for n in v.link_edges:
                if n.is_boundary and n not in seen:seen.add(n);todo.append(n)
    verts=set(v for e in group for v in e.verts)
    if all(sum(e.is_boundary for e in v.link_edges)==2 for v in verts):loops.append(group)
patches=[]
for edges in loops:
    patches.extend(bmesh.ops.holes_fill(bm,edges=edges,sides=80).get('faces',[]))
cols=8;rows=math.ceil(len(patches)/cols);cw=.16/cols;ch=1/rows
for i,f in enumerate(patches):
    f.normal_update();n=f.normal.normalized();axis=Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,1,0));u=n.cross(axis).normalized();v=n.cross(u).normalized()
    p=[(l.vert.co.dot(u),l.vert.co.dot(v)) for l in f.loops];mn=[min(x[j] for x in p) for j in range(2)];mx=[max(x[j] for x in p) for j in range(2)]
    for l,xy in zip(f.loops,p):l[new_uv].uv=(.84+(i%cols+.1+.8*(xy[0]-mn[0])/max(mx[0]-mn[0],1e-7))*cw, (i//cols+.1+.8*(xy[1]-mn[1])/max(mx[1]-mn[1],1e-7))*ch)
patch_count=len(patches)
bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(low.data);bm.free();low.data.update()
low.data.uv_layers.active=low.data.uv_layers['Head_BakeUV'];low.data.uv_layers['Head_BakeUV'].active_render=True
low.data.normals_split_custom_set([(0,0,0)]*len(low.data.loops))
for f in low.data.polygons:f.use_smooth=True
low.data.update()
mat=lo.data.materials[0].copy();mat.name='Elf_Head_Baked_4K';low.data.materials.clear();low.data.materials.append(mat)
bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for link in list(bs.inputs['Normal'].links):mat.node_tree.links.remove(link)
scene.render.engine='CYCLES';scene.cycles.samples=32
prefs=bpy.context.preferences.addons['cycles'].preferences
try:
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    for d in prefs.devices:d.use=d.type=='OPTIX'
    scene.cycles.device='GPU'
except Exception as e:print('GPU fallback',e,flush=True);scene.cycles.device='CPU'
bake=scene.render.bake;bake.use_selected_to_active=True;bake.use_cage=False;bake.cage_extrusion=.012;bake.max_ray_distance=.04;bake.margin=24;bake.use_clear=True
bake.normal_space='TANGENT';bake.normal_r='POS_X';bake.normal_g='POS_Y';bake.normal_b='POS_Z'
bake.use_pass_direct=False;bake.use_pass_indirect=False;bake.use_pass_color=True
bpy.ops.object.select_all(action='DESELECT');high.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
images={};nodes={};timings={}
for kind in ['NORMAL','DIFFUSE']:
    name='elf_head_normal_opengl_4k' if kind=='NORMAL' else 'elf_head_basecolor_4k'
    im=bpy.data.images.new(name,width=4096,height=4096,alpha=False,float_buffer=kind=='NORMAL')
    im.colorspace_settings.name='Non-Color' if kind=='NORMAL' else 'sRGB'
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.label=name
    for n in mat.node_tree.nodes:n.select=False
    node.select=True;mat.node_tree.nodes.active=node
    print('BAKE_START',kind,flush=True);t=time.time();bpy.ops.object.bake(type=kind);timings[kind]=time.time()-t;print('BAKE_DONE',kind,timings[kind],flush=True)
    # Save normal values as data, without display transform.
    im.filepath_raw=str(B/'textures'/(name+'.png'));im.file_format='PNG';im.save();im.pack();images[kind]=im;nodes[kind]=node
nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.uv_map=low.data.uv_layers.active.name;nm.inputs['Strength'].default_value=1
mat.node_tree.links.new(nodes['NORMAL'].outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
mat.node_tree.links.new(nodes['DIFFUSE'].outputs['Color'],bs.inputs['Base Color'])
nodes['DIFFUSE'].location=(-580,180);nodes['NORMAL'].location=(-580,-140);nm.location=(-270,-120);bs.location=(0,120)
low.data.transform(Matrix.Translation(-shift));low.matrix_world=lo.matrix_world.copy();low.location.y+=1.33
main.collection.objects.link(low);scene.collection.objects.unlink(low);bpy.context.window.scene=main
bpy.data.objects.remove(high,do_unlink=True);bpy.data.scenes.remove(scene)
assert original=={o.name:signature(o) for o in main.objects if o.name in original}
bpy.ops.file.pack_all();out=B/'blender/elf_head_bake_comparison_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out))
report={'high_triangles':len(hi.data.polygons),'low_triangles':len(low.data.polygons),'original_low_triangles':24474,'reduction_percent':100*(1-len(low.data.polygons)/len(hi.data.polygons)),'bake_uv':low.data.uv_layers.active.name,'original_uv_retained':True,'normal':'Tangent +X +Y +Z (OpenGL), Non-Color, Strength 1','resolution':4096,'filled_boundary_loops':patch_count,'ray_extrusion':.012,'ray_max_distance':.04,'alignment_shift':list(shift),'bake_seconds':timings,'original_objects_unchanged':True,'original_signatures':original,'output':str(out)}
(B/'reports/bake_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('BAKE_SAVED',str(out),flush=True)
