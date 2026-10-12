# 森林遗迹战斗房 场景 v002：面积约 2.1 倍、真实化溪流（河床/卵石/白沫/跌水）、更多细节
# 用法：blender -b --factory-startup --python build_scene_v002.py -- [--preview] [--nofog] [--diag]
import bpy, bmesh, math, random, os, sys, time
import numpy as np
from mathutils import Vector, noise as mn

OUT = os.path.dirname(os.path.abspath(__file__))
PREVIEW = '--preview' in sys.argv
NOFOG = '--nofog' in sys.argv
T0 = time.time()
rnd = random.Random(11)
nrng = np.random.default_rng(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def log(*a): print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)

# ---------------- 工具 ----------------
def ss(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)
def n2(x, y, s=1.0, o=0.0):
    return mn.noise(Vector((x * s + o, y * s - o * 0.7, o * 0.31)))
def fbm(x, y, s=1.0, octv=4, o=0.0):
    v, a, f = 0.0, 0.5, s
    for i in range(octv):
        v += a * n2(x, y, f, o + i * 13.7); f *= 2; a *= 0.5
    return v
def lin(h, a=1.0):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (a,)

# ---------------- 布局 ----------------
K = 1.45                            # 相对 v001 的布局放大倍数（面积约 2.1 倍）
PC = (0.0, 1.0 * K)                 # 广场中心
WALL_Y = 15.2 * K
WALL_X0, WALL_X1 = -11.2 * K, 15.5 * K
def stream_x(y):
    u = y / K
    return K * (-12.5 + 2.2 * math.sin(u * 0.17 + 0.6) + 0.8 * math.sin(u * 0.41))
def stream_dir(y):
    e = 0.2; d = Vector((stream_x(y + e) - stream_x(y - e), 2 * e, 0)); return d.normalized()
def stream_w(y): return 1.55 + 0.45 * math.sin(y * 0.21 + 1.0) + 0.25 * math.sin(y * 0.53)   # 半宽
CASCADE_Y = 9.0 * K                 # 跌水位置：上游水面高，下游低
def water_level(y): return -0.42 + 0.34 * ss(CASCADE_Y - 0.5, CASCADE_Y + 0.5, y)
def stream_d(x, y): return abs(x - stream_x(y))
def plaza_r(x, y): return math.hypot(x - PC[0], y - PC[1])
def plaza_edge(x, y):
    a = math.atan2(y - PC[1], x - PC[0])
    return K * (7.3 + 0.9 * n2(math.cos(a) * 2, math.sin(a) * 2, 1.0, 3.1))
def path_mask(x, y):
    u, v = x / K, y / K
    s = (1 - ss(0.9, 2.0, abs(u - 1.0 * math.sin(v * 0.22)))) * (1 - ss(-6.5, -5.0, v))
    n = (1 - ss(1.0, 2.0, abs(u))) * ss(6.5, 8.5, v) * (1 - ss(15.5, 16.5, v))
    return max(s, n)
def height(x, y):
    r = plaza_r(x, y) / K
    h = (0.35 * fbm(x, y, 0.07 / K, 3, 1.0) + 0.08 * n2(x, y, 0.6, 5.0)) * ss(6.5, 10.5, r)
    h += ss(16, 32, r) * (2.6 + 2.2 * fbm(x, y, 0.05 / K, 3, 7.0)) * 1.25
    # 溪谷：河岸缓坡 + 河床，河床随水位走，跌水处形成台阶
    d = stream_d(x, y); w = stream_w(y); wl = water_level(y)
    bed = wl - 0.32 - 0.38 * (1 - ss(0, w, d)) + 0.06 * n2(x, y, 1.3, 8)
    bank = ss(w * 0.7, w + 1.6, d)
    h = bed * (1 - bank) + max(h, wl + 0.12) * bank if d < w + 1.6 else h
    h -= 0.25 * (1 - ss(w + 1.0, w + 3.5, d)) * (1 - bank * 0.5) * ss(w + 0.3, w + 1.6, d)
    return h
def grass_mask(x, y):
    r = plaza_r(x, y); e = plaza_edge(x, y)
    m = ss(e - 0.3, e + 1.2, r)
    if n2(x, y, 0.9, 4) > 0.15: m = max(m, 0.35 * ss(e - 2.2, e - 0.6, r))
    m *= ss(stream_w(y) + 0.5, stream_w(y) + 1.4, stream_d(x, y))
    m *= 1 - 0.85 * path_mask(x, y)
    m *= 0.45 + 0.55 * ss(-0.35, 0.25, fbm(x, y, 0.18, 3, 9))
    if WALL_X0 - 0.6 < x < WALL_X1 + 0.3 and WALL_Y - 0.8 < y < WALL_Y + 0.8: m = 0
    return m

