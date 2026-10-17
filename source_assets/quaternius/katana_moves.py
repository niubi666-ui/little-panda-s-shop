"""太刀动作（自己设计，参考《只狼》《燕云十六声》的太刀架势）。被 build_hero.py 调用。

做法：控制器驱动
- 刀（CTL_blade，空物体）：位置 = 握把中心，X 轴 = 刀尖方向，Z 轴 = 刃口方向。太刀模型直接挂在它下面。
- 双手：IK（小臂两节）把手腕拉到刀柄上，再复制刀柄上手部目标的朝向 → 双手握刀，刀不会从手里“漂”出去。
- 双脚：IK 踩在脚部目标上；骨盆位移/扭转、胸口扭转、头始终看向前方。
- 关键帧之间默认平滑；挥砍那几帧用线性插值，刀走中间关键帧定出的弧线。
- 最后烘焙成普通骨骼动画（每招一个动作），去掉控制器，太刀改挂到右手骨骼上导出。

坐标：角色站在原点，面朝 -Y；角色右侧 = -X，左侧 = +X，上 = +Z；30 帧/秒。
每招的“蓄力结束 / 挥砍结束”帧见 MOVES 里的 cuts，换算成秒后要与 game/data/combat/prototype.json 的技能时长一致。
"""
import bpy, math
from mathutils import Matrix, Vector, Quaternion

FPS = 30
GRIP_R = 0.07     # 右手握在刀柄靠鍔的一端（刀柄中心为 0，沿刀身方向为正）
GRIP_L = -0.075   # 左手靠柄头
PALM = 0.075      # 手腕到掌心（沿手指方向）
PALM_DEPTH = 0.025


def v(*a): return Vector(a)


def nrm(a): return Vector(a).normalized()


def edge(blade, hint):
    """刃口方向：hint 去掉沿刀身的分量（必须与刀身垂直）。"""
    b = Vector(blade).normalized(); h = Vector(hint)
    return (h - h.dot(b) * b).normalized()


# ---------------------------------------------------------------- 姿势
# pelvis: (dx, dy, dz, yaw, pitch, roll) 相对静止姿势的骨盆偏移（米）与世界旋转（度；yaw 正 = 向左转，pitch 正 = 前倾）
# chest: (yaw, pitch) 胸口在骨盆之上额外扭转；feet: {"l": (x, y, z_lift, yaw), "r": ...}
# grip: 握把中心；blade: 刀尖方向；edge: 刃口朝向的提示；left: 左手是否握刀（1/0）
def pose(pelvis, chest, feet, grip, blade, edge_hint, left=1.0):
    b = nrm(blade)
    return {"pelvis": pelvis, "chest": chest, "feet": feet, "grip": v(*grip), "blade": b, "edge": edge(b, edge_hint), "left": left}


FEET_STANCE = {"r": (-0.12, -0.18, 0.0, -5.0), "l": (0.17, 0.24, 0.0, 28.0)}
STANCE = pose((0, 0.03, -0.07, 14, 8, 0), (-12, 4), FEET_STANCE,
              (-0.02, -0.36, 1.08), (0.05, -0.75, 0.6), (0, -0.3, -1))
STANCE_BREATH = pose((0, 0.03, -0.085, 14, 9, 0), (-12, 5), FEET_STANCE,
                     (-0.02, -0.35, 1.065), (0.05, -0.77, 0.58), (0, -0.3, -1))

# 一：袈裟斩（右肩上方 → 斜劈到左下）
L1_COIL = pose((0, 0.06, -0.06, -8, -3, 0), (-38, -4), FEET_STANCE,
               (-0.28, 0.02, 1.55), (0.25, 0.55, 0.8), (0.5, -0.6, -0.6))
L1_TOP = pose((0, 0.07, -0.06, -10, -4, 0), (-44, -5), FEET_STANCE,
              (-0.30, 0.05, 1.58), (0.25, 0.6, 0.78), (0.5, -0.6, -0.6))
