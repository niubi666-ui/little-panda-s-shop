"""人形主角（Quaternius 通用人形 + UAL 动作 + 程序生成的太刀）→ game/assets/combat_real/hero_katana.glb

用法（后台 Blender）：
  E:\\blender\\blender.exe --background --factory-startup --python source_assets/quaternius/build_hero.py

- 角色、动作都是 CC0（Quaternius）。动作骨骼与角色同一套，不需要移植。
- 每一刀和它的收招在这里合成一个动作（NLA 烘焙），名字对上 red_panda_temp_clips 的约定（attack_1 等）。
- 打印每个攻击动作的“手速”曲线和自动算出的切点（蓄力结束、挥砍结束，秒），填进 Godot 的 hero_clips.tres。
- 同时保存 hero_katana.blend 方便在 Blender 里检查。
"""
import bpy, bmesh, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import katana_moves
from mathutils import Matrix, Vector

Q = "E:/ShopGame/source_assets/quaternius/"
CHAR = Q + "ubc/Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf"
LIBS = [Q + "ual1/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb",
        Q + "ual2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"]
OUT_GLB = "E:/ShopGame/game/assets/combat_real/hero_katana.glb"
OUT_BLEND = Q + "hero_katana.blend"

# 游戏动作名 → 由哪些源动作首尾相接（通用动作取自动作库；待机和攻击由 katana_moves.py 自己设计）
CLIPS = {
    "run": ["Jog_Fwd_Loop"],
    "hit": ["Hit_Chest"],
    "death": ["Death01"],
    "dodge": ["Roll"],
    "charge": ["Sword_Block"],
}