# ---------------- 材质 ----------------
class NB:
    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        try: self.mat.use_nodes = True
        except Exception: pass
        self.nt = self.mat.node_tree; self.N = self.nt.nodes; self.L = self.nt.links
        self.bsdf = next(n for n in self.N if n.type == 'BSDF_PRINCIPLED')
        self.out = next(n for n in self.N if n.type == 'OUTPUT_MATERIAL')
    def node(self, t, **kw):
        n = self.N.new(t)
        for k, v in kw.items(): setattr(n, k, v)
        return n
    def inp(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket): self.L.new(v, sock)
        else: sock.default_value = v
    def attr(self, name): return self.node('ShaderNodeAttribute', attribute_name=name).outputs['Fac']
    def coord(self, kind='Object'): return self.node('ShaderNodeTexCoord').outputs[kind]
    def noise(self, scale, detail=4.0, rough=0.55, vec=None):
        n = self.node('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = rough
        if vec is not None: self.L.new(vec, n.inputs['Vector'])
        return n.outputs['Fac']
    def math(self, op, a, b=0.0, clamp=False):
        n = self.node('ShaderNodeMath', operation=op, use_clamp=clamp)
        self.inp(n.inputs[0], a); self.inp(n.inputs[1], b); return n.outputs[0]
    def mr(self, x, a, b, c=0.0, d=1.0, smooth=True):
        n = self.node('ShaderNodeMapRange')
        if smooth: n.interpolation_type = 'SMOOTHSTEP'
        self.inp(n.inputs['Value'], x)
        n.inputs['From Min'].default_value = a; n.inputs['From Max'].default_value = b
        n.inputs['To Min'].default_value = c; n.inputs['To Max'].default_value = d
        return n.outputs['Result']
    def mix(self, fac, a, b, blend='MIX'):
        n = self.node('ShaderNodeMix', data_type='RGBA', blend_type=blend)
        self.inp(next(s for s in n.inputs if s.name == 'Factor' and s.type == 'VALUE'), fac)
        self.inp(next(s for s in n.inputs if s.name == 'A' and s.type == 'RGBA'), a)
        self.inp(next(s for s in n.inputs if s.name == 'B' and s.type == 'RGBA'), b)
        return next(s for s in n.outputs if s.type == 'RGBA')
    def ao(self, dist, lo):
        n = self.node('ShaderNodeAmbientOcclusion'); n.inputs['Distance'].default_value = dist
        return self.mr(n.outputs['AO'], 0.0, 1.0, lo, 1.0, False)
    def normal_z(self):
        g = self.node('ShaderNodeNewGeometry'); s = self.node('ShaderNodeSeparateXYZ')
        self.L.new(g.outputs['Normal'], s.inputs[0]); return s.outputs['Z']
    def bump(self, h, strength):
        b = self.node('ShaderNodeBump'); b.inputs['Strength'].default_value = strength
        self.L.new(h, b.inputs['Height']); self.L.new(b.outputs['Normal'], self.bsdf.inputs['Normal'])
    def set(self, name, v): self.inp(self.bsdf.inputs[name], v)
    def surface(self, sock): self.L.new(sock, self.out.inputs['Surface'])

def stone_mat(name, ca, cb, moss=1.0, scale=1.2, stretch=None, mossz=(0.45, 0.9)):
    m = NB(name)
    co = m.coord()
    if stretch:
        mp = m.node('ShaderNodeMapping'); mp.inputs['Scale'].default_value = stretch
        m.L.new(co, mp.inputs['Vector']); co = mp.outputs['Vector']
    n1 = m.noise(scale, 6, 0.6, co); nf = m.noise(scale * 7, 4, 0.6, co)
    col = m.mix(m.mr(n1, 0.35, 0.65), lin(ca), lin(cb))
    col = m.mix(m.mr(nf, 0.3, 0.7, 0, 0.3), col, lin('#34312b'))
    top = m.mr(m.normal_z(), mossz[0], mossz[1])
    patch = m.mr(m.noise(0.9, 4, 0.6, m.coord()), 0.4, 0.58)
    mo = m.math('MULTIPLY', m.math('MULTIPLY', top, patch, True), moss, True)
    mc = m.mix(m.mr(nf, 0.3, 0.7), lin('#3c5a20'), lin('#76913a'))
    col = m.mix(mo, col, mc)
    col = m.mix(1.0, col, m.ao(0.7, 0.35), 'MULTIPLY')
    m.set('Base Color', col); m.set('Roughness', m.mr(mo, 0, 1, 0.78, 0.95, False))
    m.bump(nf, 0.35)
    return m.mat

def emissive(name, col, strength, base='#202020'):
    m = NB(name)
    m.set('Base Color', lin(base)); m.set('Emission Color', lin(col)); m.set('Emission Strength', strength)
    return m.mat

log('materials')
MAT_STONE = stone_mat('Stone', '#6f6a60', '#9c9482')
MAT_BARK = stone_mat('Bark', '#2f231b', '#5a4434', moss=0.7, scale=1.6, stretch=(3.0, 3.0, 0.35), mossz=(0.2, 0.75))

# 地面
g = NB('Ground'); co = g.coord()
nb = g.noise(0.08, 3, 0.5, co); nm = g.noise(0.6, 5, 0.6, co); nfn = g.noise(6.0, 3, 0.6, co)
grass = g.mix(g.mr(nb, 0.35, 0.65), lin('#3a5722'), lin('#7c913f'))
grass = g.mix(g.mr(nm, 0.45, 0.7, 0, 0.5), grass, lin('#55642a'))
dirt = g.mix(g.mr(nm, 0.3, 0.7), lin('#5a4835'), lin('#8a7356'))
c = g.mix(g.attr('dirt'), grass, dirt)
c = g.mix(g.attr('plaza'), c, lin('#3a3026'))
c = g.mix(g.attr('wet'), c, lin('#2b2720'))
# 水下河床：浅处是沙砾色，越深越偏墨绿，模拟水的吸收
c = g.mix(g.mr(g.attr('depth'), 0.0, 0.08), c, lin('#6e6450'))
c = g.mix(g.mr(g.attr('depth'), 0.05, 0.6), c, lin('#1d3a33'))
c = g.mix(1.0, c, g.mr(nfn, 0.2, 0.8, 0.75, 1.1, False), 'MULTIPLY')
g.set('Base Color', c); g.set('Roughness', g.mr(g.attr('wet'), 0, 1, 0.95, 0.35, False)); g.bump(nfn, 0.3)
MAT_GROUND = g.mat

# 石板
t = NB('Tiles'); co = t.coord()
tv = t.attr('tv'); nf = t.noise(9.0, 4, 0.6, co)
c = t.mix(tv, lin('#857e70'), lin('#b3a993'))
c = t.mix(t.mr(tv, 0.82, 0.9), c, lin('#a08566'))
c = t.mix(t.mr(nf, 0.3, 0.7, 0, 0.3), c, lin('#3a362f'))
mo = t.math('MULTIPLY', t.attr('tm'), t.mr(t.noise(1.4, 4, 0.6, co), 0.38, 0.62), True)
c = t.mix(mo, c, t.mix(t.mr(nf, 0.3, 0.7), lin('#3c5a20'), lin('#6f8a35')))
c = t.mix(1.0, c, t.ao(0.35, 0.3), 'MULTIPLY')
t.set('Base Color', c); t.set('Roughness', 0.82); t.bump(nf, 0.3)
MAT_TILE = t.mat

# 叶片贴图（一簇六片叶子）
def leaf_image():
    S = 256
    yy, xx = np.mgrid[0:S, 0:S]; u = (xx + 0.5) / S * 2 - 1; v = (yy + 0.5) / S * 2 - 1
    A = np.zeros((S, S)); C = np.ones((S, S))
    for cx, cy, ang, L, W in [(0, -0.05, 90, 0.62, 0.26), (-0.34, 0.1, 150, 0.45, 0.2), (0.34, 0.08, 30, 0.47, 0.2),
                              (-0.25, -0.45, 220, 0.42, 0.18), (0.26, -0.43, -40, 0.42, 0.18), (0.0, 0.52, 95, 0.4, 0.17)]:
        a = math.radians(ang); ca, sa = math.cos(a), math.sin(a)
        px, py = u - cx, v - cy
        al = px * ca + py * sa; ac = -px * sa + py * ca; tt = al / L
        inside = (np.abs(tt) < 1) & (np.abs(ac) < W * np.clip(1 - tt * tt, 0, 1) ** 0.7 * (1 - 0.25 * tt))
        shade = 0.8 + 0.2 * (tt * 0.5 + 0.5) - 0.22 * np.exp(-(ac / 0.012) ** 2) * (np.abs(tt) < 0.95)
        A = np.where(inside, 1.0, A); C = np.where(inside, shade, C)
    img = bpy.data.images.new('LeafAtlas', S, S, alpha=True)
    img.pixels.foreach_set(np.stack([C, C, C, A], -1).astype(np.float32).ravel())
    try: img.pack()
    except Exception as e: log('pack fail', e)
    return img
LEAF_IMG = leaf_image()

def foliage_mat(name, dark, light, trans, cards):
    m = NB(name)
    col = m.mix(m.attr('lv'), lin(dark), lin(light))
    if cards:
        tex = m.node('ShaderNodeTexImage'); tex.image = LEAF_IMG
        m.L.new(m.coord('UV'), tex.inputs['Vector'])
        col = m.mix(1.0, col, tex.outputs['Color'], 'MULTIPLY')
    col = m.mix(1.0, col, m.ao(1.4, 0.22), 'MULTIPLY')
    m.set('Base Color', col); m.set('Roughness', 0.55)
    tr = m.node('ShaderNodeBsdfTranslucent'); m.inp(tr.inputs['Color'], m.mix(0.55, col, lin(trans)))
    ms = m.node('ShaderNodeMixShader'); ms.inputs[0].default_value = 0.38
    m.L.new(m.bsdf.outputs[0], ms.inputs[1]); m.L.new(tr.outputs[0], ms.inputs[2])
    if cards:
        tp = m.node('ShaderNodeBsdfTransparent'); ma = m.node('ShaderNodeMixShader')
        m.L.new(tex.outputs['Alpha'], ma.inputs[0]); m.L.new(tp.outputs[0], ma.inputs[1]); m.L.new(ms.outputs[0], ma.inputs[2])
        m.surface(ma.outputs[0])
    else:
        m.surface(ms.outputs[0])
    return m.mat
MAT_LEAF = foliage_mat('Leaves', '#2c4f1f', '#86a845', '#c8e070', True)
MAT_CANOPY = foliage_mat('CanopyCore', '#1f3a17', '#4f7429', '#9cc050', False)

gm = NB('Grass')
c = gm.mix(gm.attr('gv'), lin('#3a5c20'), lin('#98ad48'))
c = gm.mix(1.0, c, gm.mr(gm.attr('gh'), 0, 1, 0.22, 1.0, False), 'MULTIPLY')
gm.set('Base Color', c); gm.set('Roughness', 0.55)
tr = gm.node('ShaderNodeBsdfTranslucent'); gm.inp(tr.inputs['Color'], gm.mix(0.5, c, lin('#c8dc66')))
ms = gm.node('ShaderNodeMixShader'); ms.inputs[0].default_value = 0.32
gm.L.new(gm.bsdf.outputs[0], ms.inputs[1]); gm.L.new(tr.outputs[0], ms.inputs[2]); gm.surface(ms.outputs[0])
MAT_GRASS = gm.mat

fm = NB('Flowers')
fv = fm.attr('fv')
c = fm.mix(fm.mr(fv, 0.32, 0.34), lin('#f4efe2'), lin('#f2cf55'))
c = fm.mix(fm.mr(fv, 0.7, 0.72), c, lin('#c9a7e8'))
fm.set('Base Color', c); fm.set('Roughness', 0.6)
MAT_FLOWER = fm.mat

# 溪水：透射 + 体积吸收（浅处清澈、深处青绿）+ 顺流拉伸的波纹 + 白沫
wm = NB('Water')
co = wm.coord()
mp = wm.node('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1.0, 0.28, 1.0)
wm.L.new(co, mp.inputs['Vector'])
ripple = wm.math('ADD', wm.noise(3.2, 4, 0.55, mp.outputs['Vector']), wm.math('MULTIPLY', wm.noise(11.0, 2, 0.5, co), 0.35))
foam_n = wm.mr(wm.noise(7.0, 5, 0.65, mp.outputs['Vector']), 0.38, 0.62)
foam = wm.math('MULTIPLY', wm.mr(wm.attr('foam'), 0.15, 0.9), foam_n, True)
# 透射颜色带一点青绿；深浅变化交给河床颜色（不用体积吸收：开放水面网格在 EEVEE 中会把背后整片染黑）
wm.set('Base Color', lin('#cfe6dc')); wm.set('Roughness', 0.025); wm.set('IOR', 1.333)
wm.set('Transmission Weight', 1.0)
try: wm.mat.use_raytrace_refraction = True
except Exception: pass
wm.bump(ripple, 0.09)
foam_b = wm.node('ShaderNodeBsdfDiffuse'); foam_b.inputs['Color'].default_value = lin('#f4f6f2')
mixf = wm.node('ShaderNodeMixShader')
wm.L.new(foam, mixf.inputs[0]); wm.L.new(wm.bsdf.outputs[0], mixf.inputs[1]); wm.L.new(foam_b.outputs[0], mixf.inputs[2])
wm.surface(mixf.outputs[0])
MAT_WATER = wm.mat

# 湿卵石（河床、水边）：偏暗、低粗糙度
MAT_PEBBLE = stone_mat('Pebble', '#4c4a44', '#8a857a', moss=0.25, scale=2.5, mossz=(0.7, 0.95))
pn = MAT_PEBBLE.node_tree.nodes
for l in list(MAT_PEBBLE.node_tree.links):
    if l.to_node.type == 'BSDF_PRINCIPLED' and l.to_socket.name == 'Roughness': MAT_PEBBLE.node_tree.links.remove(l)
next(n for n in pn if n.type == 'BSDF_PRINCIPLED').inputs['Roughness'].default_value = 0.32

# 新增材质：木头、布料、苔藓、蘑菇、青苔藤
def simple_mat(name, ca, cb, scale, rough, stretch=None, bump=0.25):
    m = NB(name); co = m.coord()
    if stretch:
        mp = m.node('ShaderNodeMapping'); mp.inputs['Scale'].default_value = stretch
        m.L.new(co, mp.inputs['Vector']); co = mp.outputs['Vector']
    n = m.noise(scale, 5, 0.6, co)
    c = m.mix(m.mr(n, 0.3, 0.7), lin(ca), lin(cb))
    c = m.mix(1.0, c, m.ao(0.5, 0.4), 'MULTIPLY')
    m.set('Base Color', c); m.set('Roughness', rough); m.bump(n, bump)
    return m.mat
MAT_WOOD = simple_mat('Wood', '#3d2a1c', '#6e5038', 3.0, 0.8, stretch=(1.0, 1.0, 0.12))
MAT_CLOTH = simple_mat('Banner', '#6e1f22', '#9a3a2c', 14.0, 0.9, bump=0.1)
MAT_GOLDTRIM = NB('GoldTrim'); MAT_GOLDTRIM.set('Base Color', lin('#b88a3c')); MAT_GOLDTRIM.set('Metallic', 1.0); MAT_GOLDTRIM.set('Roughness', 0.38)
MAT_GOLDTRIM = MAT_GOLDTRIM.mat
mu = NB('Mushroom')
mu.set('Base Color', mu.mix(mu.mr(mu.normal_z(), 0.2, 0.7), lin('#efe2c6'), lin('#c2552f'))); mu.set('Roughness', 0.45)
mu.set('Subsurface Weight', 0.3)
MAT_MUSHROOM = mu.mat
MAT_IVY = foliage_mat('Ivy', '#22401a', '#5e8a30', '#a8cc58', True)

MAT_SIGIL = emissive('Sigil', '#ffc96b', 4.0, '#6a5a3a')
MAT_LANTERN = emissive('LanternGlow', '#ffb260', 14.0, '#ffd8a0')
MAT_FIREFLY = emissive('Firefly', '#ffe38a', 30.0, '#ffffff')
cm = NB('Crystal')
cm.set('Base Color', lin('#3a9bb8')); cm.set('Roughness', 0.12); cm.set('Transmission Weight', 0.4)
cm.set('Emission Color', lin('#78e6ff')); cm.set('Emission Strength', 3.5)
MAT_CRYSTAL = cm.mat
MAT_IRON = NB('Iron'); MAT_IRON.set('Base Color', lin('#2a2622')); MAT_IRON.set('Metallic', 0.8); MAT_IRON.set('Roughness', 0.5)
MAT_IRON = MAT_IRON.mat

# ---------------- 网格工具 ----------------
def link(obj): scene.collection.objects.link(obj); return obj
def bm_obj(bm, name, mat, smooth=False, bevel=0.0):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    if smooth:
        try: me.shade_smooth()
        except Exception: me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    obj = link(bpy.data.objects.new(name, me))
    if mat: me.materials.append(mat)
    if bevel > 0:
        b = obj.modifiers.new('Bevel', 'BEVEL'); b.width = bevel; b.segments = 2
        b.limit_method = 'ANGLE'; b.angle_limit = math.radians(35)
    return obj

def np_obj(name, verts, faces, mat, attrs=None, uvs=None, smooth=False):
    me = bpy.data.meshes.new(name)
    k = faces.shape[1]; F = len(faces)
    me.vertices.add(len(verts)); me.vertices.foreach_set('co', verts.astype(np.float32).ravel())
    me.loops.add(F * k); me.loops.foreach_set('vertex_index', faces.astype(np.int32).ravel())
    me.polygons.add(F); me.polygons.foreach_set('loop_start', np.arange(0, F * k, k, dtype=np.int32))
    me.update(calc_edges=True)
    for n, arr in (attrs or {}).items():
        me.attributes.new(n, 'FLOAT', 'POINT').data.foreach_set('value', arr.astype(np.float32))
    if uvs is not None:
        me.uv_layers.new(name='UVMap').data.foreach_set('uv', uvs.astype(np.float32).ravel())
    if smooth:
        try: me.shade_smooth()
        except Exception: pass
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))