FEET_L1 = {"r": (-0.13, -0.40, 0.0, -5.0), "l": (0.17, 0.14, 0.0, 28.0)}
L1_MID1 = pose((0, -0.08, -0.10, 0, 10, 0), (-10, 4), {"r": (-0.13, -0.30, 0.06, -5.0), "l": (0.17, 0.2, 0.0, 28.0)},
               (-0.16, -0.38, 1.38), (-0.35, -0.65, 0.65), (0.55, -0.4, -0.7))
L1_MID2 = pose((0, -0.14, -0.13, 10, 16, 0), (15, 8), FEET_L1,
               (0.05, -0.50, 1.05), (0.15, -0.95, -0.1), (0.7, 0.1, -0.7))
L1_END = pose((0, -0.16, -0.15, 15, 20, 0), (34, 8), FEET_L1,
              (0.28, -0.32, 0.80), (0.75, -0.25, -0.6), (0.4, 0.7, -0.2))
L1_HOLD = pose((0, -0.15, -0.15, 16, 20, 0), (38, 8), FEET_L1,
               (0.30, -0.28, 0.78), (0.78, -0.2, -0.6), (0.4, 0.7, -0.2))

# 二：逆袈裟（左下 → 反手斜撩到右上）
L2_COIL = pose((0, -0.14, -0.14, 20, 18, 0), (45, 8), FEET_L1,
               (0.32, -0.18, 0.82), (0.8, 0.1, -0.55), (-0.3, -0.6, 0.7))
FEET_L2 = {"r": (-0.14, -0.40, 0.0, -10.0), "l": (0.16, -0.02, 0.0, 20.0)}
L2_MID1 = pose((0, -0.16, -0.12, 5, 12, 0), (15, 6), {"r": (-0.14, -0.40, 0.0, -8.0), "l": (0.16, 0.06, 0.05, 24.0)},
               (0.10, -0.48, 1.05), (0.25, -0.9, -0.3), (-0.7, -0.2, 0.7))
L2_MID2 = pose((0, -0.18, -0.10, -10, 8, 0), (-15, 4), FEET_L2,
               (-0.15, -0.45, 1.32), (-0.4, -0.8, 0.4), (-0.6, 0.3, 0.7))
L2_END = pose((0, -0.18, -0.09, -15, 4, 0), (-35, 2), FEET_L2,
              (-0.32, -0.25, 1.55), (-0.6, 0.15, 0.8), (-0.3, 0.6, 0.6))
L2_HOLD = pose((0, -0.17, -0.09, -16, 4, 0), (-38, 2), FEET_L2,
               (-0.33, -0.22, 1.57), (-0.6, 0.2, 0.8), (-0.3, 0.6, 0.6))

# 三：唐竹割（高举过头 → 大步踏前竖劈，劈到底停住）
FEET_L3_UP = {"r": (-0.13, -0.30, 0.0, -5.0), "l": (0.16, 0.10, 0.0, 22.0)}
L3_RAISE = pose((0, 0.06, -0.03, 8, -6, 0), (0, -6), FEET_L3_UP,
                (0.0, 0.08, 1.85), (0.0, 0.75, 0.65), (0, -0.3, 1))
L3_TOP = pose((0, 0.10, -0.01, 10, -9, 0), (0, -8), FEET_L3_UP,
              (0.0, 0.13, 1.90), (0.0, 0.8, 0.6), (0, -0.3, 1))
FEET_L3 = {"r": (-0.13, -0.68, 0.0, -5.0), "l": (0.16, 0.0, 0.0, 22.0)}
L3_MID1 = pose((0, -0.12, -0.08, 6, 4, 0), (0, 2), {"r": (-0.13, -0.45, 0.10, -5.0), "l": (0.16, 0.08, 0.0, 22.0)},
               (0.0, -0.25, 1.75), (0.0, -0.5, 0.85), (0, -1, 0.3))