def build_katana():
    """太刀：刀身沿 +X（握把中心在原点），刃朝 +Z；略带弧度。"""
    mesh = bpy.data.meshes.new("Katana")
    bm = bmesh.new()
    mats = []

    def material(name, color, metallic, roughness, glow=0.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = (*color, 1.0)
        p.inputs["Metallic"].default_value = metallic
        p.inputs["Roughness"].default_value = roughness
        if glow > 0.0:
            # 俯视角下刀要一眼看得见：刀身带一点自发光，阴影里也是亮的
            p.inputs["Emission Color"].default_value = (*color, 1.0)
            p.inputs["Emission Strength"].default_value = glow
        mats.append(m)
        return len(mats) - 1

    steel = material("Katana_Steel", (0.9, 0.93, 0.98), 0.3, 0.25, glow=0.45)
    dark = material("Katana_Tsuba", (0.12, 0.11, 0.1), 0.5, 0.45)
    wrap = material("Katana_Wrap", (0.06, 0.07, 0.12), 0.0, 0.8)
    gold = material("Katana_Habaki", (0.85, 0.62, 0.25), 1.0, 0.3)

    def box(cx, sx, sy, sz, mat):
        r = bmesh.ops.create_cube(bm, size=1.0)
        verts = r["verts"]
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=verts)
        bmesh.ops.translate(bm, vec=(cx, 0, 0), verts=verts)
        for f in {f for v in verts for f in v.link_faces}: f.material_index = mat

    # 柄（握把中心在原点）、柄头、鍔、鎺
    box(0.0, 0.27, 0.03, 0.026, wrap)
    box(-0.142, 0.014, 0.034, 0.03, dark)
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.045, radius2=0.045, depth=0.008)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=r["verts"])
    bmesh.ops.translate(bm, vec=(0.142, 0, 0), verts=r["verts"])
    for f in {f for v in r["verts"] for f in v.link_faces}: f.material_index = dark
    box(0.162, 0.03, 0.012, 0.032, gold)
    # 刀身：截面是刀背厚、刃口薄的楔形；沿长度略向刀背弯（反り）
    # 比真实太刀略宽略长：俯视角下要看得清刀路
    length, start, segments = 1.05, 0.177, 24
    rings = []
    for i in range(segments + 1):
        t = i / segments
        x = start + length * t
        sori = 0.028 * math.sin(math.pi * t * 0.9)
        width = 0.05 * (1.0 - 0.25 * t) if t < 0.93 else 0.05 * 0.75 * (1.0 - (t - 0.93) / 0.07)
        thick = 0.012 * (1.0 - 0.4 * t)
        spine_z = -sori - width * 0.5
        edge_z = spine_z + width
        ring = [bm.verts.new((x, -thick / 2, spine_z)), bm.verts.new((x, thick / 2, spine_z)), bm.verts.new((x, 0.0, edge_z))]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(3):
            f = bm.faces.new((a[j], a[(j + 1) % 3], b[(j + 1) % 3], b[j]))
            f.material_index = steel
    f = bm.faces.new(rings[0][::-1]); f.material_index = steel
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for m in mats: mesh.materials.append(m)
    obj = bpy.data.objects.new("Katana", mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons: poly.use_smooth = False
    return obj


def bake_clip(rig, name, sources):
    """把若干源动作首尾相接放进 NLA，烘焙成一个新动作。"""
    rig.animation_data.action = None
    for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
    track = rig.animation_data.nla_tracks.new()
    frame = 0
    for src in sources:
        action = bpy.data.actions[src]
        strip = track.strips.new(src, frame, action)
        strip.extrapolation = "HOLD_FORWARD"
        frame = int(strip.frame_end) + 1
    if len(sources) == 1:
        rig.animation_data.nla_tracks.remove(track)
        copy = bpy.data.actions[sources[0]].copy()
        copy.name = name
        return copy
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=0, frame_end=frame, only_selected=False, visual_keying=True,
                     clear_constraints=False, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = rig.animation_data.action
    baked.name = name
    rig.animation_data.action = None
    rig.animation_data.nla_tracks.remove(track)
    return baked


def hand_speed(rig, action, fps):
    """右手（刀）在每帧的移动速度，用来找挥砍最快的那一段。"""
    scene = bpy.context.scene
    rig.animation_data.action = action
    if action.slots: rig.animation_data.action_slot = action.slots[0]
    start, end = int(action.frame_range[0]), int(action.frame_range[1])
    tips = []
    for f in range(start, end + 1):
        scene.frame_set(f)
        tip = rig.matrix_world @ rig.pose.bones["hand_r"].matrix @ Vector((0.8, 0, 0))
        tips.append(tip)
    speeds = [0.0] + [(b - a).length * fps for a, b in zip(tips, tips[1:])]
    rig.animation_data.action = None
    return start, speeds


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = katana_moves.FPS
    bpy.ops.import_scene.gltf(filepath=CHAR)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig.name = "Hero"
    bpy.context.scene.render.fps = katana_moves.FPS
    rig.animation_data_create()
    for path in LIBS:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o, do_unlink=True)
    sources = {a.name for a in bpy.data.actions}
    for clip, parts in CLIPS.items():
        for part in parts: assert part in sources, part
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    made = {}
    for clip, parts in CLIPS.items():
        made[clip] = bake_clip(rig, clip, parts)
    # 只留游戏用的动作
    for action in list(bpy.data.actions):
        if action.name not in CLIPS: bpy.data.actions.remove(action)
    for action in bpy.data.actions: action.use_fake_user = True
    # 太刀与自己设计的待机/攻击动作
    katana = build_katana()
    authored = katana_moves.author(rig, katana)
    cast = authored["attack_1"][0].copy()
    cast.name = "cast"
    cast.use_fake_user = True
    for name, (action, cuts) in authored.items():
        if cuts: print("CUTS %s windup_end=%.4f active_end=%.4f length=%.4f" % (name, cuts[0] / fps, cuts[1] / fps, action.frame_range[1] / fps))
    keep = set(CLIPS) | set(authored) | {"cast"}
    for action in list(bpy.data.actions):
        if action.name not in keep: bpy.data.actions.remove(action)
    rig.animation_data.action = None
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_apply=False, export_yup=True)
    print("EXPORTED", OUT_GLB)


main()
