"""Derived copies only; item2 is never saved. Column is stood upright before export."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path('E:/ShopGame'); SOURCE=ROOT/'source_assets/characters/red_panda/blender/item2.blend'
OUT=ROOT/'game/assets/environments/room_compositions_v003';OUT.mkdir(parents=True,exist_ok=True)
assets={
 'low_wall':('71d0d5a4-fa8e-4375-bb31-dc33549b281e',(1.7,.48,.8)),
 'end_pillar':('6d00c541-9c1e-42f5-bdd1-3475b0d613d0',(.6,.6,1.15)),
 'broken_column':('65fbc458-0833-44c7-b125-2885ac8efc5e',(.8,.8,1.85)),
 'moss_patch':('35ad7ced-c425-407b-be98-e37dc3bd5d60',(1.0,.9,.09)),
 'moss_clumps':('d96e0f13-200a-4d89-b59a-458c6ac17ed7',(1.0,.9,.13)),
 'moss_seam':('aa98e3a9-34ed-4037-bab8-a4344d018873',(1.2,.32,.08)),
}
report={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'assets':{}}
for ob in bpy.context.scene.objects:ob.select_set(False)
for key,(name,dimensions) in assets.items():
 mesh=bpy.data.objects[name].data.copy();mesh.transform(Matrix.Rotation(-math.pi/2,4,'Z'))
 if key=='broken_column':mesh.transform(Matrix.Rotation(math.pi/2,4,'Y'))
 lo=Vector([min(v.co[a] for v in mesh.vertices) for a in range(3)]);hi=Vector([max(v.co[a] for v in mesh.vertices) for a in range(3)])
 pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 mesh.transform(Matrix.Diagonal(Vector((*[dimensions[a]/(hi-lo)[a] for a in range(3)],1)))@Matrix.Translation(-pivot))
 ob=bpy.data.objects.new(key,mesh);bpy.context.collection.objects.link(ob);ob.select_set(True);bpy.context.view_layer.objects.active=ob
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 report['assets'][key]={'source_object':name,'dimensions_godot':[dimensions[0],dimensions[2],dimensions[1]]}
 bpy.data.objects.remove(ob,do_unlink=True)
# No boulder exists in item2: make a clearly recorded replaceable proxy with the existing rock texture.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
ob=bpy.context.object;ob.name='moss_rock_proxy'
ob.location=(0,0,0)
for v in ob.data.vertices:
 v.co*=1+.10*math.sin(v.co.x*11+v.co.z*7)*math.cos(v.co.y*8)
 v.co.x*=.65;v.co.y*=.53;v.co.z*=.52
lo=min(v.co.z for v in ob.data.vertices)
for v in ob.data.vertices:v.co.z=max(0.0,v.co.z-lo-.18)
height=max(v.co.z for v in ob.data.vertices)
for v in ob.data.vertices:v.co.z*=.8/height
for polygon in ob.data.polygons:polygon.use_smooth=True
mat=bpy.data.materials.new('ExistingRockTexture');mat.use_nodes=True
bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.9
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'source_assets/environments/dungeon/forest_courtyard/v001/textures/worn_rock_natural_01_diff_2k.jpg.jpg'));mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);ob.data.materials.append(mat)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'moss_rock.glb'),export_format='GLB',use_selection=True,export_animations=False)
report['assets']['moss_rock']={'source_object':'procedural replaceable proxy; no boulder in item2','dimensions_godot':[ob.dimensions.x,ob.dimensions.z,ob.dimensions.y]}
assert report['source_sha256']==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
(OUT/'provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('COMPOSITION_EXPORT_OK')