def instances(tv, tf, pos, rot, scl):
    """把模板 (tv, tf) 按位置/旋转(z)/缩放(3) 批量实例化成一个网格"""
    N = len(pos); c, s = np.cos(rot), np.sin(rot)
    v = tv[None] * scl[:, None, :]
    x = v[..., 0] * c[:, None] - v[..., 1] * s[:, None]
    y = v[..., 0] * s[:, None] + v[..., 1] * c[:, None]
    V = np.stack([x, y, v[..., 2]], -1) + pos[:, None, :]
    Fc = tf[None] + (np.arange(N) * len(tv))[:, None, None]
    return V.reshape(-1, 3), Fc.reshape(-1, tf.shape[1])

def unit(n):
    v = nrng.normal(size=(n, 3)); return v / np.linalg.norm(v, axis=1, keepdims=True)

# ---------------- 地形 ----------------
log('terrain')
bm = bmesh.new()
TER = 58.0
bmesh.ops.create_grid(bm, x_segments=420, y_segments=420, size=1.0)
ext = max(max(abs(v.co.x), abs(v.co.y)) for v in bm.verts)
lp, lw, ld, ldp = (bm.verts.layers.float.new(n) for n in ('plaza', 'wet', 'dirt', 'depth'))
for v in bm.verts:
    x = v.co.x / ext * TER; y = v.co.y / ext * TER + 14
    v.co = Vector((x, y, height(x, y)))
    v[ldp] = max(0.0, water_level(y) - v.co.z) if stream_d(x, y) < stream_w(y) + 1.0 else 0.0
    r = plaza_r(x, y); e = plaza_edge(x, y); w = stream_w(y)
    v[lp] = 1 - ss(e - 0.6, e + 0.4, r)
    v[lw] = 1 - ss(w + 0.2, w + 1.4, stream_d(x, y))
    v[ld] = min(1.0, path_mask(x, y) + 0.65 * (1 - ss(e + 0.2, e + 1.8, r)) * (0.6 + 0.4 * n2(x, y, 0.5, 2)))
bm_obj(bm, 'Ground', MAT_GROUND, smooth=True)

# 溪水：沿溪流中心线的带状网格，宽度随河道变化；跌水处向下弯折
log('stream')
bm = bmesh.new(); L_foam = bm.verts.layers.float.new('foam')
NY, NX = 260, 14
Y0, Y1 = -18.0, 50.0
rows = []
for j in range(NY + 1):
    y = Y0 + (Y1 - Y0) * j / NY; w = stream_w(y) + 0.45
    cx = stream_x(y); nd = stream_dir(y); side = Vector((nd.y, -nd.x, 0))
    row = []
    for i in range(NX + 1):
        u = i / NX * 2 - 1
        p = Vector((cx, y, 0)) + side * (u * w)
        z = water_level(p.y)
        # 水面微起伏：急流段更明显
        z += 0.018 * n2(p.x, p.y * 0.4, 2.0, 3) * (1 + 2 * (1 - ss(1.5, 4, abs(p.y - CASCADE_Y))))
        vv = bm.verts.new((p.x, p.y, z))
        # 白沫：跌水下方、岸边、石块周围（后面石块生成后再叠加）
        f = (1 - ss(0.0, 2.6, p.y - CASCADE_Y + 0.4)) * ss(CASCADE_Y - 0.6, CASCADE_Y - 0.1, p.y) * 1.0
        f = max(f, 0.55 * ss(0.78, 1.0, abs(u)))
        vv[L_foam] = f
        row.append(vv)
    rows.append(row)
for j in range(NY):
    for i in range(NX):
        bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
STREAM_BM_ROWS = None
stream_obj = bm_obj(bm, 'Stream', MAT_WATER, smooth=True)

# 跌水：在落差处加一道垂直水帘（带白沫）
bm = bmesh.new(); L_foam = bm.verts.layers.float.new('foam')
y = CASCADE_Y; w = stream_w(y) + 0.2; cx = stream_x(y); nd = stream_dir(y); side = Vector((nd.y, -nd.x, 0))
top_z, bot_z = water_level(y + 0.6), water_level(y - 0.6)
cols = []
for i in range(25):
    u = i / 24 * 2 - 1; col = []
    for k in range(7):
        t = k / 6
        p = Vector((cx, y, 0)) + side * (u * w) + nd * (0.35 - 0.35 * t * t - 0.1)
        vv = bm.verts.new((p.x, p.y, top_z + (bot_z - top_z) * t - 0.02))
        vv[L_foam] = 0.35 + 0.65 * t
        col.append(vv)
    cols.append(col)
for i in range(24):
    for k in range(6):
        bm.faces.new((cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1]))
bm_obj(bm, 'Cascade', MAT_WATER, smooth=True)

# ---------------- 石板广场 ----------------
log('plaza')
bm = bmesh.new()
L_tv = bm.verts.layers.float.new('tv'); L_tm = bm.verts.layers.float.new('tm')
def sector(r0, r1, a0, a1, ztop, thick, tilt, tvv, tmv, k=3):
    pts = [(r0, a0 + (a1 - a0) * i / k) for i in range(k + 1)] + [(r1, a1 - (a1 - a0) * i / k) for i in range(k + 1)]
    rm = (r0 + r1) / 2; top, bot = [], []
    for r, a in pts:
        x = PC[0] + r * math.cos(a); y = PC[1] + r * math.sin(a); z = ztop + tilt * (r - rm)
        top.append(bm.verts.new((x, y, z))); bot.append(bm.verts.new((x, y, z - thick)))
    for vv in top + bot: vv[L_tv] = tvv; vv[L_tm] = tmv
    bm.faces.new(top); bm.faces.new(bot[::-1]); m = len(pts)
    for i in range(m): bm.faces.new((top[i], top[(i + 1) % m], bot[(i + 1) % m], bot[i]))
r = 2.3; ring = 0
while r < 9.0 * K:
    w = 0.92 if ring % 2 == 0 else 0.78
    r0, r1 = r + 0.035, r + w - 0.035; rm = (r0 + r1) / 2
    segs = max(8, round(2 * math.pi * rm / rnd.uniform(0.95, 1.2)))
    off = rnd.uniform(0, 2 * math.pi); gap = 0.035 / rm
    for s in range(segs):
        a0 = off + 2 * math.pi * s / segs; a1 = off + 2 * math.pi * (s + 1) / segs; am = (a0 + a1) / 2
        x = PC[0] + rm * math.cos(am); y = PC[1] + rm * math.sin(am); e = plaza_edge(x, y)
        if rm > e - 0.1: continue
        edge = ss(e - 2.6, e - 0.1, rm)
        if rnd.random() < edge * 0.55: continue
        tilt = rnd.uniform(-0.08, 0.08) * edge
        zt = 0.12 + rnd.uniform(-0.02, 0.02) - 0.07 * edge * rnd.random()
        sector(r0, r1, a0 + gap, a1 - gap, zt, 0.32, tilt, rnd.random(), min(1, edge * 1.3 + 0.12 * rnd.random()))
    r += w; ring += 1
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm_obj(bm, 'PlazaTiles', MAT_TILE, bevel=0.03)

