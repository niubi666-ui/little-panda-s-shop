import bpy,bmesh,math,json,shutil,hashlib
from mathutils import Vector,Matrix
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/elf_archer')
SRC=Path('E:/ShopGame/source_assets/characters/red_panda/blender/jingling.blend')
for p in ['original','blender','previews','reports']: (BASE/p).mkdir(parents=True,exist_ok=True)
backup=BASE/'original/jingling_source.blend'
if not backup.exists():shutil.copy2(SRC,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup),load_ui=False,use_scripts=False)
body=bpy.data.objects['25a7ba75-4c59-4c2e-a7d3-b97c522f7ce6'];head=bpy.data.objects['elf character 3d model_Clone1']
for o in [body,head]:
    o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
body.name='ElfArcher_Body';head.name='ElfArcher_HeadHair'
# Source +X is forward. Keep UVs and original image textures while trimming the duplicate bust.
mesh=head.data
keep=[]
for poly in mesh.polygons:
    c=sum((mesh.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
    keep.append(c.z>.28)
bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for i,f in enumerate(bm.faces) if not keep[i]],context='FACES')
# Remove only tiny detached remnants caused by texture boundaries; retain long hair connected to scalp.
bm.verts.ensure_lookup_table();seen=set();components=[]
for v in bm.verts:
    if v in seen:continue
    stack=[v];seen.add(v);component=[]
    while stack:
        p=stack.pop();component.append(p)
        for e in p.link_edges:
            n=e.other_vert(p)
            if n not in seen:seen.add(n);stack.append(n)
    components.append(component)
small=[v for comp in components if len(comp)<120 for v in comp]
if small:bmesh.ops.delete(bm,geom=small,context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
# Remove original headless neck stump where the replacement neck enters its collar.
bm=bmesh.new();bm.from_mesh(body.data)
cut=[]
for f in bm.faces:
    c=f.calc_center_median()
    if c.z>.871 and abs(c.y)<.047 and c.x>-.04:cut.append(f)
bmesh.ops.delete(bm,geom=cut,context='FACES')
bm.to_mesh(body.data);bm.free();body.data.update()
scale=.278
offset=Vector((.006,-1.25516*scale,.745))
for v in head.data.vertices:
    # Tuck the lower duplicate collar under the retained body cape.
    t=max(0,min(1,(.40-v.co.z)/.12))
    v.co.y=1.25516+(v.co.y-1.25516)*(1-.40*t)
    if v.co.x<0:v.co.x+=.095*t
    v.co=v.co*scale+offset
# Normalize to meters: preserve adult proportions and make the soles the common origin.
unit=1.70/(.97772169*scale+offset.z)
for o in [body,head]:
    o.data.transform(Matrix.Scale(unit,4))
    for p in o.data.polygons:p.use_smooth=True
root=bpy.data.objects.new('ElfArcher_Assembly',None);bpy.context.scene.collection.objects.link(root)
for o in [body,head]:o.parent=root
root['source']='jingling.blend';root['assembly_status']='Static fitted head/body; no rig or animation added'
scene=bpy.context.scene
try:scene.render.engine='BLENDER_EEVEE'
except TypeError:pass
scene.render.resolution_x=1100;scene.render.resolution_y=1300;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.12,.15,.19,1);bg.inputs[1].default_value=.45
for o in list(bpy.data.objects):
    if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
target=Vector((0,0,.86))
for name,pos,power,size in [('Key',(3,-3,4),450,4),('Fill',(-1,3,2),320,3),('Rim',(-3,-2,3),500,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=2.10
for name,pos in [('front',(4,0,1.03)),('three_quarter',(4,-2.4,1.6)),('back',(-4,0,1.05)),('side',(0,-4,1.0))]:
    camera.location=pos;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(BASE/'previews'/('assembled_'+name+'.png'));bpy.ops.render.render(write_still=True)
camera.location=(4,-2.4,1.6);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);head.select_set(True);bpy.context.view_layer.objects.active=head
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_location=target
            area.spaces.active.region_3d.view_distance=2.9
            area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/jingling_assembled_v001.blend'))
(BASE/'reports/assembly.json').write_text(json.dumps({'source':str(SRC),'backup':str(backup),'head_scale_relative_to_body':scale,'whole_scale_to_meters':unit,'head_offset_before_unit_scale':list(offset),'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'objects':{o.name:{'vertices':len(o.data.vertices),'faces':len(o.data.polygons)} for o in [body,head]}},indent=2),encoding='utf-8')
