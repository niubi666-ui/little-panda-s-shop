"""Shared helpers for the combat visual pass (Blender 5.x, run headless or through MCP).

Everything is built from coloured primitives: no textures, no sculpting. Colours are
authored in sRGB and stored as a linear float colour attribute named "Col", which the
Godot shaders read as albedo.

Blender axes used by every script here:  +X right, +Y away from the camera (Godot -Z), +Z up.
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

COLOR_LAYER = "Col"


def srgb(r, g=None, b=None):
    """Accept (r, g, b) in 0..1 sRGB or a '#rrggbb' string; return linear RGB."""
    if isinstance(r, str):
        text = r.lstrip("#")
        r, g, b = (int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return Vector((lin(r), lin(g), lin(b)))


def mix(a, b, t):
    return a * (1.0 - t) + b * t


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.fps = 30
    return scene


def material(name, emission=0.0):
    """Preview material: colour attribute -> base colour. Godot replaces it by name."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = COLOR_LAYER
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    if emission > 0.0:
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


class Part:
    """A bmesh that accumulates coloured primitives and becomes one mesh object."""

    def __init__(self, name, mat="VC", seed=1):
        self.name = name
        self.mat = mat
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.float_color.new(COLOR_LAYER)
        self.deform = self.bm.verts.layers.deform.verify()
        self.rng = random.Random(seed)
        self.groups = []          # vertex group names, index = group id
        self.default_bone = None

    # -- internal -----------------------------------------------------------------
    def _group(self, name):
        if name not in self.groups:
            self.groups.append(name)
        return self.groups.index(name)

    def _absorb(self, tmp, color, top=None, smooth=False, grad=(0.80, 1.06), jitter=0.035,
                bone=None, weights=None):
        """Colour a temporary bmesh and append it to this part.

        color/top: linear colours; the primitive is shaded bottom->top along world Z.
        bone: rigid weight to one bone. weights: callable(Vector) -> {bone: weight}.
        """
        tmp.normal_update()
        zs = [v.co.z for v in tmp.verts]
        z0, z1 = min(zs), max(zs)
        span = max(z1 - z0, 1e-5)
        shade = 1.0 + self.rng.uniform(-jitter, jitter)
        top = color if top is None else top
        layer = tmp.loops.layers.float_color.verify()
        for face in tmp.faces:
            face.smooth = smooth
            for loop in face.loops:
                t = (loop.vert.co.z - z0) / span
                c = mix(color, top, t) * mix(grad[0], grad[1], t) * shade
                loop[layer] = (c.x, c.y, c.z, 1.0)
        # Transfer through a mesh datablock: from_mesh() appends and merges layers by name.
        mesh = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        attr = mesh.color_attributes[0]
        attr.name = COLOR_LAYER
        start = len(self.bm.verts)
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        self.bm.verts.ensure_lookup_table()
        bone = bone or self.default_bone
        if bone is not None or weights is not None:
            for index in range(start, len(self.bm.verts)):
                vert = self.bm.verts[index]
                table = weights(vert.co) if weights is not None else {bone: 1.0}
                total = sum(table.values()) or 1.0
                for key, value in table.items():
                    if value > 0.0:
                        vert[self.deform][self._group(key)] = value / total

    @staticmethod
    def _matrix(loc, rot, scale):
        if not isinstance(scale, (tuple, list, Vector)):
            scale = (scale, scale, scale)
        return Matrix.LocRotScale(Vector(loc), Euler(rot, "XYZ"), Vector(scale))

    # -- primitives ---------------------------------------------------------------
    def blade(self, start, end, width_axis, width, thickness, color, taper=0.2, bevel=0.0, **kw):
        """Flat tapered box from start to end; width_axis fixes which way the flat faces."""
        start, end = Vector(start), Vector(end)
        along = (end - start)
        length = along.length
        z = along.normalized()
        x = Vector(width_axis)
        x = (x - z * x.dot(z)).normalized()
        y = z.cross(x)
        basis = Matrix((x, y, z)).transposed().to_4x4()
        basis.translation = (start + end) / 2.0
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            if v.co.z > 0:
                v.co.x *= taper
        bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((width, thickness, length, 1.0)), verts=tmp.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bevel, offset_type="OFFSET", segments=1, affect="EDGES")
        bmesh.ops.transform(tmp, matrix=basis, verts=tmp.verts)
        self._absorb(tmp, color, **kw)

    def box(self, size, loc, color, rot=(0, 0, 0), bevel=0.0, taper=1.0, **kw):
        """size = full extents. taper scales the top face in XY."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        if taper != 1.0:
            for v in tmp.verts:
                if v.co.z > 0:
                    v.co.x *= taper
                    v.co.y *= taper
        bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((*size, 1.0)), verts=tmp.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bevel, offset_type="OFFSET",
                            segments=1, profile=0.5, affect="EDGES")
        bmesh.ops.transform(tmp, matrix=self._matrix(loc, rot, 1.0), verts=tmp.verts)
        self._absorb(tmp, color, **kw)

    def cyl(self, r1, r2, height, loc, color, rot=(0, 0, 0), segs=10, **kw):
        """Tapered cylinder standing on its base at loc (before rotation)."""
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=r1, radius2=max(r2, 1e-4), depth=height)
        bmesh.ops.translate(tmp, verts=tmp.verts, vec=(0, 0, height / 2.0))
        bmesh.ops.transform(tmp, matrix=self._matrix(loc, rot, 1.0), verts=tmp.verts)
        self._absorb(tmp, color, **kw)

    def ball(self, scale, loc, color, rot=(0, 0, 0), sub=2, lump=0.0, lump_scale=1.2, **kw):
        """Ellipsoid from an icosphere, optionally lumpy (noise displaced)."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=1.0)
        if lump > 0.0:
            offset = Vector((self.rng.uniform(-50, 50), self.rng.uniform(-50, 50), self.rng.uniform(-50, 50)))
            for v in tmp.verts:
                n = noise.noise(v.co * lump_scale + offset)
                v.co *= 1.0 + n * lump
        bmesh.ops.transform(tmp, matrix=self._matrix(loc, rot, scale), verts=tmp.verts)
        self._absorb(tmp, color, **kw)

    def capsule(self, radius, length, loc, color, rot=(0, 0, 0), segs=10, squash=(1, 1), **kw):
        """Capsule along local Z, centred at loc, total length = length + 2*radius."""
        tmp = bmesh.new()
        # An odd ring count has no equator ring, so the middle band stretches into the tube.
        bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=7, radius=radius)
        for v in tmp.verts:
            v.co.z += length / 2.0 if v.co.z > 0.0 else -length / 2.0
        bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((squash[0], squash[1], 1.0, 1.0)), verts=tmp.verts)
        bmesh.ops.transform(tmp, matrix=self._matrix(loc, rot, 1.0), verts=tmp.verts)
        self._absorb(tmp, color, **kw)

    def limb(self, a, b, r1, r2, color, segs=8, **kw):
        """Tapered cylinder from point a to point b."""
        a, b = Vector(a), Vector(b)
        axis = b - a
        rot = axis.to_track_quat("Z", "Y").to_euler()
        self.cyl(r1, r2, axis.length, a, color, rot=(rot.x, rot.y, rot.z), segs=segs, **kw)

    def cone(self, radius, height, loc, color, rot=(0, 0, 0), segs=8, **kw):
        self.cyl(radius, 0.0, height, loc, color, rot=rot, segs=segs, **kw)

    def quad(self, points, color, **kw):
        tmp = bmesh.new()
        verts = [tmp.verts.new(p) for p in points]
        tmp.faces.new(verts)
        self._absorb(tmp, color, **kw)

    # -- output -------------------------------------------------------------------
    def finish(self, collection=None):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(material(self.mat, emission=4.0 if self.mat == "Glow" else 0.0))
        attr = mesh.color_attributes.get(COLOR_LAYER)
        if attr is not None:
            mesh.color_attributes.active_color = attr
            mesh.color_attributes.render_color_index = mesh.color_attributes.find(COLOR_LAYER)
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        for name in self.groups:
            obj.vertex_groups.new(name=name)
        return obj


def empty(name, loc, rot=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.location = loc
    obj.rotation_euler = rot
    obj.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def export_glb(path, animations=False, selection=False):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=selection,
        export_apply=not animations,
        export_yup=True,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
        export_animations=animations,
        export_animation_mode="NLA_TRACKS",
        export_anim_slide_to_zero=True,
        export_force_sampling=True,
        export_optimize_animation_size=False,
        export_skins=True,
        export_def_bones=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