# 中央石台 + 符文
bm = bmesh.new()
from mathutils import Matrix
DS = 1.3   # 石台放大
for rad, top, dep in ((1.66 * DS, 0.24, 0.5), (1.18 * DS, 0.40, 0.4), (0.62 * DS, 0.5, 0.3)):
    bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=rad, radius2=rad * 0.985, depth=dep,
                          matrix=Matrix.Translation((PC[0], PC[1], top - dep / 2)))
# 石台边缘的缺口与崩落块
for i in range(5):
    a = rnd.uniform(0, 6.283); rr_ = 1.66 * DS + rnd.uniform(0.1, 0.5); s = rnd.uniform(0.18, 0.32)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((PC[0] + rr_ * math.cos(a), PC[1] + rr_ * math.sin(a), 0.14 + s * 0.3))
                          @ Matrix.Rotation(rnd.uniform(0, 6), 4, 'Z') @ Matrix.Rotation(rnd.uniform(-0.4, 0.4), 4, 'X') @ Matrix.Diagonal((s * 1.4, s, s * 0.8, 1)))
bm_obj(bm, 'Dais', MAT_STONE, smooth=False, bevel=0.03)
for R_, z_ in ((0.95 * DS, 0.404), (0.66 * DS, 0.404), (0.45 * DS, 0.504)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R_, minor_radius=0.016, major_segments=96, minor_segments=6,
                                     location=(PC[0], PC[1], z_))
    bpy.context.active_object.data.materials.append(MAT_SIGIL)
bm = bmesh.new()
for i in range(24):
    a = 2 * math.pi * i / 24
    M = Matrix.Translation((PC[0] + 1.42 * DS * math.cos(a), PC[1] + 1.42 * DS * math.sin(a), 0.245)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Diagonal((0.05, 0.18 if i % 2 else 0.1, 0.012, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
for i in range(8):
    a = 2 * math.pi * i / 8 + 0.3
    M = Matrix.Translation((PC[0] + 0.8 * DS * math.cos(a), PC[1] + 0.8 * DS * math.sin(a), 0.404)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Diagonal((0.26, 0.022, 0.012, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
# 广场石板上的放射状符文线，从石台通向四个方位
for i in range(4):
    a = math.pi / 2 * i + math.pi / 4
    for k in range(5):
        rr_ = 2.6 + k * 0.9
        M = Matrix.Translation((PC[0] + rr_ * math.cos(a), PC[1] + rr_ * math.sin(a), 0.125)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Diagonal((0.42, 0.03, 0.012, 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=M)
bm_obj(bm, 'Runes', MAT_SIGIL)

# ---------------- 断柱 ----------------
log('columns')
bm = bmesh.new()
def column(x, y, h, intact, seed):
    z0 = 0.1 if plaza_r(x, y) < 8 * K else height(x, y)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x, y, z0 + 0.12)) @ Matrix.Diagonal((1.25, 1.25, 0.5, 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x, y, z0 + 0.48)) @ Matrix.Diagonal((1.05, 1.05, 0.25, 1)))
    if h <= 0: return
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.42, radius2=0.37, depth=h,
                                matrix=Matrix.Translation((x, y, z0 + 0.6 + h / 2)))
    if intact:
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x, y, z0 + 0.6 + h + 0.1)) @ Matrix.Diagonal((0.95, 0.95, 0.22, 1)))
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x, y, z0 + 0.6 + h + 0.32)) @ Matrix.Diagonal((1.15, 1.15, 0.22, 1)))
    else:
        for v in ret['verts']:
            if v.co.z > z0 + 0.6 + h - 0.01:
                v.co.z += 0.35 * mn.noise(Vector((v.co.x * 3 + seed, v.co.y * 3, seed))) - 0.15 + 0.25 * (v.co.x - x)
COLS = [(20, 2.4, 0), (65, 4.4, 1), (110, 4.4, 1), (155, 1.5, 0), (200, 0, 0), (245, 3.0, 0), (290, 1.1, 0), (335, 3.3, 0)]
COLS += [(42, 0.6, 0), (178, 2.0, 0), (268, 0, 0), (312, 3.9, 1)]
for i, (ang, h, intact) in enumerate(COLS):
    a = math.radians(ang)
    column(PC[0] + 9.4 * K * math.cos(a), PC[1] + 9.4 * K * math.sin(a), h, intact, i * 1.7)
# 两根完整立柱之间残存的横梁
a1, a2 = math.radians(65), math.radians(110); Rk = 9.4 * K
p1 = Vector((PC[0] + Rk * math.cos(a1), PC[1] + Rk * math.sin(a1), 0)); p2 = Vector((PC[0] + Rk * math.cos(a2), PC[1] + Rk * math.sin(a2), 0))
mid = (p1 + p2) / 2; L_ = (p2 - p1).length; ang = math.atan2(p2.y - p1.y, p2.x - p1.x)
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((mid.x, mid.y, 0.1 + 0.6 + 4.4 + 0.62)) @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Diagonal((L_ + 1.0, 0.8, 0.5, 1)))
# 倒塌的柱段
for (x, y, ang, L) in ((10.6 * K, -1.2 * K, 0.5, 2.2), (12.9 * K, 0.1 * K, 0.62, 1.6), (-10.2 * K, -3.4 * K, 2.1, 1.3), (-6.5 * K, -8.2 * K, 1.2, 2.0)):
    z = height(x, y) + 0.3
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.42, radius2=0.4, depth=L,
                          matrix=Matrix.Translation((x, y, z)) @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
bm_obj(bm, 'Columns', MAT_STONE, smooth=False, bevel=0.04)

# ---------------- 残墙 + 拱门 ----------------
log('wall')
bm = bmesh.new()
AR, AZ = 1.9, 2.5
def in_arch(x, z): return abs(x) < AR + 0.15 and z < AZ + math.sqrt(max(0, (AR + 0.15) ** 2 - x * x))
x = WALL_X0
while x < WALL_X1:
    zrow = 0.0; row = 0; u = x / K
    maxh = 5.4 + 1.8 * fbm(x, 0, 0.22, 3, 4)
    if 5.5 < u < 9.5: maxh = 1.2 + 0.6 * n2(x, 0, 1.0, 2)
    if u < -8: maxh = 2.0 + (u + 11) * 0.8
    if u > 13: maxh = 3.0 - (u - 13) * 1.0
    x_next = x + rnd.uniform(0.9, 1.4)
    while zrow < maxh:
        bh = rnd.uniform(0.48, 0.6)
        # 错缝
        xs = x + (0.35 if row % 2 else 0.0)
        xe = min(x_next + (0.35 if row % 2 else 0.0), WALL_X1 + 0.3)
        cx = (xs + xe) / 2; cz = zrow + bh / 2
        if not in_arch(cx, cz) and xe - xs > 0.2:
            zg = height(cx, WALL_Y) if zrow == 0 else 0
            M = (Matrix.Translation((cx, WALL_Y + rnd.uniform(-0.05, 0.05), cz + min(zg, 0) - 0.1))
                 @ Matrix.Rotation(rnd.uniform(-0.03, 0.03), 4, 'Z') @ Matrix.Diagonal((xe - xs - 0.04, 1.1, bh - 0.03, 1)))
            bmesh.ops.create_cube(bm, size=1.0, matrix=M)
        zrow += bh; row += 1
    x = x_next
