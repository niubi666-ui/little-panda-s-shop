"""Export three real v003 plant samples for the independent GPU breeze preview.

Run in a fresh Blender --background --factory-startup process. No render, no
source save, no changes to the original project's Blender scene or game scenes.
"""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Matrix

ROOT = Path('E:/ShopGame')
BASE = ROOT / 'source_assets/environments/dungeon/grand_forest_sanctuary'
SOURCE = BASE / 'v003/blender/grand_forest_sanctuary_v003_leaf_cutout.blend'
OUT = ROOT / 'game/assets/environment_wind_v001'
REPORT = BASE / 'v004/reports/sample_export.json'
assert bpy.app.background
OUT.mkdir(parents=True, exist_ok=True)
REPORT.parent.mkdir(parents=True, exist_ok=True)
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))

source_scene = bpy.context.scene
fern_sources = [bpy.data.objects['Fern_clump_0_' + str(i)] for i in range(2)]
bell_sources = [bpy.data.objects['White_meadow_flower_spray_0_' + str(i)] for i in range(3)]
oak_source = bpy.data.objects['Hero_Sacred_Oak_v005__BakedCrownCluster_000']
scene = bpy.data.scenes.new('Environment_Wind_Real_Asset_Samples')
bpy.context.window.scene = scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
material_cache = {}
material_report = []
object_report = []


def principal(mat):
    return next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)


