"""Offline foliage-only derivative. Buildings and the saved high-poly .blend are untouched.

Rasterize the eight original raised-leaf triangles into silhouette/tangent normals,
then reconstruct each original leaf's local frame and replace it with one quad.
No density thinning or placement randomization. All repeated instances share meshes.
"""
import bpy
import numpy as np
import json
import struct


def leaf_design():
    outline = [(0, 0), (.2, -.34), (.5, -.5), (.77, -.29),
               (1, 0), (.77, .29), (.5, .5), (.2, .34)]
    rows = [[1, t, w, .025 * np.sin(t * np.pi) - .13 * t * t] for t, w in outline]
    rows.append([1, .43, 0, .075])
    return np.array(rows)


def save_image(name, pixels, out, non_color=False):
    height, width, _ = pixels.shape
    image = bpy.data.images.new(name, width=width, height=height, alpha=True)
    if non_color:
        image.colorspace_settings.name = 'Non-Color'
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw = str(out / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    return image


def bake_leaf_maps(config, out):
    """Orthographic projection of source triangles, equivalent to a normal/coverage bake.
    Tangent +X follows the leaf's length; +Y is opposite the procedural side axis.
    RGB colors remain unlit so the existing Godot sun still shades each leaf.
    """
    size = config['leaf_card_resolution']
    t0, t1 = config['leaf_t_bounds']
    w0, w1 = config['leaf_w_bounds']
    design = leaf_design()
    points = design[:, [1, 2, 3]].copy()
    points[:, 1] *= -config['leaf_reference_width']
    uv = np.column_stack(((design[:, 1] - t0) / (t1 - t0), (w1 - design[:, 2]) / (w1 - w0)))
    grid = (np.arange(size) + .5) / size
    u, v = np.meshgrid(grid, grid)
    coverage = np.zeros((size, size), dtype=np.float32)
    normals = np.zeros((size, size, 4), dtype=np.float32)
    normals[:, :, :] = (.5, .5, 1, 1)
    for i in range(8):
        ids = [8, (i + 1) % 8, i]
        a, b, c = uv[ids]
        den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        wa = ((b[1]-c[1])*(u-c[0])+(c[0]-b[0])*(v-c[1]))/den
        wb = ((c[1]-a[1])*(u-c[0])+(a[0]-c[0])*(v-c[1]))/den
        inside = (wa >= 0) & (wb >= 0) & (wa+wb <= 1)
        a3, b3, c3 = points[ids]
        normal = np.cross(b3-a3, c3-a3)
        normal /= np.linalg.norm(normal)
        assert normal[2] > 0
        coverage[inside] = 1
        normals[inside, :3] = normal*.5+.5
    normal_image = save_image('RuntimeLeaf_normal', normals, out, True)
    return coverage, normal_image


def optimize(scene, config, out):
    coverage, normal_image = bake_leaf_maps(config, out)
    material_cache = {}
    mesh_cache = {}
    report = {'method': '8-triangle raised leaves to 2-triangle alpha-cutout cards with projected tangent normals',
              'config': config, 'changed': [], 'shared_meshes': []}

    def card_material(source):
        if source in material_cache:
            return material_cache[source]
        original = next(n for n in source.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        image = original.inputs['Base Color'].links[0].from_node.image
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(image.size[1], image.size[0], 4)
        size = config['leaf_card_resolution']
        ys = np.linspace(0, image.size[1]-1, size).astype(int)
        xs = np.linspace(0, image.size[0]-1, size).astype(int)
        rgba = pixels[ys[:, None], xs[None, :]].copy()
        rgba[:, :, 3] = coverage
        color = save_image('RuntimeLeaf_' + source.name, rgba, out)
        mat = bpy.data.materials.new('RuntimeLeaf_' + source.name)
        mat.use_nodes = True
        mat.use_backface_culling = False
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        p = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        p.inputs['Roughness'].default_value = original.inputs['Roughness'].default_value
        tex = nodes.new('ShaderNodeTexImage'); tex.image = color
        links.new(tex.outputs['Color'], p.inputs['Base Color'])
        links.new(tex.outputs['Alpha'], p.inputs['Alpha'])
        normal_tex = nodes.new('ShaderNodeTexImage'); normal_tex.image = normal_image
        normal = nodes.new('ShaderNodeNormalMap')
        links.new(normal_tex.outputs['Color'], normal.inputs['Color'])
        links.new(normal.outputs['Normal'], p.inputs['Normal'])
        material_cache[source] = mat
        return mat

    def cards(source):
        key = ('cards', source)
        if key in mesh_cache:
            return mesh_cache[key]
        assert len(source.vertices) % 9 == 0, source.name
        count = len(source.vertices)//9
        assert len(source.polygons) == count*8, source.name
        positions = np.empty(len(source.vertices)*3, dtype=np.float64)
        source.vertices.foreach_get('co', positions)
        positions = positions.reshape(count, 9, 3)
        design = leaf_design()
        frames = np.einsum('ij,njk->nik', np.linalg.pinv(design), positions)
        error = float(np.max(np.abs(np.einsum('ij,njk->nik', design, frames)-positions)))
        assert error < 0.0001, (source.name, error)
        t0,t1 = config['leaf_t_bounds']; w0,w1 = config['leaf_w_bounds']
        plane = config['leaf_plane_height']
        corners = np.array([[1,t0,w1,plane],[1,t1,w1,plane],[1,t1,w0,plane],[1,t0,w0,plane]])
        verts = np.einsum('ij,njk->nik', corners, frames).reshape(-1,3)
        faces = [(i*4,i*4+1,i*4+2,i*4+3) for i in range(count)]
        result = bpy.data.meshes.new(source.name+'_RuntimeCards')
        result.from_pydata(verts.tolist(), [], faces)
        result.update()
        uv = result.uv_layers.new(name='LeafBakeUV')
        uv.data.foreach_set('uv', np.tile([0,0,1,0,1,1,0,1], count))
        indices = np.empty(len(source.polygons), dtype=np.int32)
        source.polygons.foreach_get('material_index', indices)
        assert np.all(indices.reshape(count,8) == indices[::8,None])
        result.polygons.foreach_set('material_index', indices[::8])
        for mat in source.materials:
            result.materials.append(card_material(mat))
        report['shared_meshes'].append({'source':source.name,'leaves':count,'before_triangles':count*8,'after_triangles':count*2,'frame_fit_error':error})
        mesh_cache[key] = result
        return result

    for obj in list(scene.objects):
        if obj.type != 'MESH':
            continue
        source = obj.data
        mode = None
        if source.name in config['leaf_mesh_names'] or obj.name in config['leaf_object_names']:
            obj.data = cards(source)
            mode = 'leaf_cards'
        elif (any(obj.name.startswith(prefix) for prefix in config['background_tree_prefixes']) or obj.name in config['foreground_tree_names']) and not obj.name.endswith('_Living_Canopy'):
            assert any(c.name == 'Forest' for c in obj.users_collection), obj.name
            ratio = config['foreground_tree_ratio'] if obj.name in config['foreground_tree_names'] else config['background_tree_ratio']
            key = ('decimate', source, ratio)
            if key not in mesh_cache:
                tmp = bpy.data.objects.new('_RuntimeTreeSimplify', source.copy())
                scene.collection.objects.link(tmp)
                modifier = tmp.modifiers.new('RuntimeBackgroundOnly','DECIMATE')
                modifier.ratio = ratio
                modifier.use_collapse_triangulate = True
                depsgraph = bpy.context.evaluated_depsgraph_get()
                mesh_cache[key] = bpy.data.meshes.new_from_object(tmp.evaluated_get(depsgraph), depsgraph=depsgraph)
                bpy.data.objects.remove(tmp, do_unlink=True)
            obj.data = mesh_cache[key]
            mode = 'tree_decimation'
        if mode:
            source.calc_loop_triangles();obj.data.calc_loop_triangles()
            report['changed'].append({'name':obj.name,'mode':mode,'before_triangles':len(source.loop_triangles),'after_triangles':len(obj.data.loop_triangles)})
    assert len(report['changed']) > 0
    print('FOLIAGE_OPTIMIZED',len(report['changed']),flush=True)
    return report


def finalize_glb(path):
    """Explicit glTF MASK avoids Blender-version dependent alpha blend export modes."""
    data = path.read_bytes()
    size, kind = struct.unpack_from('<II', data, 12)
    document = json.loads(data[20:20+size])
    for mat in document['materials']:
        if mat.get('name','').startswith('RuntimeLeaf_'):
            mat['alphaMode'] = 'MASK'
            mat['alphaCutoff'] = 0.5
            mat['doubleSided'] = True
    payload = json.dumps(document, separators=(',',':')).encode()
    payload += b' ' * (-len(payload)%4)
    rest = data[20+size:]
    path.write_bytes(struct.pack('<III',0x46546C67,2,20+len(payload)+len(rest))+struct.pack('<II',len(payload),kind)+payload+rest)