# 拱券
for i in range(11):
    a = math.pi * (i + 0.5) / 11
    M = (Matrix.Translation((math.cos(a) * (AR + 0.32), WALL_Y, AZ + math.sin(a) * (AR + 0.32)))
         @ Matrix.Rotation(-(math.pi / 2 - a), 4, 'Y') @ Matrix.Diagonal((0.52, 1.25, 0.6, 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
# 散落石块
for i in range(60):
    x = rnd.uniform(WALL_X0 + 1, WALL_X1 - 0.5); y = WALL_Y - rnd.uniform(0.9, 3.2)
    if abs(x) < 2.6: continue
    if 5 * K < x < 10 * K: y -= rnd.uniform(0, 2.5)
    s = rnd.uniform(0.45, 0.85)
    M = (Matrix.Translation((x, y, height(x, y) + s * 0.25)) @ Matrix.Rotation(rnd.uniform(0, 6.3), 4, 'Z')
         @ Matrix.Rotation(rnd.uniform(-0.3, 0.3), 4, 'X') @ Matrix.Diagonal((s * 1.6, s, s * 0.9, 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
bm_obj(bm, 'RuinWall', MAT_STONE, bevel=0.05)

# ---------------- 岩石 ----------------
log('rocks')
bm = bmesh.new()
def rock(x, y, s, flat=0.65, seed=0.0, sink=0.3):
    ret = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    sx, sy = rnd.uniform(0.8, 1.3), rnd.uniform(0.8, 1.3); rot = rnd.uniform(0, 6.3)
    z = height(x, y)
    for v in ret['verts']:
        d = v.co.normalized()
        k = 1 + 0.22 * mn.noise(d * 1.6 + Vector((seed, seed * 0.5, 0))) + 0.06 * mn.noise(d * 5 + Vector((0, seed, 0)))
        p = Vector((d.x * sx, d.y * sy, d.z * flat)) * k * s
        p = Vector((p.x * math.cos(rot) - p.y * math.sin(rot), p.x * math.sin(rot) + p.y * math.cos(rot), p.z))
        v.co = Vector((x, y, z - s * flat * sink)) + p
for (x, y, s) in ((-17, -8, 1.6), (15.5, -8.5, 1.4), (17.5, 8.5, 1.2), (-6, 21.5, 1.8), (13.5, 18, 1.3), (-16.5, 16, 1.5), (6.5, -9.8, 0.8), (12.2, 6.4, 0.6), (-7.2, 11.5, 0.7),
                  (21, -3, 1.4), (-4, -11, 1.1), (19, 14, 1.0), (24, 6, 1.7)):
    rock(x * K, y * K, s * 1.15, seed=x * 0.7 + y)
bm_obj(bm, 'Rocks', MAT_STONE, smooth=True)

# 溪流石头：岸边大石（半露出水面）、河床卵石、跌水处的石坎、垫脚石
log('stream stones')
bm = bmesh.new()
STREAM_ROCKS = []
def stream_rock(x, y, s, flat=0.6, sink=0.35, seed=0.0):
    rock(x, y, s, flat=flat, seed=seed, sink=sink); STREAM_ROCKS.append((x, y, s))
# 岸边大石块：成组分布
for i in range(26):
    y = rnd.uniform(-16, 48); side = rnd.choice((-1, 1)); w = stream_w(y)
    x = stream_x(y) + side * (w + rnd.uniform(-0.3, 0.5))
    stream_rock(x, y, rnd.uniform(0.45, 1.0), seed=i * 3.1)
    for k in range(rnd.randint(1, 3)):
        stream_rock(x + rnd.uniform(-0.9, 0.9), y + rnd.uniform(-0.9, 0.9), rnd.uniform(0.2, 0.45), seed=i * 3.1 + k * 7)
# 水中露头石（下游有白沫）
for i in range(12):
    y = rnd.uniform(-14, 46); w = stream_w(y)
    stream_rock(stream_x(y) + rnd.uniform(-0.6, 0.6) * w, y, rnd.uniform(0.3, 0.55), flat=0.55, sink=0.2, seed=90 + i)
# 跌水石坎：一排扁平石块形成台阶
y = CASCADE_Y; cx = stream_x(y); nd = stream_dir(y); side = Vector((nd.y, -nd.x, 0)); w = stream_w(y)
for i in range(9):
    u = (i / 8 * 2 - 1) * (w + 0.6)
    p = Vector((cx, y, 0)) + side * u - nd * rnd.uniform(0.2, 0.6)
    rock(p.x, p.y, rnd.uniform(0.45, 0.7), flat=0.45, seed=130 + i, sink=0.15)
    if abs(u) > w * 0.8: STREAM_ROCKS.append((p.x, p.y, 0.6))
# 垫脚石（通往西侧小路）
y = -0.5 * K; cx = stream_x(y); nd = stream_dir(y); side = Vector((nd.y, -nd.x, 0))
for i, u in enumerate((-1.55, -0.55, 0.45, 1.45)):
    p = Vector((cx, y, 0)) + side * u
    rock(p.x, p.y + rnd.uniform(-0.2, 0.2), 0.46, flat=0.38, seed=50 + i, sink=-0.05)
    STREAM_ROCKS.append((p.x, p.y, 0.46))
bm_obj(bm, 'StreamStones', MAT_PEBBLE, smooth=True)

# 河床卵石（实例化，在水下可见）
bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
for v in bm.verts: v.co *= 1 + 0.18 * mn.noise(v.co * 1.8)
peb_v = np.array([v.co[:] for v in bm.verts]); bm.faces.ensure_lookup_table()
peb_f = np.array([[v.index for v in f.verts] for f in bm.faces]); bm.free()
pp = []
for i in range(9000 if not PREVIEW else 4000):
    y = rnd.uniform(-18, 50); w = stream_w(y) + 0.9
    x = stream_x(y) + rnd.uniform(-w, w)
    pp.append((x, y, height(x, y) + 0.01))
pp = np.array(pp); Np = len(pp)
s = nrng.uniform(0.04, 0.16, Np) ** 1.0
V, F = instances(peb_v, peb_f, pp, nrng.uniform(0, 6.283, Np), np.stack([s * nrng.uniform(1.0, 1.6, Np), s, s * 0.45], 1))
np_obj('Pebbles', V, F, MAT_PEBBLE, smooth=True)

# 给水面加上石头周围的白沫（流向下游方向拖长）
fl = stream_obj.data.attributes['foam'].data
co_ = np.array([v.co[:] for v in stream_obj.data.vertices])
fv_ = np.array([d.value for d in fl])
for (x, y, s) in STREAM_ROCKS:
    d = co_[:, :2] - np.array([x, y])
    along = d[:, 1]                       # 溪流整体向 -y 流
    dist = np.sqrt(d[:, 0] ** 2 + np.where(along < 0, along * 0.35, along) ** 2)
    fv_ = np.maximum(fv_, np.clip(1 - (dist - s * 0.9) / (s * 0.9 + 0.25), 0, 1) * 0.9)
fl.foreach_set('value', fv_.astype(np.float32))

# ---------------- 树、树冠、灌木 ----------------
log('trees')
canopy_bm = bmesh.new()
CARDS = []
def add_blob(c, r, card=0.8, dens=2.2, seed=0.0, tint=0.0, inner=0.84, squash=0.8):
    ret = bmesh.ops.create_icosphere(canopy_bm, subdivisions=3, radius=1.0)
    off = Vector((seed, seed * 0.37, 0))
    for v in ret['verts']:
        d = v.co.normalized(); k = 1 + 0.3 * mn.noise(d * 1.7 + off)
        v.co = c + Vector((d.x, d.y, d.z * squash)) * r * k * inner
    N = int(4 * math.pi * r * r * dens)
    dirs = unit(N)
    k = 1 + 0.3 * np.array([mn.noise(Vector(tuple(d * 1.7)) + off) for d in dirs])
    pos = np.array(c)[None] + dirs * np.array([1, 1, squash]) * (r * k * nrng.uniform(0.86, 1.06, N))[:, None]
    nrm = dirs * 0.55 + unit(N) * 0.7
    lv = np.clip(nrng.uniform(0, 1, N) * 0.6 + 0.4 * (dirs[:, 2] * 0.5 + 0.5) + tint, 0, 1)
    CARDS.append((pos, nrm, card * nrng.uniform(0.75, 1.25, N), lv))

def tube(bm, pts, radii, segs=12, bump=0.0, seed=0.0):
    rings = []; prev = None
    for i, p in enumerate(pts):
        t = (pts[i + 1] - p).normalized() if i < len(pts) - 1 else (p - pts[i - 1]).normalized()
        if prev is None:
            ref = Vector((1, 0, 0)) if abs(t.z) > 0.9 else Vector((0, 0, 1))
            n = t.cross(ref).normalized()
        else:
            n = (prev - t * prev.dot(t)).normalized()
        prev = n; b = t.cross(n); ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs; d = n * math.cos(a) + b * math.sin(a)
            rr = radii[i] * (1 + bump * mn.noise(Vector((d.x * 2 + seed, d.y * 2, p.z * 0.7 + d.z))))
            ring.append(bm.verts.new(p + d * rr))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bm.faces.new(rings[-1])

def tree(x, y, H, R, seed, canopy=1.0, branches=(3, 4)):
    r_ = random.Random(seed); bm = bmesh.new()
    base = Vector((x, y, height(x, y) - 0.4)); n = 26; pts, radii = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append(base + Vector((0.5 * math.sin(t * 3 + seed) * t, 0.5 * math.cos(t * 2.3 + seed) * t, H * t)))
        radii.append(R * (1 - 0.5 * t) * (1 + 1.1 * (1 - ss(0, 0.1, t))))
    tube(bm, pts, radii, 16, 0.12, seed)
    for k in range(6):
        a = 2 * math.pi * k / 6 + r_.uniform(-0.35, 0.35); d = Vector((math.cos(a), math.sin(a), 0))
        L = R * r_.uniform(2.0, 3.4); rp, rr = [], []
        for i in range(8):
            t = i / 7; p = base + d * (R * 0.4 + L * t)
            p.z = height(p.x, p.y) + R * 0.55 * (1 - t) ** 1.5 - 0.25 * t
            rp.append(p); rr.append(R * 0.42 * (1 - 0.85 * t))
        tube(bm, rp, rr, 8, 0.1, seed + k)
    tips = [pts[-1]]
    for k in range(r_.randint(*branches)):
        t0 = r_.uniform(0.55, 0.82); i0 = int(t0 * (n - 1)); p0 = pts[i0]
        a = r_.uniform(0, 6.283); d = Vector((math.cos(a), math.sin(a), r_.uniform(0.5, 1.0))).normalized()
        L = H * r_.uniform(0.22, 0.36); bp, br = [], []
        for i in range(7):
            t = i / 6; bp.append(p0 + d * L * t + Vector((0, 0, L * 0.3 * t * t))); br.append(radii[i0] * 0.5 * (1 - 0.75 * t))
        tube(bm, bp, br, 10, 0.08, seed + 10 + k); tips.append(bp[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm_obj(bm, 'Tree', MAT_BARK, smooth=True)
    if canopy:
        for p in tips:
            add_blob(p + Vector((0, 0, 0.8)), r_.uniform(2.4, 3.6) * canopy, seed=seed + p.x, tint=r_.uniform(-0.1, 0.1))

TREES = [(-7.5, 19.5, 22, 1.15), (9.5, 20.5, 22, 1.05), (-1.5, 26, 20, 0.8), (5, 30, 20, 0.9), (-15, 24, 18, 0.9),
         (16, 27, 19, 0.85), (-19.5, 9, 13, 0.75), (-18.5, -5, 12, 0.7), (18.5, 3, 13, 0.8), (16.5, 13.5, 14, 0.8),
         (-11.5, 13.5, 12, 0.6), (21, 19, 15, 0.8), (-22, 18, 14, 0.8)]
TREES += [(-24, 2, 15, 0.85), (25, -6, 14, 0.8), (-26, -12, 13, 0.75), (23, 25, 17, 0.9), (-28, 28, 16, 0.85), (0, 34, 21, 1.0), (12, 35, 19, 0.85)]
for i, (x, y, H, R) in enumerate(TREES): tree(x * K, y * K, H * 1.1, R * 1.1, seed=i * 7.3)
# 倒木横跨溪流
bm = bmesh.new()
lx0, ly0, lx1, ly1 = stream_x(27) - 4.5, 27.0, stream_x(30) + 4.0, 30.0
def log_z(t):
    x = lx0 + (lx1 - lx0) * t; y = ly0 + (ly1 - ly0) * t
    return max(height(x, y), water_level(y) + 0.2) + 0.4
pts = [Vector((lx0 + (lx1 - lx0) * t, ly0 + (ly1 - ly0) * t, max(log_z(t), log_z(0) * (1 - t) + log_z(1) * t))) for t in np.linspace(0, 1, 18)]
tube(bm, pts, [0.48 - 0.1 * t for t in np.linspace(0, 1, 18)], 12, 0.1, 3.0)
# 断口处的根盘
tube(bm, [pts[0] + Vector((-0.4, -0.1, 0)), pts[0] + Vector((-0.9, -0.2, 0.2))], [0.9, 1.1], 14, 0.3, 5.0)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm_obj(bm, 'FallenLog', MAT_BARK, smooth=True)

# 画面外的高空树冠：沿阳光方向投下斑驳树影，中心石台保留一束阳光
SUN_DIR = Vector((-0.53, 0.31, 0.79)).normalized()
placed = 0
while placed < 5:
    q = Vector((rnd.uniform(-20, 20), rnd.uniform(-10, 18), 0))
    if (q - Vector((PC[0], PC[1], 0))).length < 5: continue
    if abs(q.x) < 13 and -6 < q.y < 13: continue
    z = rnd.uniform(9, 12); p = q + SUN_DIR * (z / SUN_DIR.z)
    add_blob(p, rnd.uniform(1.4, 2.0), card=0.9, dens=1.8, seed=placed * 5.1); placed += 1

# 灌木
bushes = []
for i in range(130):
    for _ in range(40):
        x = rnd.uniform(-34, 34); y = rnd.uniform(-16, 38)
        rr_ = plaza_r(x, y)
        if rr_ < plaza_edge(x, y) + 1.5 or stream_d(x, y) < stream_w(y) + 0.9 or path_mask(x, y) > 0.2: continue
        if WALL_X0 - 1 < x < WALL_X1 + 0.5 and WALL_Y - 1.2 < y < WALL_Y + 1.0: continue
        near_feature = (WALL_Y - 3 < y < WALL_Y - 0.9) or rr_ > 17 or stream_d(x, y) < stream_w(y) + 3
        if not near_feature and rnd.random() < 0.7: continue
        break
    s = rnd.uniform(0.55, 1.25); bushes.append((x, y, s))
    add_blob(Vector((x, y, height(x, y) + s * 0.45)), s, card=0.5, dens=3.2, seed=i * 2.3, tint=rnd.uniform(-0.15, 0.2), squash=0.75)
bm_obj(canopy_bm, 'CanopyCore', MAT_CANOPY, smooth=True)

log('leaf cards', sum(len(c[0]) for c in CARDS))
P = np.concatenate([c[0] for c in CARDS]); Nn = np.concatenate([c[1] for c in CARDS])
S = np.concatenate([c[2] for c in CARDS]); LV = np.concatenate([c[3] for c in CARDS])
Nn /= np.linalg.norm(Nn, axis=1, keepdims=True)
Tt = np.cross(Nn, unit(len(P))); Tt /= np.linalg.norm(Tt, axis=1, keepdims=True); Bb = np.cross(Nn, Tt)
h = (S / 2)[:, None]
V = np.stack([P - Tt * h - Bb * h, P + Tt * h - Bb * h, P + Tt * h + Bb * h, P - Tt * h + Bb * h], 1).reshape(-1, 3)
F = np.arange(len(V)).reshape(-1, 4)
UV = np.tile(np.array([[0, 0], [1, 0], [1, 1], [0, 1]], np.float32), (len(P), 1))
np_obj('LeafCards', V, F, MAT_LEAF, attrs={'lv': np.repeat(LV, 4)}, uvs=UV)

# ---------------- 草 & 花 ----------------
log('grass')
bl_v, bl_f, bl_h = [], [], []
for b in range(7):
    phi = 2 * math.pi * b / 7 + rnd.uniform(-0.3, 0.3); lean = rnd.uniform(0.08, 0.2); H = rnd.uniform(0.28, 0.55)
    off = len(bl_v); side = np.array([-math.sin(phi), math.cos(phi), 0])
    for s in range(4):
        tt = s / 3; c = np.array([math.cos(phi) * (0.03 + lean * tt * tt), math.sin(phi) * (0.03 + lean * tt * tt), H * tt])
        w = 0.032 * (1 - 0.9 * tt)
        bl_v += [c - side * w, c + side * w]; bl_h += [tt, tt]
    for s in range(3): bl_f.append([off + 2 * s, off + 2 * s + 1, off + 2 * s + 3, off + 2 * s + 2])
bl_v = np.array(bl_v); bl_f = np.array(bl_f); bl_h = np.array(bl_h)
cand = 80000 if PREVIEW else 260000
gp = []
for i in range(cand):
    x = rnd.uniform(-38, 38); y = rnd.uniform(-17, 42)
    if rnd.random() < grass_mask(x, y) * 0.6: gp.append((x, y, height(x, y) - 0.03))
gp = np.array(gp); Ng = len(gp)
log('grass clumps', Ng)
sc = nrng.uniform(0.7, 1.35, Ng); scl = np.stack([sc, sc, sc * nrng.uniform(0.8, 1.5, Ng)], 1)
V, F = instances(bl_v, bl_f, gp, nrng.uniform(0, 6.283, Ng), scl)
gv = np.repeat(np.clip(nrng.uniform(0, 1, Ng) * 0.7 + 0.3 * np.array([ss(-0.3, 0.3, fbm(p[0], p[1], 0.12, 2, 4)) for p in gp]), 0, 1), len(bl_v))
np_obj('Grass', V, F, MAT_GRASS, attrs={'gh': np.tile(bl_h, Ng), 'gv': gv})

bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
ico_v = np.array([v.co[:] for v in bm.verts]); bm.faces.ensure_lookup_table()
ico_f = np.array([[v.index for v in f.verts] for f in bm.faces]); bm.free()
fp = []
for i in range(cand // 8):
    x = rnd.uniform(-36, 36); y = rnd.uniform(-17, 40)
    if fbm(x, y, 0.2, 2, 33) > 0.12 and rnd.random() < grass_mask(x, y): fp.append((x, y, height(x, y) + rnd.uniform(0.2, 0.42)))
fp = np.array(fp); Nf = len(fp)
s = nrng.uniform(0.03, 0.05, Nf); V, F = instances(ico_v, ico_f, fp, np.zeros(Nf), np.stack([s, s, s * 0.6], 1))
np_obj('Flowers', V, F, MAT_FLOWER, attrs={'fv': np.repeat(np.array([fbm(p[0], p[1], 0.3, 2, 40) * 0.5 + 0.5 + rnd.uniform(-0.15, 0.15) for p in fp]), len(ico_v))})

# ---------------- 光源道具：灯笼、水晶、萤火 ----------------
log('props')
def point_light(name, loc, col, power, radius=0.1):
    L_ = bpy.data.lights.new(name, 'POINT'); L_.energy = power; L_.color = lin(col)[:3]; L_.shadow_soft_size = radius
    o = link(bpy.data.objects.new(name, L_)); o.location = loc; return o
bm_post, bm_glow = bmesh.new(), bmesh.new()
for (x, y) in ((-3.3, WALL_Y - 1.4), (3.3, WALL_Y - 1.4), (-2.6, -6.0 * K), (2.7, -6.3 * K)):
    z = max(height(x, y), 0.1)
    bmesh.ops.create_cube(bm_post, size=1.0, matrix=Matrix.Translation((x, y, z + 1.0)) @ Matrix.Diagonal((0.16, 0.16, 2.0, 1)))
    bmesh.ops.create_cube(bm_post, size=1.0, matrix=Matrix.Translation((x, y, z + 2.05)) @ Matrix.Diagonal((0.46, 0.46, 0.06, 1)))
    bmesh.ops.create_cube(bm_post, size=1.0, matrix=Matrix.Translation((x, y, z + 2.62)) @ Matrix.Diagonal((0.5, 0.5, 0.08, 1)))
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        bmesh.ops.create_cube(bm_post, size=1.0, matrix=Matrix.Translation((x + dx * 0.19, y + dy * 0.19, z + 2.33)) @ Matrix.Diagonal((0.04, 0.04, 0.5, 1)))
    bmesh.ops.create_icosphere(bm_glow, subdivisions=2, radius=0.13, matrix=Matrix.Translation((x, y, z + 2.33)))
    point_light('Lantern', (x, y, z + 2.33), '#ffad5c', 90, 0.12)
bm_obj(bm_post, 'LanternPosts', MAT_IRON, bevel=0.01)
bm_obj(bm_glow, 'LanternGlow', MAT_LANTERN, smooth=True)

bm = bmesh.new()
for (cx, cy, n, big) in ((12.2 * K, 12.6 * K, 8, 1.15), (stream_x(13 * K) - 3.2, 13 * K, 6, 0.9), (13.8 * K, -5.2 * K, 4, 0.65), (-9 * K, -7 * K, 3, 0.5)):
    z0 = height(cx, cy)
    for i in range(n):
        a = rnd.uniform(0, 6.283); d = rnd.uniform(0, 0.6) * big
        h = rnd.uniform(0.6, 1.8) * big * (1.3 if i == 0 else 1); rad = rnd.uniform(0.1, 0.2) * big
        tilt = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.15, 0.6)
        base = Vector((cx + math.cos(a) * d, cy + math.sin(a) * d, z0 - 0.1))
        axis = (Vector((0, 0, 1)) + tilt).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=rad, radius2=rad, depth=h,
                                    matrix=Matrix.Translation(base) @ rot @ Matrix.Translation((0, 0, h / 2)))
        top = [v for v in ret['verts'] if (v.co - base).dot(axis) > h * 0.99]
        tip = bm.verts.new(base + axis * (h + rad * 2.2))
        for f in list({f for v in top for f in v.link_faces if all(vv in top for vv in f.verts)}):
            bm.faces.remove(f)
        for k in range(len(top)):
            a_, b_ = top[k], top[(k + 1) % len(top)]
            try: bm.faces.new((a_, b_, tip))
            except Exception: pass
    point_light('CrystalGlow', (cx, cy, z0 + 0.9 * big), '#6fdcff', 160 * big, 0.3)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm_obj(bm, 'Crystals', MAT_CRYSTAL)

ff = []
for i in range(320):
    x = rnd.uniform(-30, 30); y = rnd.uniform(-14, 34)
    if plaza_r(x, y) < 9 and rnd.random() < 0.8: continue
    ff.append((x, y, height(x, y) + rnd.uniform(0.3, 2.8)))
ff = np.array(ff); s = nrng.uniform(0.018, 0.04, len(ff))
V, F = instances(ico_v, ico_f, ff, np.zeros(len(ff)), np.stack([s, s, s], 1))
np_obj('Fireflies', V, F, MAT_FIREFLY)

# ---------------- v002 新增细节 ----------------
log('details')
# 1) 拱门两侧垂挂的破旧旗帜（带金边），布面有褶皱和随风摆动的弧度
def banner(x, y, z_top, W, H, seed):
    bm = bmesh.new(); L_ = []
    nx_, nz_ = 8, 16
    for k in range(nz_ + 1):
        t = k / nz_; row = []
        for i in range(nx_ + 1):
            u = i / nx_ - 0.5
            torn = 1.0 if t < 0.85 else (1 - 0.6 * abs(math.sin(u * 9 + seed)))
            zz = z_top - H * t * torn
            yy = y - 0.62 - 0.12 * math.sin(u * 6.0 + seed) * t - 0.25 * t * t
            row.append(bm.verts.new((x + u * W * (1 - 0.06 * t), yy, zz)))
        L_.append(row)
    for k in range(nz_):
        for i in range(nx_):
            bm.faces.new((L_[k][i], L_[k][i + 1], L_[k + 1][i + 1], L_[k + 1][i]))
    o = bm_obj(bm, 'Banner', MAT_CLOTH, smooth=True)
    sol = o.modifiers.new('Solid', 'SOLIDIFY'); sol.thickness = 0.02
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.05, radius2=0.05, depth=W + 0.5,
                          matrix=Matrix.Translation((x, y - 0.62, z_top + 0.04)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    for i in (-1, 1):
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((x + i * W * 0.44, y - 0.66, z_top - H * 0.45)) @ Matrix.Diagonal((0.05, 0.03, H * 0.9, 1)))
    bm_obj(bm, 'BannerTrim', MAT_GOLDTRIM, smooth=True)
banner(-3.6, WALL_Y, 4.6, 1.15, 3.2, 1.0)
banner(3.6, WALL_Y, 4.6, 1.15, 2.6, 2.3)

# 2) 爬满残墙和柱子的藤蔓（叶片卡片沿表面垂落）
ivy_cards = []
def ivy_strand(p, length, seed, n=28):
    r_ = random.Random(seed); pts = []
    q = Vector(p)
    for k in range(n):
        q = q + Vector((r_.uniform(-0.12, 0.12), r_.uniform(-0.03, 0.03), -length / n))
        pts.append(q.copy())
    for q in pts:
        for _ in range(3):
            ivy_cards.append((np.array(q[:]) + nrng.normal(0, 0.12, 3) * [1, 0.4, 1], np.array([0, -1, 0.3]) + nrng.normal(0, 0.5, 3), r_.uniform(0.22, 0.36)))
for i in range(26):
    x = rnd.uniform(WALL_X0 + 1, WALL_X1 - 1)
    if abs(x) < 2.6 or 5 * K < x < 10 * K: continue
    ivy_strand((x, WALL_Y - 0.6, rnd.uniform(3.6, 5.6)), rnd.uniform(1.8, 4.5), i)
for i, (ang, h, intact) in enumerate(COLS):
    if h < 2: continue
    a = math.radians(ang); R_ = 9.4 * K
    for k in range(3):
        b = rnd.uniform(0, 6.283)
        ivy_strand((PC[0] + R_ * math.cos(a) + 0.44 * math.cos(b), PC[1] + R_ * math.sin(a) + 0.44 * math.sin(b), h + 0.5), h * rnd.uniform(0.5, 0.9), 100 + i * 3 + k)
P = np.array([c[0] for c in ivy_cards]); Nn = np.array([c[1] for c in ivy_cards]); S = np.array([c[2] for c in ivy_cards])
Nn /= np.linalg.norm(Nn, axis=1, keepdims=True)
Tt = np.cross(Nn, unit(len(P))); Tt /= np.linalg.norm(Tt, axis=1, keepdims=True); Bb = np.cross(Nn, Tt); h = (S / 2)[:, None]
V = np.stack([P - Tt * h - Bb * h, P + Tt * h - Bb * h, P + Tt * h + Bb * h, P - Tt * h + Bb * h], 1).reshape(-1, 3)
UV = np.tile(np.array([[0, 0], [1, 0], [1, 1], [0, 1]], np.float32), (len(P), 1))
np_obj('Ivy', V, np.arange(len(V)).reshape(-1, 4), MAT_IVY, attrs={'lv': np.repeat(nrng.uniform(0, 1, len(P)), 4)}, uvs=UV)

# 3) 树根和倒木旁的蘑菇丛
bm = bmesh.new()
def mushroom(x, y, s):
    z = height(x, y)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.05 * s, radius2=0.04 * s, depth=0.3 * s, matrix=Matrix.Translation((x, y, z + 0.15 * s)))
    ret = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=0.16 * s, matrix=Matrix.Translation((x, y, z + 0.3 * s)))
    for v in ret['verts']:
        if v.co.z < z + 0.3 * s: v.co.z = z + 0.3 * s - 0.02 * s
        else: v.co.z = z + 0.3 * s + (v.co.z - z - 0.3 * s) * 0.6
for (tx, ty, H, R) in TREES[:16]:
    for k in range(rnd.randint(2, 6)):
        a = rnd.uniform(0, 6.283); d = R * K * rnd.uniform(1.4, 2.4)
        mushroom(tx * K + d * math.cos(a), ty * K + d * math.sin(a), rnd.uniform(0.7, 1.6))
for t in np.linspace(0.05, 0.3, 6):
    mushroom(lx0 + (lx1 - lx0) * t + rnd.uniform(-0.6, 0.6), ly0 + (ly1 - ly0) * t - 0.6, rnd.uniform(0.6, 1.3))
bm_obj(bm, 'Mushrooms', MAT_MUSHROOM, smooth=True)

# 4) 溪边的香蒲 / 芦苇
bm_r = bmesh.new(); reed_pts = []
for i in range(220):
    y = rnd.uniform(-16, 46); side = rnd.choice((-1, 1)); w = stream_w(y)
    if n2(0, y, 0.25, 70) < 0.0: continue
    x = stream_x(y) + side * (w + rnd.uniform(-0.15, 0.6))
    reed_pts.append((x, y))
reed_v, reed_f = [], []
for (x, y) in reed_pts:
    z = height(x, y); H = rnd.uniform(0.9, 1.7); lean = Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 1)).normalized()
    side = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)).normalized() * 0.02
    o = len(reed_v)
    for k in range(5):
        t = k / 4; c = Vector((x, y, z)) + lean * H * t + Vector((lean.x, lean.y, 0)) * H * 0.25 * t * t
        reed_v += [c - side * (1 - 0.8 * t), c + side * (1 - 0.8 * t)]
    for k in range(4): reed_f.append((o + 2 * k, o + 2 * k + 1, o + 2 * k + 3, o + 2 * k + 2))
    if rnd.random() < 0.5:
        tip = Vector((x, y, z)) + lean * H * 0.85
        bmesh.ops.create_cone(bm_r, cap_ends=True, segments=6, radius1=0.035, radius2=0.035, depth=0.16, matrix=Matrix.Translation(tip))
rv = np.array([v[:] for v in reed_v]); rf = np.array(reed_f)
np_obj('Reeds', rv, rf, MAT_GRASS, attrs={'gh': np.tile(np.repeat(np.linspace(0, 1, 5), 2), len(reed_pts)), 'gv': np.repeat(nrng.uniform(0, 0.5, len(reed_pts)), 10)})
bm_obj(bm_r, 'ReedHeads', MAT_WOOD, smooth=True)

# 5) 广场东南侧：倾倒的破旧木货车 + 散落的木箱、木桶（冒险气息）
bm = bmesh.new()
cxw, cyw = 13.5 * K, -3.5 * K; z = height(cxw, cyw); rot = Matrix.Rotation(0.6, 4, 'Z')
base = Matrix.Translation((cxw, cyw, z + 0.65)) @ rot @ Matrix.Rotation(0.12, 4, 'X')
for k in range(5):
    bmesh.ops.create_cube(bm, size=1.0, matrix=base @ Matrix.Translation((0, -0.8 + k * 0.4, 0)) @ Matrix.Diagonal((1.6, 0.36, 0.08, 1)))
for sx in (-1, 1):
    bmesh.ops.create_cube(bm, size=1.0, matrix=base @ Matrix.Translation((sx * 0.8, 0, 0.3)) @ Matrix.Diagonal((0.08, 2.0, 0.5, 1)))
for sy in (-1, 1):
    bmesh.ops.create_cube(bm, size=1.0, matrix=base @ Matrix.Translation((0, sy * 1.0, 0.3)) @ Matrix.Diagonal((1.6, 0.08, 0.5, 1)))
bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.55, radius2=0.55, depth=0.1, matrix=Matrix.Translation((cxw - 1.0, cyw - 0.6, z + 0.5)) @ rot @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.55, radius2=0.55, depth=0.1, matrix=Matrix.Translation((cxw + 0.9, cyw + 1.6, z + 0.08)) @ Matrix.Rotation(0.2, 4, 'X'))
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((cxw - 1.4, cyw - 2.0, z + 0.25)) @ rot @ Matrix.Rotation(-0.25, 4, 'Z') @ Matrix.Diagonal((0.1, 2.4, 0.1, 1)))
for (dx, dy, s, r_) in ((1.8, -1.4, 0.7, 0.3), (2.5, -0.6, 0.55, 1.0), (2.1, -0.9, 0.45, 0.7)):
    zz = height(cxw + dx, cyw + dy)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((cxw + dx, cyw + dy, zz + s / 2)) @ Matrix.Rotation(r_, 4, 'Z') @ Matrix.Diagonal((s, s, s, 1)))
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((cxw + 2.15, cyw - 1.1, height(cxw + 2.1, cyw - 1.1) + 0.7 + 0.22)) @ Matrix.Rotation(0.5, 4, 'Z') @ Matrix.Diagonal((0.44, 0.44, 0.44, 1)))
for (dx, dy) in ((-2.3, 0.8), (-2.9, 0.1)):
    zz = height(cxw + dx, cyw + dy)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.32, radius2=0.32, depth=0.85, matrix=Matrix.Translation((cxw + dx, cyw + dy, zz + 0.42)))
