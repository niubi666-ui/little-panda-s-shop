# 把 forest_ruin_v002.blend 转成 Godot 运行时资源
# 用法：blender -b forest_ruin_v002.blend --python export_godot.py -- <输出目录>
#
# 输出（全部为 Godot 坐标：+Y 向上，Blender (x, y, z) → Godot (x, z, -y)）：
#   forest_ruin_v002.glb        静态网格；材质在 Godot 端按节点名重新指定
#   ground_albedo.png           地面颜色（含苔藓、泥土、湿痕、河床深浅、AO）俯视烘焙
#   plaza_albedo.png            石板广场颜色俯视烘焙
#   leaf_atlas.png              叶片贴图
#   grass_instances.bin         草丛实例：每条 6×float32 (x, y, z, 旋转, 缩放, 色调)
#   height.bin / room_data.json 地面高度图、阻挡物包围盒、灯光点位、烘焙范围
import bpy, bmesh, sys, os, math, json, struct
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = args[0] if args else os.path.join(os.path.dirname(bpy.data.filepath), 'godot_export')
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene
def log(*a): print('[export]', *a, flush=True)
def g3(v): return [round(float(v[0]), 3), round(float(v[2]), 3), round(float(-v[1]), 3)]   # Blender → Godot

# ---------- 0. 记录灯光点位（Godot 端重建）----------
lights = []
for o in scene.objects:
    if o.type == 'LIGHT' and o.data.type == 'POINT':
        lights.append({'kind': 'crystal' if o.name.startswith('Crystal') else 'lantern', 'pos': g3(o.location),
                       'color': [round(c, 3) for c in o.data.color], 'power': o.data.energy})
sun = next(o for o in scene.objects if o.type == 'LIGHT' and o.data.type == 'SUN')
sun_dir = sun.matrix_world.to_3x3() @ Vector((0, 0, 1))          # 指向太阳
sun_info = {'to_sun': g3(sun_dir), 'color': [round(c, 3) for c in sun.data.color]}

