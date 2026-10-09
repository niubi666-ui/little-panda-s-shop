"""Run in a separate background Blender. Never touches an interactive scene.

Author a reusable physical arrow in canonical units: length 1, head width 1,
shaft width 0.2. Runtime dimensions and effect tuning belong to Godot Resources.
"""
from pathlib import Path
import bpy
import math
import json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
OUT = ROOT / "game/assets/vfx/elite_ranger_v001"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, metal, roughness, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Metallic"].default_value = metal
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Emission Color"].default_value = (*color, 1)
    node.inputs["Emission Strength"].default_value = emission
    return mat

wood = material("Dark polished arrow shaft", (.115, .053, .019), .05, .37)
gold = material("Antique gold blade edges", (.67, .34, .07), .82, .23)
steel = material("Silver central blade", (.65, .69, .67), .78, .25)
feather = material("Ivory feather vanes", (.76, .67, .43), .08, .58)
inlay = material("Golden rune inlay", (.98, .49, .10), .6, .25, .65)
parts = []

def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    parts.append(obj)
    return obj

def shaft(name, radius, depth, y, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth,
                                      location=(0, y, 0), rotation=(math.pi/2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for face in obj.data.polygons: face.use_smooth = True
    parts.append(obj)

# Blender +Y exports to Godot -Z; the tip is at +0.5 and tail at -0.5.
shaft("Wooden shaft", .1, .72, -.14, wood)
shaft("Gold head socket", .119, .10, .20, gold)
shaft("Gold nock", .115, .045, -.4775, gold)
outline = [(0, .5), (-.5, .20), (-.30, .12), (-.095, .21),
           (0, .12), (.095, .21), (.30, .12), (.5, .20)]
verts = [(x, y, z) for z in [-.025, .025] for x, y in outline]
faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
faces += [(i, (i+1)%8, (i+1)%8+8, i+8) for i in range(8)]
head = mesh("Swept broadhead", verts, faces, gold)
bevel = head.modifiers.new("Blade edge bevel", "BEVEL")
bevel.width = .008
bevel.segments = 1
mesh("Central steel ridge", [(-.06,.22,.028), (.06,.22,.028),
     (0,.492,.028), (0,.30,.055)], [(0,1,3),(1,2,3),(2,0,3)], steel)
mesh("Central steel ridge underside", [(-.06,.22,-.028), (.06,.22,-.028),
     (0,.492,-.028), (0,.30,-.055)], [(1,0,3),(2,1,3),(0,2,3)], steel)
for sign in [-1, 1]:
    for z in [-.026, .026]:
        mesh("Blade glowing incision", [(sign*.15,.245,z), (sign*.30,.231,z),
             (sign*.24,.257,z), (sign*.13,.28,z)], [(0,1,2,3)], inlay)
for index in range(3):
    angle = index*math.tau/3
    axis = (math.cos(angle), math.sin(angle))
    outline = [(.06,-.49),(.36,-.44),(.38,-.33),(.16,-.19),(.06,-.19)]
    for sign in [-1, 1]:
        verts = [(r*axis[0], y, r*axis[1]+sign*.006) for r,y in outline]
        mesh("Ivory fletching", verts, [tuple(range(5))], feather)
    for seam in range(6):
        y = -.43 + seam*.034
        mesh("Feather golden rib", [(axis[0]*.075,y,axis[1]*.075),
             (axis[0]*.30,y-.038,axis[1]*.30),
             (axis[0]*.30,y-.033,axis[1]*.30),
             (axis[0]*.075,y+.005,axis[1]*.075)], [(0,1,2,3)], gold)

bpy.ops.object.select_all(action="DESELECT")
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
arrow = bpy.context.object
arrow.name = "Ranger_Arrow"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
arrow.location = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "ranger_arrow_v001.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "ranger_arrow.glb"),
                          export_format="GLB", use_selection=True,
                          export_animations=False, export_cameras=False,
                          export_lights=False)
arrow.data.calc_loop_triangles()
report = {"blender":bpy.app.version_string,
          "triangles":len(arrow.data.loop_triangles),
          "forward":"Godot -Z", "unit_length":1, "unit_shaft_width":.2,
          "unit_head_width":1, "runtime":"game/assets/vfx/elite_ranger_v001/ranger_arrow.glb"}
(SOURCE / "arrow_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("RANGER_ARROW_ASSET", json.dumps(report))