bm_obj(bm, 'Cart', MAT_WOOD, bevel=0.02)

# 6) 广场西北侧：半埋的古代石像（只剩头部和肩），朝向石台
bm = bmesh.new()
sx_, sy_ = -11.0 * K, 9.5 * K; z = height(sx_, sy_)
ret = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
for v in ret['verts']:
    d = v.co.normalized(); p = Vector((d.x * 1.15, d.y * 1.0, d.z * 1.35)) * (1 + 0.05 * mn.noise(d * 3))
    if d.y < -0.6: p.y -= 0.25 * (d.z + 0.2)    # 鼻梁
    v.co = Vector((sx_, sy_, z + 1.55)) + p
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((sx_, sy_ + 0.3, z + 0.35)) @ Matrix.Rotation(0.15, 4, 'X') @ Matrix.Diagonal((3.4, 1.8, 1.2, 1)))
bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=1.2, radius2=0.95, depth=0.4, matrix=Matrix.Translation((sx_, sy_, z + 2.95)))
bm_obj(bm, 'Statue', MAT_STONE, smooth=True)

# 7) 广场上的落叶
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
lf_v = np.array([v.co[:] for v in bm.verts]); bm.faces.ensure_lookup_table(); lf_f = np.array([[v.index for v in f.verts] for f in bm.faces]); bm.free()
lp_ = []
for i in range(1400):
    a = rnd.uniform(0, 6.283); r_ = math.sqrt(rnd.random()) * 9.5 * K
    x, y = PC[0] + r_ * math.cos(a), PC[1] + r_ * math.sin(a)
    if r_ < 2.4: continue
    if rnd.random() > 0.35 + 0.65 * ss(4, 9 * K, r_): continue
    lp_.append((x, y, (0.13 if r_ < plaza_edge(x, y) else height(x, y)) + 0.005))