def sample_material(original):
    if original.name in material_cache:
        return material_cache[original.name]
    source_p = principal(original)
    src_nodes = list(original.node_tree.nodes)
    source_images = [n for n in src_nodes if n.type == 'TEX_IMAGE' and n.image]
    color_tex = next((n for n in source_images if n.image.colorspace_settings.name != 'Non-Color'), None)
    normal_tex = next((n for n in source_images if n.image.colorspace_settings.name == 'Non-Color'), None)
    # Godot's import-name hint treats a trailing _Alpha as alpha blending and
    # overrides glTF MASK. Keep source identity in the report, use a neutral name.
    safe_name = original.name[:-6] + '_CutoutMaterial' if original.name.lower().endswith('_alpha') else original.name
    mat = bpy.data.materials.new('Breeze_' + safe_name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    ns, links = mat.node_tree.nodes, mat.node_tree.links
    ns.clear()
    out = ns.new('ShaderNodeOutputMaterial')
    p = ns.new('ShaderNodeBsdfPrincipled')
    links.new(p.outputs['BSDF'], out.inputs['Surface'])
    p.inputs['Metallic'].default_value = 0.0
    p.inputs['Roughness'].default_value = float(source_p.inputs['Roughness'].default_value)
    p.inputs['Specular IOR Level'].default_value = float(source_p.inputs['Specular IOR Level'].default_value)
    rec = {'source': original.name, 'export': mat.name, 'roughness': float(p.inputs['Roughness'].default_value)}
    if color_tex:
        tex = ns.new('ShaderNodeTexImage')
        tex.image = color_tex.image
        tex.interpolation = 'Linear'
        links.new(tex.outputs['Color'], p.inputs['Base Color'])
        cutoff = ns.new('ShaderNodeMath')
        cutoff.operation = 'GREATER_THAN'
        cutoff.inputs[1].default_value = 0.42
        links.new(tex.outputs['Alpha'], cutoff.inputs[0])
        links.new(cutoff.outputs[0], p.inputs['Alpha'])
        if normal_tex:
            tex_normal = ns.new('ShaderNodeTexImage')
            tex_normal.image = normal_tex.image
            normal = ns.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value = 0.72
            links.new(tex_normal.outputs['Color'], normal.inputs['Color'])
            links.new(normal.outputs['Normal'], p.inputs['Normal'])
        rec.update({'method': 'original UV and embedded source image; explicit PBR alpha mask',
                    'albedo_image': color_tex.image.name,
                    'normal_image': normal_tex.image.name if normal_tex else None,
                    'alpha_cutoff': 0.42,
                    'color_adjustment': 'glTF baseColorFactor [0.94, 1, 0.97, 1]; modest relative green tint only; source gamma/value lift is not baked',
                    'source_color_adjustment_not_exact': {'gamma': 0.90, 'value': 1.16, 'saturation': 1.08, 'rgb_multiplier': [0.98, 1.13, 1.05]}})
    else:
        ramps = [n for n in src_nodes if n.type == 'VALTORGB']
        if ramps:
            rgba = list(ramps[0].color_ramp.evaluate(0.5))
            method = 'representative linear color at source ColorRamp 0.5'
        else:
            rgba = list(source_p.inputs['Base Color'].default_value)
            method = 'source Principled base color'
        p.inputs['Base Color'].default_value = rgba
        mat.diffuse_color = rgba
        rec.update({'method': method, 'base_color_linear': rgba,
                    'limitation': 'procedural noise/bump and translucent mixing are not carried into this PBR sample'})
    mat['wind_color_attribute_usage'] = 'COLOR_0.r is bend data, never multiply into albedo in the preview shader'
    material_cache[original.name] = mat
    material_report.append(rec)
    return mat


def root(name, location):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.location = location
    ob['wind_kind'] = name
    return ob


def group_extent(sources):
    points = [v.co for ob in sources for v in ob.data.vertices]
    return {'z_min': min(v.z for v in points), 'z_max': max(v.z for v in points),
            'radius': max(math.hypot(v.x, v.y) for v in points)}


def add_sample(source, parent, kind, extent=None, preserve_sample_scale=True):
    mesh = source.data.copy()
    mesh.name = parent.name + '_' + source.data.name
    original_materials = list(mesh.materials)
    material_indices = [p.material_index for p in mesh.polygons]
    mesh.materials.clear()
    for mat in original_materials:
        mesh.materials.append(sample_material(mat))
    for polygon, material_index in zip(mesh.polygons, material_indices):
        polygon.material_index = material_index
    source_wind = source.data.color_attributes.get('wind_rgba')
    for attr in list(mesh.color_attributes):
        mesh.color_attributes.remove(attr)
    wind = mesh.color_attributes.new(name='BreezeWind', type='FLOAT_COLOR', domain='POINT')
    mesh.color_attributes.active_color = wind
    mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(wind)
    weights = []
    for v in mesh.vertices:
        if kind == 'OakCluster':
            weight = float(source_wind.data[v.index].color[0])
        elif kind == 'Fern':
            radial = math.hypot(v.co.x, v.co.y) / extent['radius']
            height = max(0.0, v.co.z - extent['z_min']) / (extent['z_max'] - extent['z_min'])
            # Both fern mesh parts use one shape envelope and one root anchor.
            weight = min(1.0, max(radial, height * 0.72)) ** 1.45
            weight *= min(1.0, max(radial, height) / 0.12)
        else:
            # Whole-plant z=0 anchor shared by leaves, stems and suspended bells.
            weight = min(1.0, max(0.0, v.co.z) / extent['z_max']) ** 1.5
        wind.data[v.index].color = (weight, 1.0, 1.0, 1.0)
        weights.append(weight)
    ob = bpy.data.objects.new(parent.name + '_' + source.data.name, mesh)
    scene.collection.objects.link(ob)
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = (0, 0, 0)
    ob.rotation_euler = source.rotation_euler.copy()
    ob.scale = source.scale.copy() if preserve_sample_scale else (1, 1, 1)
    ob['source_object'] = source.name
    ob['wind_kind'] = kind
    ob['wind_color_r'] = 'root-to-tip bend weight; independent of surface color'
    mesh.calc_loop_triangles()
    object_report.append({'source_object': source.name, 'source_mesh': source.data.name,
                          'export_object': ob.name, 'group': parent.name,
                          'vertices': len(mesh.vertices), 'triangles': len(mesh.loop_triangles),
                          'weight_min': min(weights), 'weight_max': max(weights),
                          'shared_extent': extent, 'source_scale': list(source.scale),
                          'export_scale': list(ob.scale), 'geometry_modified': False})
    return ob


fern_root = root('Fern', (-2, 0, 0))
fern_extent = group_extent(fern_sources)
for source in fern_sources:
    add_sample(source, fern_root, 'Fern', fern_extent)
bell_root = root('Bellflower', (0, 0, 0))
bell_extent = group_extent(bell_sources)
for source in bell_sources:
    add_sample(source, bell_root, 'Bellflower', bell_extent)
oak_root = root('OakCluster', (2.3, 0, 1.25))
add_sample(oak_source, oak_root, 'OakCluster', preserve_sample_scale=False)
bpy.context.view_layer.update()
for ob in scene.objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active = next(ob for ob in scene.objects if ob.type == 'MESH')
glb_path = OUT / 'breeze_samples.glb'
bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format='GLB', use_selection=True, use_active_scene=True,
                         export_extras=True, export_animations=False, export_cameras=False,
                         export_lights=False, export_apply=False, export_normals=True,
                         export_texcoords=True, export_vertex_color='NAME',
                         export_vertex_color_name='BreezeWind', export_all_vertex_colors=False,
                         export_attributes=False, export_image_format='AUTO')