# ---------- 1. 草丛：提取实例，不进 GLB ----------
grass = bpy.data.objects['Grass']; me = grass.data
co = np.zeros(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
gh = np.zeros(len(me.vertices), np.float32); me.attributes['gh'].data.foreach_get('value', gh)
gv = np.zeros(len(me.vertices), np.float32); me.attributes['gv'].data.foreach_get('value', gv)
VPC = 56                                                          # 每簇 7 片 × 8 顶点
co = co.reshape(-1, VPC, 3); gh = gh.reshape(-1, VPC); gv = gv.reshape(-1, VPC)
base = np.where((gh == 0)[..., None], co, np.nan)
pos = np.nanmean(base, 1)
top = co[np.arange(len(co)), gh.argmax(1)]
height_ = top[:, 2] - pos[:, 2]
first_tip = co[:, 7] - co[:, 1]                                   # 第一片叶子的朝向，近似整簇旋转
rot = np.arctan2(first_tip[:, 1], first_tip[:, 0])
rec = np.stack([pos[:, 0], pos[:, 2], -pos[:, 1], -rot, height_ / 0.45, gv[:, 0]], 1).astype(np.float32)
rec.tofile(os.path.join(OUT, 'grass_instances.bin'))
log('grass instances', len(rec))

# 去掉不进 GLB 的物体：草（改 MultiMesh）、萤火虫（改粒子）、雾、灯、相机
for o in list(bpy.data.objects):
    if o.type in ('LIGHT', 'CAMERA') or o.name.split('.')[0] in ('Grass', 'Fireflies', 'FogVolume'):
        bpy.data.objects.remove(o, do_unlink=True)

# ---------- 2. 应用修改器 ----------
dg = bpy.context.evaluated_depsgraph_get()
for o in [o for o in scene.objects if o.type == 'MESH' and o.modifiers]:
    m = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    o.modifiers.clear(); o.data = m

# ---------- 3. 俯视烘焙地面 / 广场颜色 ----------
scene.render.engine = 'CYCLES'; scene.cycles.samples = 4; scene.cycles.use_denoising = False
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'; prefs.get_devices()
    for d in prefs.devices: d.use = d.type == 'OPTIX'
    scene.cycles.device = 'GPU'
except Exception as e: log('gpu', e)

def planar_uv(o, x0, x1, y0, y1):
    me = o.data
    uv = me.uv_layers.new(name='TopUV'); me.uv_layers.active = uv
    loops = np.zeros(len(me.loops), np.int32); me.loops.foreach_get('vertex_index', loops)
    vc = np.zeros(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', vc); vc = vc.reshape(-1, 3)
    W = np.array(o.matrix_world); vw = vc @ W[:3, :3].T + W[:3, 3]
    u = (vw[loops, 0] - x0) / (x1 - x0); v = (vw[loops, 1] - y0) / (y1 - y0)
    uv.data.foreach_set('uv', np.stack([u, v], 1).astype(np.float32).ravel())

def bake_top(o, size, rect, fname):
    planar_uv(o, *rect)
    img = bpy.data.images.new(fname, size, size, alpha=False)
    mat = o.data.materials[0]; nt = mat.node_tree
    tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = img
    uvn = nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'TopUV'; nt.links.new(uvn.outputs[0], tn.inputs[0])
    nt.nodes.active = tn
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=4, uv_layer='TopUV')
    img.filepath_raw = os.path.join(OUT, fname); img.file_format = 'PNG'; img.save()
    nt.nodes.remove(tn); nt.nodes.remove(uvn)
    log('baked', fname)

GR = (-58.0, 58.0, -44.0, 72.0)                                   # 地面范围（Blender xy）
PR = (-14.5, 14.5, -13.05, 15.95)                                  # 广场范围
bake_top(bpy.data.objects['Ground'], 4096, GR, 'ground_albedo.png')
bake_top(bpy.data.objects['PlazaTiles'], 2048, PR, 'plaza_albedo.png')

# 叶片贴图
leaf = bpy.data.images['LeafAtlas']
leaf.filepath_raw = os.path.join(OUT, 'leaf_atlas.png'); leaf.file_format = 'PNG'; leaf.save()

# ---------- 4. 顶点色（Godot 端着色用）----------
def hex_lin(h):
    h = h.lstrip('#'); c = np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def attr(me, name):
    a = me.attributes.get(name)
    v = np.zeros(len(me.vertices), np.float32)
    if a is not None: a.data.foreach_get('value', v)
    return v
def set_color(o, rgb):
    me = o.data
    for a in [a for a in me.color_attributes]: me.color_attributes.remove(a)
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', np.concatenate([rgb, np.ones((len(rgb), 1))], 1).astype(np.float32).ravel())
    me.color_attributes.active_color = ca
rng = np.random.default_rng(3)
for o in list(scene.objects):
    if o.type != 'MESH': continue
    b = o.name.split('.')[0]; me = o.data; n = len(me.vertices)
    if b in ('Stream', 'Cascade'):
        set_color(o, np.stack([attr(me, 'foam'), np.zeros(n), np.zeros(n)], 1))
    elif b in ('LeafCards', 'Ivy', 'FallenLeaves'):
        lv = attr(me, 'lv')[:, None]
        pal = {'LeafCards': ('#2c4f1f', '#86a845'), 'Ivy': ('#22401a', '#5e8a30'), 'FallenLeaves': ('#6b4a22', '#b08a3c')}[b]
        set_color(o, hex_lin(pal[0]) * (1 - lv) + hex_lin(pal[1]) * lv)
    elif b == 'CanopyCore':
        z = np.zeros(n * 3, np.float32); me.vertices.foreach_get('normal', z); nz = z.reshape(-1, 3)[:, 2:3]
        t = np.clip(nz * 0.5 + 0.5, 0, 1)
        set_color(o, hex_lin('#1a3214') * (1 - t) + hex_lin('#4f7429') * t)
    elif b == 'Flowers':
        fv = attr(me, 'fv')
        c = np.where((fv < 0.33)[:, None], hex_lin('#f4efe2'), np.where((fv > 0.71)[:, None], hex_lin('#c9a7e8'), hex_lin('#f2cf55')))
        set_color(o, c)
    elif b == 'Reeds':
        gh_ = attr(me, 'gh')[:, None]; gv_ = attr(me, 'gv')[:, None]
        set_color(o, (hex_lin('#4a6526') * (1 - gv_) + hex_lin('#a3a858') * gv_) * (0.35 + 0.65 * gh_))
    elif b == 'Pebbles':
        t = np.repeat(rng.uniform(0, 1, n // 42 + 1), 42)[:n, None]
        set_color(o, hex_lin('#4c4a44') * (1 - t) + hex_lin('#8f897c') * t)

# ---------- 5. 减面 ----------
def decimate(o, ratio):
    m = o.modifiers.new('Dec', 'DECIMATE'); m.ratio = ratio
    dg = bpy.context.evaluated_depsgraph_get()
    nm = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    o.modifiers.clear(); o.data = nm
def thin(o, keep, group):
    me = o.data; bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    nI = len(bm.faces) // group; drop = np.random.default_rng(7).random(nI) > keep
    bmesh.ops.delete(bm, geom=[bm.faces[i * group + k] for i in np.nonzero(drop)[0] for k in range(group)], context='FACES')
    bm.to_mesh(me); bm.free()
RATIO = {'Ground': 0.18, 'Rocks': 0.35, 'StreamStones': 0.3, 'CanopyCore': 0.25, 'Tree': 0.55, 'FallenLog': 0.6, 'Statue': 0.5}
for o in list(scene.objects):
    if o.type != 'MESH': continue
    b = o.name.split('.')[0]
    if b == 'Pebbles': thin(o, 0.3, 80); decimate(o, 0.3)
    elif b in RATIO: decimate(o, RATIO[b])

# 合并同类物体，减少节点和 draw call
def join_prefix(prefix):
    objs = [o for o in scene.objects if o.type == 'MESH' and o.name.split('.')[0] == prefix]
    if len(objs) < 2: return
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join(); objs[0].name = prefix
for p in ('Tree', 'Torus', 'Banner', 'BannerTrim'): join_prefix(p)
for o in scene.objects:
    if o.type == 'MESH' and o.name.startswith('Torus'): o.name = 'SigilRings'

# ---------- 6. 阻挡物包围盒 ----------
BLOCK = ('Columns', 'RuinWall', 'Rocks', 'Statue', 'Cart', 'Tree', 'FallenLog', 'StreamStones', 'Crystals', 'LanternPosts')
blockers = []
for o in scene.objects:
    b = o.name.split('.')[0]
    if o.type != 'MESH' or b not in BLOCK: continue
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    W = np.array(o.matrix_world); seen = np.zeros(len(bm.verts), bool)
    for v0 in bm.verts:
        if seen[v0.index]: continue
        stack = [v0]; comp = []
        while stack:
            q = stack.pop()
            if seen[q.index]: continue
            seen[q.index] = True; comp.append(q.co[:])
            stack.extend(e.other_vert(q) for e in q.link_edges)
        if len(comp) < 4: continue
        P = np.array(comp) @ W[:3, :3].T + W[:3, 3]; lo, hi = P.min(0), P.max(0); sz = hi - lo
        if sz[2] < 0.3 or max(sz[0], sz[1]) < 0.3 or max(sz[0], sz[1]) > 30: continue
        if b == 'Tree':          # 树：只取树干底部 2 米做圆柱
            low = P[P[:, 2] < lo[2] + 2.5]
            if len(low) == 0: continue
            c = low.mean(0); r = float(np.percentile(np.linalg.norm(low[:, :2] - c[:2], axis=1), 60))
            blockers.append({'kind': 'trunk', 'center': g3(c), 'radius': round(min(r, 2.0), 3), 'height': 6.0}); continue
        c = (lo + hi) / 2
        blockers.append({'kind': b, 'center': g3(c), 'size': [round(float(sz[0]), 3), round(float(sz[2]), 3), round(float(sz[1]), 3)]})
    bm.free()
log('blockers', len(blockers))

# ---------- 7. 高度图（Godot 坐标：x 向右，z 向“下方/镜头”，与 Blender -y 对应）----------
g = bpy.data.objects['Ground']
N = 233; hm = np.zeros((N, N), np.float32)
for j in range(N):                       # j 沿 Godot +z，即 Blender -y
    by = GR[3] - (GR[3] - GR[2]) * j / (N - 1)
    for i in range(N):
        bx = GR[0] + (GR[1] - GR[0]) * i / (N - 1)
        hit, loc, *_ = g.ray_cast(Vector((bx, by, 300.0)), Vector((0, 0, -1)))
        hm[j, i] = loc.z if hit else 0.0
hm.tofile(os.path.join(OUT, 'height.bin'))
data = {
    'ground_rect_godot': {'x0': GR[0], 'x1': GR[1], 'z0': -GR[3], 'z1': -GR[2]},
    'plaza_rect_godot': {'x0': PR[0], 'x1': PR[1], 'z0': -PR[3], 'z1': -PR[2]},
    'height': {'size': N, 'file': 'height.bin'},
    'plaza_center': g3((0.0, 1.45, 0.12)), 'plaza_radius': 10.6,
    'sun': sun_info, 'lights': lights, 'blockers': blockers, 'grass_count': int(len(rec)),
}
with open(os.path.join(OUT, 'room_data.json'), 'w', encoding='utf-8') as f: json.dump(data, f, indent=1)

# ---------- 8. 导出 ----------
for m in bpy.data.materials:            # GLB 只带占位材质，Godot 端按节点名替换
    pass
tris = {}
for o in scene.objects:
    if o.type == 'MESH':
        b = o.name.split('.')[0]; tris[b] = tris.get(b, 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
log('triangles', sum(tris.values()), json.dumps(dict(sorted(tris.items(), key=lambda x: -x[1])[:12])))
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT, 'forest_ruin_v002.glb'), export_format='GLB', use_selection=False,
    export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
    export_vertex_color='ACTIVE', export_materials='PLACEHOLDER', export_lights=False, export_cameras=False)
log('done', OUT)
