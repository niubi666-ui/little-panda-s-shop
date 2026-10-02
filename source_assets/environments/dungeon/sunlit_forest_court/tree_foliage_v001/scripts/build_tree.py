import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector, Euler
R=Path(__file__).resolve().parents[1]
random.seed(728)
bpy.ops.wm.open_mainfile(filepath=str(R/'original/tree_import_snapshot.blend'))
s=bpy.context.scene
tree=next(o for o in s.objects if o.type=='MESH')
tree.name='SacredOak_Trunk_OriginalMesh'
for o in list(s.objects):
    if o!=tree: bpy.data.objects.remove(o,do_unlink=True)
# Keep original mesh untouched, normalize only the presentation instance to ten meters.
scale=10/tree.dimensions.z
tree.scale*=scale
bpy.context.view_layer.update()
for im in bpy.data.images:
    if im.packed_file:
        path=R/'textures'/('trunk_basecolor'+Path(im.filepath).suffix.lower())
        path.write_bytes(im.packed_file.data)
        im.unpack(method='REMOVE'); im.filepath=str(path); im.reload(); im.pack()
for m in tree.data.materials:
    if m and m.use_nodes:
        bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bs: bs.inputs['Roughness'].default_value=.83
canopy=bpy.data.collections.new('TREE_CROWN_linked_modules');s.collection.children.link(canopy)
kit=bpy.data.collections.new('LIBRARY_four_leaf_modules_hidden');s.collection.children.link(kit);kit.hide_render=True;kit.hide_viewport=True
mat=bpy.data.materials.new('OakLeaves_Atlas_Cutout');mat.use_nodes=True
n=mat.node_tree.nodes; n.clear(); l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');trans=n.new('ShaderNodeBsdfTransparent');bs=n.new('ShaderNodeBsdfPrincipled');tex=n.new('ShaderNodeTexImage')
tex.image=bpy.data.images.load(str(R/'textures/oak_branch_atlas_rgba.png'));tex.image.pack()
bs.inputs['Roughness'].default_value=.78
bs.inputs['Subsurface Weight'].default_value=.04
l.new(tex.outputs['Color'],bs.inputs['Base Color']);l.new(tex.outputs['Alpha'],mix.inputs[0]);l.new(trans.outputs[0],mix.inputs[1]);l.new(bs.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
mat.diffuse_color=(.22,.34,.07,1)
def module(k):
    verts=[]; faces=[]; uv=[]
    # Five curved sprays per reusable crown module. Each spray is six quads.
    for c in range(5):
        rot=Euler((random.uniform(-.55,.55),random.uniform(-.5,.5),c*math.tau/5+k*.25)).to_matrix()
        base=len(verts)
        for j in range(4):
            t=j/3
            for i in range(3):
                x=(i/2-.5)*.86
                p=rot@Vector((x,t*1.5,.15*math.sin(t*math.pi)-.22*abs(x)))
                verts.append(p)
                # Pillow top is the tip, UV bottom is the attachment.
                col=k%2; row=1-k//2
                uv.append(((col+i/2)/2,(row+t)/2))
        for j in range(3):
            for i in range(2):
                a=base+j*3+i;faces.append((a,a+1,a+4,a+3))
    me=bpy.data.meshes.new('LeafModule_%02d_mesh'%k);me.from_pydata(verts,[],faces);me.materials.append(mat)
    u=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        p.use_smooth=True
        for idx in p.loop_indices:u.data[idx].uv=uv[me.loops[idx].vertex_index]
    ob=bpy.data.objects.new('Library_LeafSpray_%02d'%k,me);kit.objects.link(ob)
    return me
meshes=[module(k) for k in range(4)]
# Select spatially separated real branch surface points, avoiding unsupported floating clumps.
points=[tree.matrix_world@v.co for v in tree.data.vertices]
candidates=[p for p in points if p.z>4.5 and (math.hypot(p.x,p.y)>1.45 or p.z>7.6)]
random.shuffle(candidates); anchors=[]
for p in candidates:
    if all((p-q).length>.44 for q in anchors): anchors.append(p)
for i,p in enumerate(anchors):
    ob=bpy.data.objects.new('CrownSpray_%03d'%i,meshes[i%4]);canopy.objects.link(ob)
    ob.location=p
    ob.rotation_euler=(random.uniform(-1.0,1.0),random.uniform(-.85,.85),math.atan2(p.y,p.x)-math.pi/2+random.uniform(-.8,.8))
    a=random.uniform(.95,1.4);ob.scale=(a,a,a)
    ob['module_variant']=i%4
# Neutral review floor and warm/cool lighting; kept separate from tree collections.
stage=bpy.data.collections.new('REVIEW_STAGE_not_game_asset');s.collection.children.link(stage)
def stage_obj(ob):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    stage.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='ReviewGround';stage_obj(floor)
fm=bpy.data.materials.new('ReviewGround_M');fm.use_nodes=True
fb=next(n for n in fm.node_tree.nodes if n.type=='BSDF_PRINCIPLED');fb.inputs['Base Color'].default_value=(.13,.16,.12,1);fb.inputs['Roughness'].default_value=.9;floor.data.materials.append(fm)
world=bpy.data.worlds.new('ReviewWorld');world.use_nodes=True;s.world=world
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.50,.63,.79,1);bg.inputs[1].default_value=.35
def aim(ob,p):ob.rotation_euler=(Vector(p)-ob.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=loc;aim(ob,(0,0,5))
area('Warm_Key',(-7,-8,16),2300,(1,.83,.59),8)
area('Cool_Fill',(5,-3,9),1100,(.7,.83,1),9)
area('Canopy_Rim',(3,7,15),2800,(1,.93,.7),7)
cam=bpy.data.objects.new('Review_Camera',bpy.data.cameras.new('Review_Camera'));stage.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=16;cam.location=(22,-14,13);aim(cam,(0,0,5.4));s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True;s.cycles.transparent_max_bounces=16
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for d in prefs.devices:d.use=d.type=='OPTIX'
    s.cycles.device='GPU'
except Exception as e: print('GPU fallback',e)
s.render.resolution_x=1400;s.render.resolution_y=1400;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'
for a in bpy.context.screen.areas if bpy.context.screen else []:
    if a.type=='VIEW_3D': a.spaces.active.region_3d.view_perspective='CAMERA'
tree.data.calc_loop_triangles()
report={'source_sha256':hashlib.sha256((R/'original/tree_import_snapshot.blend').read_bytes()).hexdigest(),'trunk_triangles':len(tree.data.loop_triangles),'trunk_height_m':tree.dimensions.z,'leaf_modules_unique':4,'leaf_module_instances':len(anchors),'triangles_per_module':60,'foliage_triangles':len(anchors)*60,'texture_size':2048,'note':'Blender prototype. No Godot import or runtime performance validation. No high-to-low trunk bake performed.'}
(R/'reports/build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/sacred_oak_foliage_v001.blend'))
s.render.filepath=str(R/'previews/tree_hero.png');bpy.ops.render.render(write_still=True)
cam.location=(14,-18,21);aim(cam,(0,0,5));cam.data.ortho_scale=18
s.render.filepath=str(R/'previews/tree_gameplay_angle.png');bpy.ops.render.render(write_still=True)
print('DONE',report)