L3_MID2 = pose((0, -0.30, -0.18, 4, 16, 0), (0, 8), {"r": (-0.13, -0.62, 0.04, -5.0), "l": (0.16, 0.02, 0.0, 22.0)},
               (0.0, -0.55, 1.25), (0.0, -0.95, 0.15), (0, -0.2, -1))
L3_END = pose((0, -0.36, -0.25, 3, 20, 0), (0, 8), FEET_L3,
              (0.0, -0.78, 0.98), (0.0, -0.85, -0.5), (0, 0.5, -0.85))
L3_HOLD = pose((0, -0.36, -0.26, 3, 21, 0), (0, 8), FEET_L3,
               (0.0, -0.77, 0.96), (0.0, -0.83, -0.53), (0, 0.5, -0.85))

# R：居合·横一文字（压低、刀收在左腰 → 单手横扫，左手留在腰间）
FEET_IAI = {"r": (-0.13, -0.15, 0.0, -10.0), "l": (0.19, 0.28, 0.0, 30.0)}
IAI_COIL = pose((0, 0.05, -0.20, 35, 15, 0), (30, 6), FEET_IAI,
                (0.28, 0.02, 0.92), (0.15, 0.95, -0.2), (0, 0, 1))
IAI_TOP = pose((0, 0.07, -0.25, 38, 18, 0), (40, 8), FEET_IAI,
               (0.29, 0.04, 0.88), (0.15, 0.95, -0.2), (0, 0, 1))
FEET_IAI_STRIKE = {"r": (-0.15, -0.62, 0.0, -15.0), "l": (0.19, 0.22, 0.0, 30.0)}
IAI_MID1 = pose((0, -0.15, -0.22, 20, 14, 0), (15, 5), {"r": (-0.15, -0.45, 0.08, -12.0), "l": (0.19, 0.26, 0.0, 30.0)},
                (0.18, -0.42, 1.02), (0.55, -0.85, 0.05), (-0.9, -0.3, 0), left=0.0)
IAI_MID2 = pose((0, -0.25, -0.22, 0, 12, 0), (-15, 4), FEET_IAI_STRIKE,
                (-0.15, -0.58, 1.08), (-0.3, -0.95, 0.05), (-0.9, 0.3, 0), left=0.0)
IAI_END = pose((0, -0.30, -0.22, -20, 12, 0), (-40, 4), FEET_IAI_STRIKE,
               (-0.55, -0.25, 1.12), (-0.9, 0.35, 0.1), (0, 1, 0), left=0.0)
IAI_HOLD = pose((0, -0.30, -0.23, -21, 12, 0), (-43, 4), FEET_IAI_STRIKE,
                (-0.56, -0.22, 1.12), (-0.9, 0.4, 0.1), (0, 1, 0), left=0.0)

# 每招：[(帧, 姿势, 这一段到下一帧是否线性)]；cuts = (蓄力结束帧, 挥砍结束帧)
MOVES = {
    "idle": {"keys": [(0, STANCE, False), (18, STANCE_BREATH, False), (36, STANCE, False)], "cuts": None},
    "attack_1": {"keys": [(0, STANCE, False), (4, L1_COIL, False), (6, L1_TOP, True), (7, L1_MID1, True), (8, L1_MID2, True),
                          (9, L1_END, False), (13, L1_HOLD, False), (20, STANCE, False)], "cuts": (6, 9)},
    "attack_2": {"keys": [(0, L1_HOLD, False), (3, L2_COIL, False), (5, L2_COIL, True), (6, L2_MID1, True), (7, L2_MID2, True),
                          (8, L2_END, False), (12, L2_HOLD, False), (19, STANCE, False)], "cuts": (5, 8)},
    "attack_3": {"keys": [(0, L2_HOLD, False), (6, L3_RAISE, False), (9, L3_TOP, True), (10, L3_MID1, True), (11, L3_MID2, True),
                          (12, L3_END, False), (18, L3_HOLD, False), (29, STANCE, False)], "cuts": (9, 12)},
    "heavy": {"keys": [(0, STANCE, False), (8, IAI_COIL, False), (14, IAI_TOP, True), (15, IAI_MID1, True), (16, IAI_MID2, True),
                       (18, IAI_END, False), (24, IAI_HOLD, False), (32, STANCE, False)], "cuts": (14, 18)},
}