lp_ = np.array(lp_); s = nrng.uniform(0.25, 0.45, len(lp_))
V, F = instances(lf_v, lf_f, lp_, nrng.uniform(0, 6.283, len(lp_)), np.stack([s, s, s], 1))
tuv = lf_v[lf_f[0]][:, :2]; tuv = (tuv - tuv.min(0)) / (tuv.max(0) - tuv.min(0))   # 每个面角的 UV
UV = np.tile(tuv.astype(np.float32), (len(lp_), 1))
fallen = foliage_mat('FallenLeaves', '#6b4a22', '#b08a3c', '#d0a050', True)
np_obj('FallenLeaves', V, F, fallen, attrs={'lv': np.repeat(nrng.uniform(0, 1, len(lp_)), 4)}, uvs=UV)

# ---------------- 体积雾（贴地更浓）----------------
fogm = bpy.data.materials.new('Fog')
try: fogm.use_nodes = True
except Exception: pass
nt = fogm.node_tree
for n in list(nt.nodes):
    if n.type != 'OUTPUT_MATERIAL': nt.nodes.remove(n)
outn = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
geo = nt.nodes.new('ShaderNodeNewGeometry'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(geo.outputs['Position'], sep.inputs[0])
mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0.0; mr.inputs['From Max'].default_value = 9.0
mr.inputs['To Min'].default_value = 0.011; mr.inputs['To Max'].default_value = 0.0015; nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
vs = nt.nodes.new('ShaderNodeVolumeScatter'); vs.inputs['Anisotropy'].default_value = 0.65
vs.inputs['Color'].default_value = lin('#fff2e0')
nt.links.new(mr.outputs['Result'], vs.inputs['Density']); nt.links.new(vs.outputs[0], outn.inputs['Volume'])
bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
fog = bm_obj(bm, 'FogVolume', fogm); fog.scale = (130, 130, 30); fog.location = (0, 14, 13)
if NOFOG or '--diag' in sys.argv: fog.hide_render = True; fog.hide_viewport = True

# ---------------- 灯光 / 世界 / 相机 ----------------
log('lights & render setup')
sunL = bpy.data.lights.new('Sun', 'SUN'); sunL.energy = 5.0; sunL.angle = math.radians(2.0); sunL.color = (1.0, 0.84, 0.64)
sun = link(bpy.data.objects.new('Sun', sunL)); sun.rotation_euler = SUN_DIR.to_track_quat('Z', 'Y').to_euler()

world = bpy.data.worlds.new('World'); scene.world = world
try: world.use_nodes = True
except Exception: pass
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs['Color'].default_value = lin('#a9c2dc'); bg.inputs['Strength'].default_value = 0.75

camd = bpy.data.cameras.new('Cam'); camd.lens = 32; camd.clip_end = 500
cam = link(bpy.data.objects.new('Camera', camd)); cam.location = (-1.0, -28.0, 29.0)
cam.rotation_euler = (Vector((-1.5, 6.0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam

scene.render.engine = 'CYCLES'
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for dt in ('OPTIX', 'CUDA'):
        try:
            prefs.compute_device_type = dt; prefs.get_devices()
            if any(d.type == dt for d in prefs.devices):
                for d in prefs.devices: d.use = d.type == dt
                scene.cycles.device = 'GPU'; log('GPU', dt); break
        except Exception as e: log('device', dt, e)
except Exception as e: log('gpu setup failed', e)
cy = scene.cycles
cy.samples = 24 if PREVIEW else 256
cy.use_adaptive_sampling = True; cy.adaptive_threshold = 0.015
cy.use_denoising = True
cy.max_bounces = 10; cy.diffuse_bounces = 3; cy.glossy_bounces = 3; cy.transmission_bounces = 8
cy.transparent_max_bounces = 48; cy.volume_bounces = 0
cy.volume_step_rate = 4.0 if PREVIEW else 1.5
scene.render.resolution_x = 1600; scene.render.resolution_y = 900
scene.render.resolution_percentage = 50 if PREVIEW else 100
scene.view_settings.view_transform = 'AgX'
for look in ('AgX - Punchy', 'Punchy', 'AgX - Medium High Contrast', 'Medium High Contrast'):
    try: scene.view_settings.look = look; break
    except Exception: pass
scene.view_settings.exposure = 0.33
# 让保存的 .blend 在 EEVEE 视口里也能正确显示水面折射
for attr, val in (('use_raytracing', True), ('use_shadows', True)):
    try: setattr(scene.eevee, attr, val)
    except Exception: pass

name = 'preview_v002' if PREVIEW else 'forest_ruin_v002'
if not PREVIEW:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'forest_ruin_v002.blend'), compress=True)
scene.render.filepath = os.path.join(OUT, name + '.png')
print('LOOK', scene.view_settings.look)
if '--diag' in sys.argv:
    from bpy_extras.object_utils import world_to_camera_view
    dg = bpy.context.evaluated_depsgraph_get()
    fr = cam.data.view_frame(scene=scene); M = cam.matrix_world
    for j in range(5):
        row = []
        for i in range(7):
            u, v = i / 6, 1 - j / 4
            pl = fr[2].lerp(fr[1], u)  # 底边
            pt = fr[3].lerp(fr[0], u)  # 顶边
            d = (M.to_3x3() @ pl.lerp(pt, v)).normalized()
            hit, loc, nrm, idx, ob, _ = scene.ray_cast(dg, cam.location, d)
            if not hit: row.append('SKY'); continue
            sh = scene.ray_cast(dg, loc + nrm * 0.02 + SUN_DIR * 0.02, SUN_DIR)
            row.append(f"{ob.name[:9]}{'#' if sh[0] else '*'}{(sh[4].name[:6] if sh[0] else '')}")
        print('DIAG', ' | '.join(row))
    from collections import Counter
    cnt = Counter(); lit = 0; N = 400
    for k in range(N):
        a_ = rnd.uniform(0, 6.283); r_ = math.sqrt(rnd.random()) * 7 * K
        o = Vector((PC[0] + r_ * math.cos(a_), PC[1] + r_ * math.sin(a_), 0.6))
        hit = scene.ray_cast(dg, o, SUN_DIR)
        if not hit[0]: lit += 1
        else: cnt[hit[4].name] += 1; cnt[(round(hit[1].x / 4) * 4, round(hit[1].y / 4) * 4, round(hit[1].z / 4) * 4)] += 1
    print('PLAZA_LIT', lit / N, cnt.most_common(14))
    sys.exit(0)
log('rendering', scene.render.filepath)
bpy.ops.render.render(write_still=True)
log('done')