# Make the requested alpha mask and small tint explicit in the portable artifact,
# then inspect the actual exported accessors instead of assuming export success.
raw = glb_path.read_bytes()
magic, version, total_length = struct.unpack_from('<III', raw, 0)
assert magic == 0x46546C67 and version == 2 and total_length == len(raw)
json_length, json_kind = struct.unpack_from('<II', raw, 12)
assert json_kind == 0x4E4F534A
gltf = json.loads(raw[20:20 + json_length])
binary_chunk = raw[20 + json_length:]
for mat in gltf.get('materials', []):
    mat['doubleSided'] = True
    pbr = mat.get('pbrMetallicRoughness', {})
    if 'baseColorTexture' in pbr:
        mat['alphaMode'] = 'MASK'
        mat['alphaCutoff'] = 0.42
        pbr['baseColorFactor'] = [0.94, 1.0, 0.97, 1.0]
encoded = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
encoded += b' ' * ((-len(encoded)) % 4)
glb_path.write_bytes(struct.pack('<III', magic, version, 20 + len(encoded) + len(binary_chunk)) +
                     struct.pack('<II', len(encoded), json_kind) + encoded + binary_chunk)
primitives = [p for me in gltf['meshes'] for p in me['primitives']]
all_weights = []
bin_length, bin_kind = struct.unpack_from('<II', binary_chunk, 0)
assert bin_kind == 0x004E4942
binary = binary_chunk[8:8 + bin_length]
for primitive in primitives:
    attrs = primitive['attributes']
    assert 'POSITION' in attrs and 'NORMAL' in attrs and 'COLOR_0' in attrs
    acc = gltf['accessors'][attrs['COLOR_0']]
    view = gltf['bufferViews'][acc['bufferView']]
    fmt, size, divisor = {5126: ('f', 4, 1), 5121: ('B', 1, 255), 5123: ('H', 2, 65535)}[acc['componentType']]
    components = {'VEC3': 3, 'VEC4': 4}[acc['type']]
    stride = view.get('byteStride', components * size)
    start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    for index in range(acc['count']):
        all_weights.append(struct.unpack_from('<' + fmt, binary, start + index * stride)[0] / divisor)
    mat = gltf['materials'][primitive['material']]
    if 'baseColorTexture' in mat.get('pbrMetallicRoughness', {}):
        assert 'TEXCOORD_0' in attrs and mat['alphaMode'] == 'MASK'
node_names = [n.get('name') for n in gltf['nodes']]
assert all(name in node_names for name in ['Fern', 'Bellflower', 'OakCluster'])
assert not gltf.get('cameras')
assert 'KHR_lights_punctual' not in gltf.get('extensions', {})
assert min(all_weights) < 0.02 and max(all_weights) > 0.95
assert any('normalTexture' in m for m in gltf['materials'])
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
report = {'source': str(SOURCE), 'source_sha256_before': source_hash,
          'source_sha256_after': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'output': str(glb_path), 'output_sha256': hashlib.sha256(glb_path.read_bytes()).hexdigest(),
          'blender_version': bpy.app.version_string, 'render_performed': False,
          'groups_blender_z_up': {'Fern': [-2, 0, 0], 'Bellflower': [0, 0, 0], 'OakCluster': [2.3, 0, 1.25]},
          'groups_gltf_godot_y_up': {'Fern': [-2, 0, 0], 'Bellflower': [0, 0, 0], 'OakCluster': [2.3, 1.25, 0]},
          'objects': object_report, 'materials': material_report,
          'validation': {'mesh_objects': len(object_report), 'mesh_primitives': len(primitives),
                         'all_primitives_have_position_normal_color0': True,
                         'color_r_range_in_glb': [min(all_weights), max(all_weights)],
                         'root_nodes_present': True, 'uv_on_textured_primitives': True,
                         'embedded_images': len(gltf.get('images', [])),
                         'no_alpha_import_name_hint': all(not m['name'].lower().endswith(('_alpha', '-alpha')) for m in gltf['materials']),
                         'source_hash_preserved': True, 'lights_and_cameras_absent': True},
          'consumer_contract': 'Use COLOR.r only as wind weight; custom preview shader must not multiply vertex color into albedo. Default glTF material vertex-color multiplication is unsuitable for this data channel.',
          'limits': ['Independent PBR asset sample, not the complete sanctuary lighting or scene.',
                     'Procedural ground-plant color/bump/translucency is approximated by representative color.',
                     'Atlas normal map is preserved; outer folded leaf source has no normal texture and retains its geometric normals.',
                     'Leaf gamma/value/saturation chain is not reproduced exactly; modest green tint is applied as an explicit base-color factor.']}
REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print('BREEZE_SAMPLE_EXPORT_OK', json.dumps(report['validation']), flush=True)