# ---------------------------------------------------------------- 控制器
class Rig:
    def __init__(self, rig, katana):
        self.rig = rig
        self.katana = katana
        bones = rig.data.bones
        self.pelvis_head = bones["pelvis"].head_local.copy()
        self.ankle = {s: bones["calf_" + s].tail_local.copy() for s in "lr"}
        self.blade = self._empty("CTL_blade")
        self.blade.rotation_mode = "QUATERNION"
        katana.parent = self.blade
        katana.matrix_parent_inverse = Matrix.Identity(4)
        katana.matrix_basis = Matrix.Identity(4)
        # 手部目标：刀柄坐标系里固定，手骨 Z = 刀尖方向（拇指一侧），Y = 刃口一侧（手指方向），X = Y × Z
        hand_rot = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))  # 列：X_h=(0,1,0) Y_h=(0,0,1) Z_h=(1,0,0)
        self.hand = {}
        self.hand_local = {}
        for side, grip, palm_sign in (("r", GRIP_R, -1.0), ("l", GRIP_L, 1.0)):
            e = self._empty("IK_hand_" + side)
            e.rotation_mode = "QUATERNION"
            x_h, y_h = hand_rot.col[0], hand_rot.col[1]
            wrist = Vector((grip, 0, 0)) - y_h * PALM - x_h * palm_sign * PALM_DEPTH
            self.hand_local[side] = Matrix.Translation(wrist) @ hand_rot.to_4x4()
            if side == "r":
                e.parent = self.blade
                e.matrix_basis = self.hand_local[side]
            self.hand[side] = e
        self.pole_arm = {s: self._empty("POLE_arm_" + s) for s in "lr"}
        self.foot = {s: self._empty("IK_foot_" + s) for s in "lr"}
        self.pole_leg = {s: self._empty("POLE_leg_" + s) for s in "lr"}
        for e in list(self.foot.values()): e.rotation_mode = "QUATERNION"
        self._constraints()

    def _empty(self, name):
        e = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(e)
        e.empty_display_size = 0.05
        return e

    def _constraints(self):
        pb = self.rig.pose.bones
        self.ik = {}
        for s in "lr":
            ik = pb["lowerarm_" + s].constraints.new("IK")
            ik.target = self.hand[s]; ik.pole_target = self.pole_arm[s]; ik.chain_count = 2; ik.use_tail = True
            self.ik["arm_" + s] = ik
            cr = pb["hand_" + s].constraints.new("COPY_ROTATION"); cr.target = self.hand[s]
            self.ik["hand_" + s] = cr
            leg = pb["calf_" + s].constraints.new("IK")
            leg.target = self.foot[s]; leg.pole_target = self.pole_leg[s]; leg.chain_count = 2; leg.use_tail = True
            self.ik["leg_" + s] = leg
            fr = pb["foot_" + s].constraints.new("COPY_ROTATION"); fr.target = self.foot[s]
        # 手指握拳（绕手指局部 X 正向弯曲即朝掌心）
        for b in pb:
            n = b.name
            if any(n.startswith(f) for f in ("index_", "middle_", "ring_", "pinky_")) and "leaf" not in n:
                b.rotation_mode = "XYZ"; b.rotation_euler = (math.radians(75 if n[-4:-2] != "01" else 60), 0, 0)
            if n.startswith("thumb_0") and "leaf" not in n:
                b.rotation_mode = "XYZ"; b.rotation_euler = (math.radians(25), 0, 0)

    def pick_pole_angles(self):
        """自动选 IK 极向角：让肘、膝最靠近各自的极向目标。"""
        layer = bpy.context.view_layer
        for key, mid in (("arm_r", "lowerarm_r"), ("arm_l", "lowerarm_l"), ("leg_r", "calf_r"), ("leg_l", "calf_l")):
            best = None
            for deg in range(-180, 180, 15):
                self.ik[key].pole_angle = math.radians(deg)
                layer.update()
                joint = self.rig.matrix_world @ self.rig.pose.bones[mid].head
                d = (joint - self.ik[key].pole_target.matrix_world.translation).length
                if best is None or d < best[0]: best = (d, deg)
            self.ik[key].pole_angle = math.radians(best[1])
            print("POLE", key, best[1])

    # -------------------------------------------------------- 摆姿势
    def apply(self, p):
        layer = bpy.context.view_layer
        pb = self.rig.pose.bones
        dx, dy, dz, yaw, pitch, roll = p["pelvis"]
        r_pelvis = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ Matrix.Rotation(math.radians(roll), 3, "Y")
        self._world(pb["pelvis"], r_pelvis, self.pelvis_head + Vector((dx, dy, dz)))
        cy, cp = p["chest"]
        for name, f in (("spine_01", 0.35), ("spine_02", 0.7), ("spine_03", 1.0)):
            r = r_pelvis @ Matrix.Rotation(math.radians(cy * f), 3, "Z") @ Matrix.Rotation(math.radians(cp * f), 3, "X")
            self._world(pb[name], r)
        self._world(pb["neck_01"], Matrix.Rotation(math.radians(4), 3, "X"))
        self._world(pb["Head"], Matrix.Rotation(math.radians(6), 3, "X"))
        # 刀
        b, e = p["blade"], p["edge"]
        rot = Matrix((b, e.cross(b), e)).transposed()
        self.blade.matrix_world = Matrix.Translation(p["grip"]) @ rot.to_4x4()
        blade_world = Matrix.Translation(p["grip"]) @ rot.to_4x4()
        if p["left"] >= 0.5:
            self.hand["l"].matrix_world = blade_world @ self.hand_local["l"]
        else:
            # 左手按在左腰：手指朝前下，掌心朝身体
            # 列：X（掌心朝身体内侧）、Y（手指朝前下）、Z = X × Y
            r_hip = r_pelvis @ Matrix(((-1, 0, 0), (0, -0.5, -0.85), (0, -0.85, 0.5))).transposed()
            hip = self.pelvis_head + Vector((dx, dy, dz)) + r_pelvis @ Vector((0.21, -0.05, -0.02))
            self.hand["l"].matrix_world = Matrix.Translation(hip) @ r_hip.to_4x4()
        # 脚与极向目标
        for s in "lr":
            x, y, lift, fyaw = p["feet"][s]
            rest = self.rig.data.bones["foot_" + s].matrix_local.to_3x3()
            self.foot[s].matrix_world = Matrix.Translation((x, y, self.ankle[s].z + lift)) @ (Matrix.Rotation(math.radians(fyaw), 3, "Z") @ rest).to_4x4()
            side = -1.0 if s == "r" else 1.0
            self.pole_leg[s].location = (x + side * 0.15, y - 0.8, 0.55)
            spine = r_pelvis @ Matrix.Rotation(math.radians(cy), 3, "Z")
            self.pole_arm[s].location = Vector((dx, dy, 0)) + self.pelvis_head + spine @ Vector((side * 0.55, 0.45, 0.15))
        layer.update()

    def _world(self, b, rot, head=None):
        """把骨骼的世界朝向设成 rot × 静止朝向（head 给出时同时设位置）。"""
        bpy.context.view_layer.update()
        rest = b.bone.matrix_local
        if head is None: head = b.head.copy()
        b.matrix = Matrix.Translation(head) @ (rot @ rest.to_3x3()).to_4x4()

    def key(self, frame, linear):
        pb = self.rig.pose.bones
        items = [(pb[n], ("rotation_quaternion",)) for n in ("spine_01", "spine_02", "spine_03", "neck_01", "Head")]
        items.append((pb["pelvis"], ("rotation_quaternion", "location")))
        for o in [self.blade, self.hand["l"]] + list(self.foot.values()):
            items.append((o, ("location", "rotation_quaternion")))
        for o in list(self.pole_arm.values()) + list(self.pole_leg.values()):
            items.append((o, ("location",)))
        for target, paths in items:
            for path in paths: target.keyframe_insert(path, frame=frame)
        return linear


