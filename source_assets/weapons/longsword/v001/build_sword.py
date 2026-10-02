"""Build a simple game-ready sword in a background Blender process."""
import bpy
from pathlib import Path
from math import pi
bpy.ops.wm.read_factory_settings(use_empty=True)
base=Path(__file__).resolve().parent
root=base.parents[3]
def material(name,color,metallic,roughness):
    mat=bpy.data.materials.new(name); mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Metallic'].default_value=metallic
    bsdf.inputs['Roughness'].default_value=roughness
    return mat
steel=material('Blue silver steel',(.31,.43,.53),.78,.26)
gold=material('Antique brass',(.44,.24,.07),.72,.31)
leather=material('Dark leather grip',(.07,.026,.013),0,.76)
edge=material('Polished steel bevel',(.61,.72,.77),.88,.20)
verts=[]
for z,width,depth in [(.5,.053,.017),(.38,.072,.021),(-.32,.057,.016),(-.5,0,.001)]:
    verts.extend([(-width,0,z),(0,depth,z),(width,0,z),(0,-depth,z)])
faces=[]
for ring in range(3):
    for side in range(4):
        a=ring*4+side; b=ring*4+(side+1)%4
        faces.append((a,b,b+4,a+4))
faces.extend([(3,2,1,0),(12,13,14,15)])
mesh=bpy.data.meshes.new('Diamond blade'); mesh.from_pydata(verts,[],faces); mesh.update()
blade=bpy.data.objects.new('Blade',mesh); bpy.context.collection.objects.link(blade)
blade.data.materials.append(steel); blade.data.materials.append(edge)
for face in blade.data.polygons: face.material_index=face.index%2
def box(name,location,dimensions,mat,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object; obj.name=name; obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    mod=obj.modifiers.new('Soft metal edges','BEVEL'); mod.width=bevel; mod.segments=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj
box('Crossguard',(0,0,.535),(.31,.053,.045),gold,.009)
for side in [-1,1]:
    obj=box('Guard swept end',(side*.145,0,.525),(.067,.048,.035),gold,.009)
    obj.rotation_euler.y=side*.22
def cylinder(name,z,radius,depth,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=depth,location=(0,0,z))
    obj=bpy.context.object; obj.name=name; obj.data.materials.append(mat)
    return obj
cylinder('Leather grip',.675,.031,.22,leather)
for z in [.57,.78]: cylinder('Grip brass collar',z,.036,.018,gold)
for z in [.6,.63,.66,.69,.72,.75]: cylinder('Leather wrap seam',z,.033,.007,leather)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.044,location=(0,0,.825))
bpy.context.object.name='Pommel'; bpy.context.object.data.materials.append(gold)
bpy.ops.wm.save_as_mainfile(filepath=str(base/'longsword_v001.blend'))
out=root/'game/assets/weapons/longsword_v001/longsword.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=False)
print('SWORD_EXPORTED',out)
