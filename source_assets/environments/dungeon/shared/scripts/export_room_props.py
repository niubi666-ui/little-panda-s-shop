"""Export copies of item2 meshes. Never save or modify the source blend."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path('E:/ShopGame')
SOURCE = ROOT/'source_assets/characters/red_panda/blender/item2.blend'
OUT = ROOT/'game/assets/environments/room_props_v001'
OUT.mkdir(parents=True, exist_ok=True)
# Blender XYZ; GLTF maps these to Godot X,-Z,Y. Dimensions are art bounds.
ASSETS = {
    'barrel': ('木桶3d模型', (0.85, 0.85, 1.0)),
    'crate': ('板条箱', (0.9, 0.9, 0.9)),
    'chest1': ('chest1', (1.1, 0.78, 0.85)),
    'chest2': ('chest2', (1.2, 0.8, 0.9)),
    'forest_bag': ('forest_bag1', (0.85, 0.75, 0.9)),
    'stone_wall': ('ba956f36-4051-4087-a2ba-15b622e9bb75', (1.8, 0.6, 1.0)),
}
report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'assets': {}}
for obj in bpy.context.scene.objects: obj.select_set(False)
for key, (name, dimensions) in ASSETS.items():
    source = bpy.data.objects[name]
    mesh = source.data.copy()
    mesh.transform(Matrix.Rotation(-math.pi/2, 4, 'Z'))
    low = Vector([min(v.co[a] for v in mesh.vertices) for a in range(3)])
    high = Vector([max(v.co[a] for v in mesh.vertices) for a in range(3)])
    extent = high-low
    pivot = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    mesh.transform(Matrix.Diagonal(Vector((*[dimensions[a]/extent[a] for a in range(3)], 1))) @ Matrix.Translation(-pivot))
    obj = bpy.data.objects.new(key, mesh)
    bpy.context.collection.objects.link(obj)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')), export_format='GLB', use_selection=True, export_animations=False, export_cameras=False, export_lights=False)
    report['assets'][key] = {'source_object':name, 'dimensions_godot':[dimensions[0],dimensions[2],dimensions[1]], 'triangles':sum(len(p.vertices)-2 for p in mesh.polygons)}
    bpy.data.objects.remove(obj, do_unlink=True)
report_path = ROOT/'source_assets/environments/dungeon/shared/room_props_export.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
assert report['source_sha256'] == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
print('ROOM_PROP_EXPORT', json.dumps(report, ensure_ascii=False))
