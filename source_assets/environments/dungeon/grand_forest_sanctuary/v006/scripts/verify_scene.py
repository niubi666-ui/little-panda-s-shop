"""Read-only checks for the lighting revision's saved scene and source."""
import bpy, json, hashlib, array
from pathlib import Path

assert bpy.app.background
root = Path(__file__).resolve().parents[1]
profile = json.loads((root / 'scripts/lighting_profile.json').read_text(encoding='utf-8'))
saved = root / 'blender/grand_forest_sanctuary_v006_golden_canopy.blend'
assert Path(bpy.data.filepath).resolve() == saved.resolve()

def snapshot():
    scene = bpy.context.scene
    objects = {}
    for obj in scene.objects:
        objects[obj.name] = dict(
            type=obj.type, matrix=list(v for row in obj.matrix_world for v in row),
            mesh=obj.data.name if obj.type == 'MESH' else None,
            modifiers=[(mod.name, mod.node_group.name) for mod in obj.modifiers
                       if mod.type == 'NODES' and mod.node_group],
        )
    meshes = {}
    for mesh in bpy.data.meshes:
        coords = array.array('f', [0]) * (3 * len(mesh.vertices))
        indices = array.array('i', [0]) * len(mesh.loops)
        mesh.vertices.foreach_get('co', coords)
        mesh.loops.foreach_get('vertex_index', indices)
        digest = hashlib.sha256(coords.tobytes() + indices.tobytes()).hexdigest()
        meshes[mesh.name] = dict(vertices=len(mesh.vertices), polygons=len(mesh.polygons),
                                 loops=len(mesh.loops), coordinates_indices_sha256=digest)
    return objects, meshes

current_objects, current_meshes = snapshot()
scene = bpy.context.scene
proxy_names = ['Canopy_far_soft_leaf_masses', 'Canopy_near_branch_leaf_clusters']
active_proxy_triangles = sum(sum(len(p.vertices) - 2 for p in scene.objects[name].data.polygons)
                             for name in proxy_names)
hidden_old_proxy = scene.objects['LIGHTING_ONLY_overhead_leaf_shadows'].hide_render
hidden_forest = all(obj.hide_render for obj in scene.objects if obj.name.startswith('Forest_oak_'))
preview_uses_eevee = scene.render.engine == 'BLENDER_EEVEE'
packed_images = sum(bool(image.packed_file) for image in bpy.data.images)
proxy_wind = all(any(mod.type == 'NODES' and mod.node_group for mod in scene.objects[name].modifiers)
                 for name in proxy_names)

bpy.ops.wm.open_mainfile(filepath=profile['source'], load_ui=False)
source_objects, source_meshes = snapshot()
lost_objects = sorted(set(source_objects) - set(current_objects))
changed_geometry = [name for name, data in source_meshes.items() if current_meshes.get(name) != data]
changed_mesh_references = [name for name, data in source_objects.items()
                           if current_objects.get(name, {}).get('mesh') != data['mesh']]
changed_layout = [name for name, data in source_objects.items()
                  if data['type'] != 'LIGHT' and current_objects.get(name, {}).get('matrix') != data['matrix']]
changed_wind = [name for name, data in source_objects.items()
                if current_objects.get(name, {}).get('modifiers') != data['modifiers']]
source_hash = hashlib.sha256(Path(profile['source']).read_bytes()).hexdigest()
build = json.loads((root / 'reports/lighting_build.json').read_text(encoding='utf-8'))
checks = dict(
    source_hash_unchanged=source_hash == build['source_sha256'],
    original_objects_retained=not lost_objects,
    original_mesh_coordinates_indices_counts_retained=not changed_geometry,
    original_shared_mesh_references_retained=not changed_mesh_references,
    non_light_object_transforms_retained=not changed_layout,
    original_geometry_node_modifiers_retained=not changed_wind,
    old_shadow_proxy_hidden=hidden_old_proxy,
    peripheral_forest_still_hidden=hidden_forest,
    two_new_proxy_wind_modifiers_present=proxy_wind,
    eevee_preview_saved=preview_uses_eevee,
    proxy_triangle_count_matches_build=active_proxy_triangles == build['new_lighting_proxy_triangles'],
)
report = dict(checks=checks, all_passed=all(checks.values()), packed_images=packed_images,
              active_lighting_proxy_triangles=active_proxy_triangles,
              changed_geometry=changed_geometry, changed_layout=changed_layout,
              changed_mesh_references=changed_mesh_references, changed_wind=changed_wind,
              missing_source_objects=lost_objects, source_sha256=source_hash)
(root / 'reports/validation.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print('V006_READONLY_CHECKS', json.dumps(report, ensure_ascii=False), flush=True)
assert report['all_passed'], report