def set_interpolation(objects, linear_frames):
    """挥砍段（linear_frames 里的帧开始的那一段）改成线性插值；其余用平滑。"""
    for o in objects:
        ad = o.animation_data
        if ad is None or ad.action is None: continue
        for fc in iter_fcurves(ad):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR" if int(round(kp.co.x)) in linear_frames else "BEZIER"
                kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"


def iter_fcurves(ad):
    action = ad.action
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])):
        yield from action.fcurves
        return
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def author(rig, katana):
    """返回 {动作名: (Action, cuts)}；调用前角色不能带动作。"""
    scene = bpy.context.scene
    ctl = Rig(rig, katana)
    ctl.apply(STANCE)
    ctl.pick_pole_angles()
    result = {}
    for name, move in MOVES.items():
        objects = [rig, ctl.blade, ctl.hand["l"]] + list(ctl.foot.values()) + list(ctl.pole_arm.values()) + list(ctl.pole_leg.values())
        for o in objects:
            o.animation_data_clear()
        linear = set()
        for frame, p, is_linear in move["keys"]:
            ctl.apply(p)
            ctl.key(frame, is_linear)
            if is_linear: linear.add(frame)
        set_interpolation(objects, linear)
        end = move["keys"][-1][0]
        scene.frame_start, scene.frame_end = 0, end
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.pose.select_all(action="SELECT")
        bpy.ops.nla.bake(frame_start=0, frame_end=end, only_selected=False, visual_keying=True,
                         clear_constraints=False, use_current_action=False, bake_types={"POSE"})
        bpy.ops.object.mode_set(mode="OBJECT")
        baked = rig.animation_data.action
        baked.name = name
        baked.use_fake_user = True
        rig.animation_data.action = None
        result[name] = (baked, move["cuts"])
        print("AUTHORED", name, "frames", end, "cuts", move["cuts"])
    # 记下握刀关系：在某一帧把太刀从控制器改挂到右手骨骼
    rig.animation_data.action = result["idle"][0]
    if result["idle"][0].slots: rig.animation_data.action_slot = result["idle"][0].slots[0]
    for o in [ctl.blade, ctl.hand["l"]] + list(ctl.foot.values()) + list(ctl.pole_arm.values()) + list(ctl.pole_leg.values()):
        o.animation_data_clear()
    ctl.apply(STANCE)
    scene.frame_set(0)
    bpy.context.view_layer.update()
    world = katana.matrix_world.copy()
    for b in rig.pose.bones:
        for c in list(b.constraints):
            if c.type in ("IK", "COPY_ROTATION"): b.constraints.remove(c)
    bpy.context.view_layer.update()
    hand = rig.matrix_world @ rig.pose.bones["hand_r"].matrix
    katana.parent = rig
    katana.parent_type = "BONE"
    katana.parent_bone = "hand_r"
    # 骨骼父级以骨尾为原点
    tail = hand @ Matrix.Translation((0, rig.data.bones["hand_r"].length, 0))
    katana.matrix_parent_inverse = Matrix.Identity(4)
    katana.matrix_basis = tail.inverted() @ world
    for e in [ctl.blade] + list(ctl.hand.values()) + list(ctl.foot.values()) + list(ctl.pole_arm.values()) + list(ctl.pole_leg.values()):
        bpy.data.objects.remove(e, do_unlink=True)
    rig.animation_data.action = None
    return result
