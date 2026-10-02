import bpy, math, random, json
from pathlib import Path
from mathutils import Vector, Euler
R=Path(__file__).resolve().parents[1]
random.seed(912)
src=R.parent/'tree_foliage_v001/original/tree_import_snapshot.blend'
bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
tree=next(o for o in s.objects if o.type=='MESH');tree.name='SacredOak_Trunk_Preserved'
for o in list(s.objects):
    if o!=tree:bpy.data.objects.remove(o,do_unlink=True)
tree.scale*=10/tree.dimensions.z;bpy.context.view_layer.update()
for im in bpy.data.images:
    if im.packed_file:
        path=R/'textures'/('trunk_basecolor'+Path(im.filepath).suffix.lower());path.write_bytes(im.packed_file.data)
        im.unpack(method='REMOVE');im.filepath=str(path);im.reload();im.pack()
for m in tree.data.materials:
    if m and m.use_nodes:
        bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bs:bs.inputs['Roughness'].default_value=.83
canopy=bpy.data.collections.new('CROWN_compact_oak_clusters');s.collection.children.link(canopy)
kit=bpy.data.collections.new('LIBRARY_six_modules_hidden');s.collection.children.link(kit);kit.hide_render=True;kit.hide_viewport=True
mat=bpy.data.materials.new('Oak_ShortRoundedLeaves_RGBA');mat.use_nodes=True
n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');trans=n.new('ShaderNodeBsdfTransparent');bs=n.new('ShaderNodeBsdfPrincipled');tex=n.new('ShaderNodeTexImage')
tex.image=bpy.data.images.load(str(R/'textures/oak_compact_sprays_rgba.png'));tex.image.pack()
bs.inputs['Roughness'].default_value=.87
bs.inputs['Specular IOR Level'].default_value=.14
bs.inputs['Subsurface Weight'].default_value=.025
cut=n.new('ShaderNodeMath');cut.operation='GREATER_THAN';cut.inputs[1].default_value=.45
l.new(tex.outputs['Color'],bs.inputs['Base Color']);l.new(tex.outputs['Alpha'],cut.inputs[0]);l.new(cut.outputs[0],mix.inputs[0]);l.new(trans.outputs[0],mix.inputs[1])
thin=n.new('ShaderNodeBsdfTranslucent');leafmix=n.new('ShaderNodeMixShader');leafmix.inputs[0].default_value=.32
l.new(tex.outputs['Color'],thin.inputs['Color']);l.new(bs.outputs[0],leafmix.inputs[1]);l.new(thin.outputs[0],leafmix.inputs[2]);l.new(leafmix.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
mat.diffuse_color=(.23,.3,.08,1)
def module(k):
    verts=[];faces=[];uv=[]
    # Compact short sprays arranged in a rounded volume, never a radial fern rosette.
    for c in range(30):
        angle=random.uniform(0,math.tau)
        rad=random.uniform(.12,.76)
        center=Vector((math.cos(angle)*rad,math.sin(angle)*rad,random.uniform(-.40,.50)))
        rot=Euler((random.uniform(-1.15,1.15),random.uniform(-.8,.8),random.uniform(0,math.tau))).to_matrix()
        size=random.uniform(.42,.70);base=len(verts);variant=(k+c)%4
        for j in range(3):
            t=j/2
            for i in range(3):
                x=i/2-.5
                p=rot@Vector((x*size,(t-.35)*size,.12*math.sin(t*math.pi)-.12*abs(x)))+center
                verts.append(p);col=variant%2;row=1-variant//2
                uv.append(((col+.025+(i/2)*.95)/2,(row+.025+t*.95)/2))
        for j in range(2):
            for i in range(2):
                a=base+j*3+i;faces.append((a,a+1,a+4,a+3))
    me=bpy.data.meshes.new('CompactOakCluster_%02d'%k);me.from_pydata(verts,[],faces);me.materials.append(mat)
    layer=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        p.use_smooth=True
        for idx in p.loop_indices:layer.data[idx].uv=uv[me.loops[idx].vertex_index]
    me.normals_split_custom_set_from_vertices([(Vector(v)+Vector((0,0,.55))).normalized() for v in verts])
    ob=bpy.data.objects.new('Module_%02d'%k,me);kit.objects.link(ob);return me
meshes=[module(i) for i in range(6)]
points=[tree.matrix_world@v.co for v in tree.data.vertices]
# Outer branch envelope in height bands, avoiding the exposed main trunk and inner crotches.
env={}
for p in points:
    z=int(p.z/.75);env[z]=max(env.get(z,0),math.hypot(p.x,p.y))
candidates=[]
for p in points:
    r=math.hypot(p.x,p.y);edge=env[int(p.z/.75)]
    if p.z>3.8 and (r>max(1.9,edge*.70) or p.z>8.75):candidates.append(p)
random.shuffle(candidates);anchors=[]
for p in candidates:
    if all((p-q).length>.66 for q in anchors):anchors.append(p.copy())
for i,p in enumerate(anchors):
    ob=bpy.data.objects.new('CrownCluster_%03d'%i,meshes[i%6]);canopy.objects.link(ob)
    r=Vector((p.x,p.y,0));r.normalize();ob.location=p+r*.20+Vector((0,0,.30 if p.z>8.7 else .12))
    ob.rotation_euler=(random.uniform(-.45,.45),random.uniform(-.4,.4),random.uniform(0,math.tau))
    a=random.uniform(.84,1.23);ob.scale=(a,a,random.uniform(.8,1.12)*a)
stage=bpy.data.collections.new('REVIEW_stage_not_export');s.collection.children.link(stage)
def stage_obj(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    stage.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Review_Floor';stage_obj(floor)
fm=bpy.data.materials.new('WarmGrey_Studio');fm.use_nodes=True
fb=next(n for n in fm.node_tree.nodes if n.type=='BSDF_PRINCIPLED');fb.inputs['Base Color'].default_value=(.40,.37,.32,1);fb.inputs['Roughness'].default_value=.85;floor.data.materials.append(fm)
world=bpy.data.worlds.new('NeutralStudio');world.use_nodes=True;s.world=world
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.76,.79,.83,1);bg.inputs[1].default_value=.8
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.size=size
    o=bpy.data.objects.new(name,d);stage.objects.link(o);o.location=loc;aim(o,(0,0,5))
area('Key',(8,-8,17),2100,(1,.92,.79),9)
area('Fill',(5,9,9),950,(.86,.91,1),10)
area('Rim',(-5,2,15),1700,(1,.96,.82),8)
cam=bpy.data.objects.new('Review_Camera',bpy.data.cameras.new('Review_Camera'));stage.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=13.5;cam.location=(26,-3,9);aim(cam,(0,0,5.3));s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True;s.cycles.transparent_max_bounces=24
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for d in prefs.devices:d.use=d.type=='OPTIX'
    s.cycles.device='GPU'
except Exception as e:print(e)
s.render.resolution_x=1400;s.render.resolution_y=1500;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
report={'trunk_triangles':sum(len(p.vertices)-2 for p in tree.data.polygons),'foliage_triangles':len(anchors)*240,'module_count':6,'cluster_instances':len(anchors),'triangles_per_module':240,'alpha_image_size':list(tex.image.size),'leaf_spray_size_m':[.42,.70],'tree_trunk_height_m':10,'source':'../tree_foliage_v001/original/tree_import_snapshot.blend','status':'Blender review only; no Godot writes, no LOD/wind/runtime profiling'}
(R/'reports/build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/sacred_oak_foliage_v002.blend'))
s.render.filepath=str(R/'previews/tree_hero.png');bpy.ops.render.render(write_still=True)
cam.location=(20,-14,20);aim(cam,(0,0,5));cam.data.ortho_scale=15
s.render.filepath=str(R/'previews/tree_gameplay_angle.png');bpy.ops.render.render(write_still=True)
print('DONE',report)
