"""Temporary jackal-clan enemies on the shared humanoid rig: crossbow, brute, charger, banner.

Run:  blender --background --factory-startup --python build_enemies.py -- <out_dir> [<blend_dir>] [--only=name] [--report]

Each enemy is one GLB named <name>_temp.glb with the clips listed in its builder. Colours keep
the prototype's coding (crossbow = teal, brute = iron, charger = ochre, banner = crimson) so
the roles stay readable from the top-down camera.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import sg_char as sc
import sg_lib as sg
from sg_char import P

FUR = sg.srgb("#9d8a70")
FUR_LIGHT = sg.srgb("#d3c4a7")
FUR_DARK = sg.srgb("#3a2f2b")
BONE = sg.srgb("#ece4cf")
INK = sg.srgb("#16110f")
EYE = sg.srgb("#ffb347")
LEATHER = sg.srgb("#59402f")
LEATHER_LIGHT = sg.srgb("#8c6a48")
WOOD = sg.srgb("#6b4a30")
WOOD_LIGHT = sg.srgb("#a2764c")
IRON = sg.srgb("#4b4f5c")
IRON_LIGHT = sg.srgb("#9aa3b5")
STEEL = sg.srgb("#c5cedb")
CRIMSON = sg.srgb("#9c2734")
CRIMSON_LIGHT = sg.srgb("#d8475a")
TEAL = sg.srgb("#22505c")
TEAL_LIGHT = sg.srgb("#3f8a92")
OCHRE = sg.srgb("#8a5a24")
OCHRE_LIGHT = sg.srgb("#d39a3e")
PLATE = sg.srgb("#33363f")
PLATE_LIGHT = sg.srgb("#6f7789")
PLUM = sg.srgb("#5c2140")
PLUM_LIGHT = sg.srgb("#9a3a5c")

MEDIUM = dict(hip_z=0.76, neck_z=1.28, head_len=0.3, shoulder_x=0.23, shoulder_z=1.2, arm_out=0.07,
              upper_arm=0.29, forearm=0.27, hand=0.1, leg_x=0.13, thigh=0.37, shin=0.33, foot=0.2)
HEAVY = dict(hip_z=0.84, neck_z=1.52, head_len=0.3, shoulder_x=0.4, shoulder_z=1.44, arm_out=0.1,
             upper_arm=0.36, forearm=0.34, hand=0.13, leg_x=0.2, thigh=0.4, shin=0.37, foot=0.26)
SMOOTH = dict(smooth=True, jitter=0.0)


def make_rig(name, proportions):
    bones = sc.humanoid_bones(proportions)
    table = {bone[0]: (Vector(bone[1]), Vector(bone[2])) for bone in bones}
    elbow, wrist = table["forearm.R"]
    direction = (wrist - elbow).normalized()
    grip = table["hand.R"][0] + direction * 0.05
    bones.append(("weapon", grip, grip + direction * 0.3, "hand.R"))
    rig = sc.Rig(name, bones)
    rig.report_bones = ["weapon"] if getattr(sc, "REPORT", False) else []
    return rig, grip, direction


def body(part, rig, cloth, cloth_light, limb=0.07, torso=0.24, depth=0.8, fur=FUR, fur_light=FUR_LIGHT):
    """Shared jackal body: torso, limbs, head with snout and tall ears."""
    H, T = rig.heads, rig.tails
    hip = H["hips"]
    chest = H["spine"].lerp(T["spine"], 0.55)
    part.ball((torso * 0.92, torso * depth * 0.9, 0.2), (0, 0, hip.z + 0.03), cloth, top=cloth_light, bone="hips", **SMOOTH)
    part.ball((torso, torso * depth, (T["spine"].z - H["spine"].z) * 0.72), chest, cloth, top=cloth_light, bone="spine", **SMOOTH)
    part.ball((0.19, 0.16, 0.26), (0, 0.2, hip.z - 0.02), fur, top=fur_light, bone="hips", **SMOOTH)          # bushy tail
    part.ball((0.13, 0.11, 0.17), (0, 0.27, hip.z - 0.2), FUR_DARK, bone="hips", **SMOOTH)
    head = H["head"] + Vector((0, -0.02, 0.17))
    part.limb(T["spine"], H["head"] + Vector((0, 0, 0.06)), limb * 1.3, limb * 1.2, fur, bone="spine", **SMOOTH)
    part.ball((0.17, 0.185, 0.165), head, fur, top=fur_light, sub=3, bone="head", **SMOOTH)
    part.limb(head + Vector((0, -0.1, -0.03)), head + Vector((0, -0.34, -0.07)), 0.095, 0.055, fur_light, top=fur_light, bone="head", **SMOOTH)
    part.ball((0.045, 0.04, 0.038), head + Vector((0, -0.36, -0.06)), INK, bone="head", **SMOOTH)
    for sx in (-1, 1):
        part.cone(0.075, 0.26, head + Vector((sx * 0.105, 0.03, 0.1)), fur, rot=(-0.12, sx * 0.22, 0), segs=6, top=FUR_DARK, bone="head", **SMOOTH)
        part.ball((0.03, 0.02, 0.026), head + Vector((sx * 0.085, -0.155, 0.035)), EYE, bone="head", **SMOOTH)
        side = ".L" if sx > 0 else ".R"
        part.ball((limb * 1.25,) * 3, H["upper_arm" + side], cloth_light, bone="upper_arm" + side, **SMOOTH)
        part.limb(H["upper_arm" + side], T["upper_arm" + side], limb * 1.05, limb * 0.95, cloth, top=cloth_light, bone="upper_arm" + side, **SMOOTH)
        part.ball((limb,) * 3, H["forearm" + side], fur, bone="forearm" + side, **SMOOTH)
        part.limb(H["forearm" + side], T["forearm" + side], limb * 0.95, limb * 0.85, fur, top=fur_light, bone="forearm" + side, **SMOOTH)
        part.ball((limb * 1.15,) * 3, H["hand" + side].lerp(T["hand" + side], 0.5), FUR_DARK, bone="hand" + side, **SMOOTH)
        part.limb(H["thigh" + side], T["thigh" + side], limb * 1.45, limb * 1.15, cloth, top=cloth_light, bone="thigh" + side, **SMOOTH)
        part.ball((limb * 1.15,) * 3, H["shin" + side], cloth, bone="shin" + side, **SMOOTH)
        part.limb(H["shin" + side], T["shin" + side], limb * 1.1, limb * 0.9, fur, top=fur_light, bone="shin" + side, **SMOOTH)
        ankle = H["foot" + side]
        part.ball((limb * 1.2, limb * 2.1, limb * 0.85), (ankle.x, ankle.y - limb * 0.9, limb * 0.8), FUR_DARK, bone="foot" + side, **SMOOTH)
    return head


# ------------------------------------------------------------------------------------------
# Shared clips
# ------------------------------------------------------------------------------------------
def clip_idle(rig, stand, frames=110, extra=None):
    breathe = P(stand, extra or {}, _loc={"hips": (0, 0, stand.get("_loc", {}).get("hips", (0, 0, 0))[2] - 0.02)})
    spine = stand.get("spine", (0, 0, 0))
    breathe["spine"] = (spine[0] + 4, spine[1], spine[2])
    rig.clip("idle", [(0, stand), (frames // 2, breathe), (frames, stand)])


def clip_move(rig, stand, name="walk", frames=36, stride=1.0, lean=8.0, bounce=0.03, swing=None):
    """swing: {bone: degrees} for free arms; weapon arms stay in the stand pose."""
    base_z = stand.get("_loc", {}).get("hips", (0, 0, 0))[2]
    sh, ss, sd = stand.get("hips", (0, 0, 0)), stand.get("spine", (0, 0, 0)), stand.get("head", (0, 0, 0))
    def contact(lead):
        other = ".R" if lead == ".L" else ".L"
        sign = 1 if lead == ".L" else -1
        pose = P(stand, _loc={"hips": (0, 0, base_z - bounce)},
                 hips=(sh[0] + lean * 0.6, sh[1], sh[2] + 6 * sign), spine=(ss[0] + lean, ss[1], ss[2] - 10 * sign), head=(sd[0] - lean * 0.8, sd[1], sd[2] + 4 * sign),
                 **{"thigh" + lead: (-38 * stride, 0, 0), "shin" + lead: (14, 0, 0), "foot" + lead: (-10, 0, 0),
                    "thigh" + other: (30 * stride, 0, 0), "shin" + other: (44 * stride, 0, 0), "foot" + other: (22, 0, 0)})
        for bone, degrees in (swing or {}).items():
            rest = stand.get(bone, (0, 0, 0))
            direction = sign if bone.endswith(".L") else -sign
            pose[bone] = (rest[0] + degrees * direction, rest[1], rest[2])
        return pose
    def passing(support):
        other = ".R" if support == ".L" else ".L"
        return P(stand, _loc={"hips": (0, 0, base_z + bounce * 0.7)},
                 hips=(sh[0] + lean * 0.6, sh[1], sh[2]), spine=(ss[0] + lean, ss[1], ss[2]), head=(sd[0] - lean * 0.8, sd[1], sd[2]),
                 **{"thigh" + support: (5, 0, 0), "shin" + support: (8, 0, 0), "foot" + support: (-6, 0, 0),
                    "thigh" + other: (-18 * stride, 0, 0), "shin" + other: (72 * stride, 0, 0), "foot" + other: (10, 0, 0)})
    q = frames // 4
    rig.clip(name, [(0, contact(".L")), (q, passing(".L")), (2 * q, contact(".R")), (3 * q, passing(".R")), (4 * q, contact(".L"))])


def clip_hit(rig, stand, frames=14):
    spine = stand.get("spine", (0, 0, 0))
    recoil = P(stand, _loc={"hips": (0, 0.12, stand.get("_loc", {}).get("hips", (0, 0, 0))[2] - 0.05)},
               hips=(-14, 0, 0), spine=(spine[0] - 30, 0, 10), head=(-22, 0, -8),
               thigh_L=(-30, 0, 8), shin_L=(34, 0, 0), thigh_R=(-2, 0, -8), shin_R=(30, 0, 0))
    rig.clip("hit", [(0, stand), (3, recoil), (frames, stand)])


def clip_death(rig, stand, hip_z, frames=54):
    reel = P(stand, _loc={"hips": (0, 0.2, 0.03)}, hips=(-30, 0, 0), spine=(-32, 0, 8), head=(-26, 0, 0),
             thigh_L=(-30, -6, 0), shin_L=(36, 0, 0), thigh_R=(4, 6, 0), shin_R=(30, 0, 0))
    fall = P(stand, _loc={"hips": (0, 0.6, -hip_z * 0.55)}, hips=(-72, 0, 0), spine=(-10, 0, 0), head=(-14, 0, 0),
             thigh_L=(-52, -12, 0), shin_L=(50, 0, 0), thigh_R=(-30, 12, 0), shin_R=(30, 0, 0),
             upper_arm_L=(-60, -60, 0), forearm_L=(-20, 0, 0), upper_arm_R=(-40, 60, 0), forearm_R=(-20, 0, 0))
    lie = P(_loc={"hips": (0, 0.85, -(hip_z - 0.2))}, hips=(-90, 0, 0), spine=(2, 0, 0), head=(6, 0, 20),
            thigh_L=(-6, -14, 0), shin_L=(8, 0, 0), thigh_R=(-24, 14, 0), shin_R=(36, 0, 0),
            upper_arm_L=(-10, -70, 0), forearm_L=(-24, 0, 0), upper_arm_R=(-6, 62, 0), forearm_R=(-14, 0, 0), weapon=(10, 0, 20))
    bounce = P(lie, _loc={"hips": (0, 0.9, -(hip_z - 0.24))}, hips=(-85, 0, 0))
    rig.clip("death", [(0, stand), (6, reel), (20, fall), (27, lie), (32, bounce), (39, lie), (frames, lie)])


# ------------------------------------------------------------------------------------------
# Crossbow: ranged
# ------------------------------------------------------------------------------------------
def build_crossbow():
    rig, grip, d = make_rig("Crossbow", MEDIUM)
    part = sg.Part("CrossbowBody", "Character", seed=31)
    head = body(part, rig, TEAL, TEAL_LIGHT, limb=0.065, torso=0.22)
    # hood and short cape
    part.ball((0.21, 0.22, 0.2), head + Vector((0, 0.04, 0.02)), TEAL, top=TEAL_LIGHT, sub=3, bone="head", **SMOOTH)
    part.cone(0.12, 0.2, head + Vector((0, 0.14, 0.12)), TEAL, rot=(0.9, 0, 0), segs=8, bone="head", **SMOOTH)
    part.ball((0.27, 0.2, 0.12), rig.tails["spine"] + Vector((0, 0.03, -0.02)), TEAL, top=TEAL_LIGHT, bone="spine", **SMOOTH)
    part.box((0.36, 0.04, 0.42), rig.tails["spine"] + Vector((0, 0.19, -0.24)), TEAL, top=TEAL_LIGHT, bevel=0.015, taper=0.8, bone="spine", jitter=0.0)
    # quiver
    part.cyl(0.07, 0.06, 0.38, rig.tails["spine"] + Vector((-0.12, 0.2, -0.36)), LEATHER, top=LEATHER_LIGHT, rot=(0, 0.35, 0), segs=8, bone="spine", **SMOOTH)
    for i in range(3):
        part.ball((0.03, 0.03, 0.045), rig.tails["spine"] + Vector((-0.24 + i * 0.03, 0.2 + (i % 2) * 0.03, 0.0)), CRIMSON_LIGHT, bone="spine", **SMOOTH)
    # crossbow: stock along the forearm, bow limbs across it
    across = Vector((d.z, 0.0, -d.x))
    tip = grip + d * 0.62
    part.blade(grip - d * 0.2, tip, across, 0.07, 0.08, WOOD, top=WOOD_LIGHT, taper=0.8, bevel=0.01, bone="weapon", jitter=0.0)
    for sx in (-1, 1):
        part.limb(tip - d * 0.06, tip - d * 0.2 + across * sx * 0.42, 0.03, 0.018, IRON, top=IRON_LIGHT, segs=6, bone="weapon", jitter=0.0)
        part.limb(tip - d * 0.2 + across * sx * 0.42, grip + d * 0.14, 0.006, 0.006, BONE, segs=4, bone="weapon", jitter=0.0)
    part.limb(grip + d * 0.14, tip + d * 0.14, 0.014, 0.014, BONE, segs=5, bone="weapon", jitter=0.0)
    part.cone(0.03, 0.08, tip + d * 0.12, STEEL, rot=tuple(d.to_track_quat("Z", "Y").to_euler()), segs=6, bone="weapon", jitter=0.0)
    rig.bind(part.finish())

    stand = P(_loc={"hips": (0, 0, -0.03)}, hips=(4, 0, -14), spine=(8, 0, -10), head=(-8, 0, 22),
              thigh_L=(-16, 0, 10), shin_L=(18, 0, 0), thigh_R=(8, 0, -8), shin_R=(14, 0, 0), foot_R=(-18, 0, 0),
              upper_arm_R=(-28, 10, 26), forearm_R=(-46, 0, 0), weapon=(16, 0, 0),
              upper_arm_L=(-52, -8, -34), forearm_L=(-44, 0, 0))
    aimed = P(stand, _loc={"hips": (0, 0.02, -0.07)}, hips=(4, 0, -34), spine=(6, 0, -12), head=(-4, -8, 44),
              thigh_L=(-26, 0, 14), shin_L=(26, 0, 0), thigh_R=(10, 0, -10), shin_R=(22, 0, 0),
              upper_arm_R=(-72, 10, 72), forearm_R=(-28, 0, 0), weapon=(10, 0, 0),
              upper_arm_L=(-86, -4, 26), forearm_L=(-12, 0, 0))
    raising = P(aimed, _loc={"hips": (0, 0.0, -0.05)}, upper_arm_R=(-50, 10, 52), forearm_R=(-40, 0, 0), weapon=(4, 0, 0))
    recoil = P(aimed, _loc={"hips": (0, 0.07, -0.06)}, spine=(-4, 0, -14), head=(-12, -6, 44),
               upper_arm_R=(-78, 10, 72), forearm_R=(-30, 0, 0), weapon=(-2, 0, 0))
    clip_idle(rig, stand)
    clip_move(rig, stand, "walk", frames=32, stride=0.95, lean=10)
    rig.clip("aim", [(0, stand), (10, raising), (20, aimed), (27, P(aimed, _loc={"hips": (0, 0.03, -0.08)}))])
    rig.clip("aim_hold", [(0, aimed), (30, P(aimed, _loc={"hips": (0, 0.02, -0.08)}, weapon=(12, 0, 0))), (60, aimed)])
    rig.clip("shoot", [(0, aimed), (2, recoil), (9, stand)])
    clip_hit(rig, stand)
    clip_death(rig, stand, MEDIUM["hip_z"])
    return rig


# ------------------------------------------------------------------------------------------
# Brute: heavy melee
# ------------------------------------------------------------------------------------------
def build_brute():
    rig, grip, d = make_rig("Brute", HEAVY)
    part = sg.Part("BruteBody", "Character", seed=32)
    head = body(part, rig, PLATE, PLATE_LIGHT, limb=0.105, torso=0.4, depth=0.78, fur=sg.srgb("#7d6b58"), fur_light=sg.srgb("#b3a388"))
    H, T = rig.heads, rig.tails
    # armour: breastplate, pauldrons, horned helmet, crimson sash
    part.ball((0.43, 0.3, 0.3), H["spine"].lerp(T["spine"], 0.62) + Vector((0, -0.03, 0)), PLATE, top=PLATE_LIGHT, sub=3, bone="spine", **SMOOTH)
    part.box((0.5, 0.08, 0.14), (0, -0.2, H["hips"].z + 0.1), CRIMSON, top=CRIMSON_LIGHT, bevel=0.02, bone="hips", jitter=0.0)
    part.box((0.26, 0.05, 0.4), (0.08, -0.26, H["hips"].z - 0.14), CRIMSON, top=CRIMSON_LIGHT, bevel=0.015, taper=0.75, bone="hips", jitter=0.0)
    for sx in (-1, 1):
        side = ".L" if sx > 0 else ".R"
        part.ball((0.22, 0.2, 0.17), H["upper_arm" + side] + Vector((sx * 0.04, 0, 0.07)), PLATE, top=PLATE_LIGHT, sub=3, bone="upper_arm" + side, **SMOOTH)
        part.cone(0.06, 0.16, H["upper_arm" + side] + Vector((sx * 0.1, 0, 0.18)), STEEL, rot=(0, sx * 0.5, 0), segs=6, bone="upper_arm" + side, **SMOOTH)
        part.cyl(0.13, 0.12, 0.18, H["forearm" + side].lerp(T["forearm" + side], 0.3), IRON, top=IRON_LIGHT,
                 rot=tuple((T["forearm" + side] - H["forearm" + side]).to_track_quat("Z", "Y").to_euler()), segs=8, bone="forearm" + side, **SMOOTH)
        part.cone(0.055, 0.3, head + Vector((sx * 0.17, 0.02, 0.08)), BONE, rot=(0.25, sx * 0.9, 0), segs=6, bone="head", **SMOOTH)   # horn
    part.ball((0.2, 0.21, 0.15), head + Vector((0, 0.03, 0.06)), PLATE, top=PLATE_LIGHT, sub=3, bone="head", **SMOOTH)
    part.box((0.3, 0.06, 0.05), head + Vector((0, -0.17, 0.07)), IRON_LIGHT, bevel=0.01, bone="head", jitter=0.0)
    # maul: long haft, iron head with crimson bands
    across = Vector((d.z, 0.0, -d.x))
    end = grip + d * 1.45
    part.limb(grip - d * 0.42, end, 0.04, 0.04, WOOD, top=WOOD_LIGHT, segs=8, bone="weapon", jitter=0.0)
    part.blade(end - d * 0.2, end + d * 0.14, across, 0.56, 0.34, IRON, top=IRON_LIGHT, taper=1.0, bevel=0.035, bone="weapon", jitter=0.0)
    for offset in (-0.12, 0.06):
        part.blade(end + d * (offset - 0.02), end + d * (offset + 0.02), across, 0.6, 0.38, CRIMSON, taper=1.0, bevel=0.008, bone="weapon", jitter=0.0)
    part.ball((0.06, 0.06, 0.06), grip - d * 0.44, IRON_LIGHT, bone="weapon", **SMOOTH)
    rig.bind(part.finish())

    stand = P(_loc={"hips": (0, 0, -0.06)}, hips=(8, 0, -8), spine=(16, 0, -6), head=(-18, 0, 14),
              thigh_L=(-22, -12, 10), shin_L=(26, 0, 0), foot_L=(-6, 0, 0), thigh_R=(-6, 12, -10), shin_R=(22, 0, 0), foot_R=(-10, 0, 0),
              upper_arm_R=(-40, 20, 10), forearm_R=(-112, 0, 0), weapon=(-46, 0, 0),
              upper_arm_L=(-46, -14, -36), forearm_L=(-52, 0, 0))
    coil = P(stand, _loc={"hips": (0, 0.06, -0.12)}, hips=(10, 0, -26), spine=(20, 0, -22), head=(-22, 0, 40),
             upper_arm_R=(-40, 30, -10), forearm_R=(-70, 0, 0), weapon=(-10, 0, 0),
             upper_arm_L=(-60, -10, -50), forearm_L=(-60, 0, 0))
    raised = P(_loc={"hips": (0, 0.08, 0.05)}, hips=(-8, 0, -6), spine=(-20, 0, -4), head=(6, 0, 8),
               thigh_L=(-18, -12, 8), shin_L=(14, 0, 0), foot_L=(14, 0, 0), thigh_R=(4, 12, -8), shin_R=(10, 0, 0), foot_R=(16, 0, 0),
               upper_arm_R=(-158, 14, 0), forearm_R=(-26, 0, 0), weapon=(-10, 0, 0),
               upper_arm_L=(-150, -16, 0), forearm_L=(-40, 0, 0))
    peak = P(raised, _loc={"hips": (0, 0.1, 0.08)}, spine=(-26, 0, -4), upper_arm_R=(-166, 14, 0), weapon=(-16, 0, 0))
    slam = P(_loc={"hips": (0, -0.3, -0.26)}, hips=(26, 0, 4), spine=(44, 0, 4), head=(-52, 0, -6),
             thigh_L=(-64, -14, 6), shin_L=(64, 0, 0), foot_L=(0, 0, 0), thigh_R=(24, 14, -6), shin_R=(30, 0, 0), foot_R=(-40, 0, 0),
             upper_arm_R=(-118, 6, 0), forearm_R=(-10, 0, 0), weapon=(-10, 0, 0),
             upper_arm_L=(-104, -10, 6), forearm_L=(-30, 0, 0))
    buried = P(slam, _loc={"hips": (0, -0.32, -0.3)}, spine=(48, 0, 4), upper_arm_R=(-116, 6, 0), weapon=(-8, 0, 0))
    heave = P(slam, _loc={"hips": (0, -0.22, -0.2)}, hips=(18, 0, 0), spine=(34, 0, 0), head=(-36, 0, 0), upper_arm_R=(-96, 10, 0), weapon=(6, 0, 0))
    clip_idle(rig, stand, frames=140)
    clip_move(rig, stand, "walk", frames=52, stride=0.8, lean=12, bounce=0.045)
    # game timing: wind-up 1.15 s, active 0.18 s, recovery 0.9 s
    rig.clip("attack", [(0, stand), (18, coil), (50, raised), (69, peak), (73, slam), (80, buried), (106, heave), (134, stand)])
    clip_hit(rig, stand, frames=10)
    clip_death(rig, stand, HEAVY["hip_z"], frames=60)
    return rig


# ------------------------------------------------------------------------------------------
# Charger: spear and shield
# ------------------------------------------------------------------------------------------
def build_charger():
    rig, grip, d = make_rig("Charger", MEDIUM)
    part = sg.Part("ChargerBody", "Character", seed=33)
    head = body(part, rig, OCHRE, OCHRE_LIGHT, limb=0.075, torso=0.26)
    H, T = rig.heads, rig.tails
    # leather cap with a crest, chest strap
    part.ball((0.185, 0.2, 0.13), head + Vector((0, 0.03, 0.08)), LEATHER, top=LEATHER_LIGHT, sub=3, bone="head", **SMOOTH)
    part.box((0.04, 0.3, 0.12), head + Vector((0, 0.04, 0.2)), CRIMSON, top=CRIMSON_LIGHT, bevel=0.012, bone="head", jitter=0.0)
    part.box((0.5, 0.36, 0.08), H["spine"].lerp(T["spine"], 0.5), LEATHER, top=LEATHER_LIGHT, rot=(0, 0.5, 0), bevel=0.02, bone="spine", jitter=0.0)
    # spear continues the right forearm: short butt behind the hand, long shaft ahead
    across = Vector((d.z, 0.0, -d.x))
    tip = grip + d * 1.55
    part.limb(grip - d * 0.6, tip, 0.028, 0.026, WOOD, top=WOOD_LIGHT, segs=8, bone="weapon", jitter=0.0)
    part.blade(tip, tip + d * 0.36, across, 0.13, 0.04, STEEL, top=sg.srgb("#ffffff"), taper=0.12, bone="weapon", jitter=0.0, grad=(1, 1))
    part.ball((0.05, 0.05, 0.05), tip, CRIMSON_LIGHT, bone="weapon", **SMOOTH)
    # round shield strapped to the left forearm, facing outward
    arm = (T["forearm.L"] - H["forearm.L"]).normalized()
    centre = H["forearm.L"].lerp(T["forearm.L"], 0.6) + Vector((0.11, -0.02, 0))
    rot = (0, math.pi / 2, 0)
    part.cyl(0.36, 0.34, 0.05, centre, BONE, rot=rot, segs=18, bone="forearm.L", jitter=0.0, smooth=True)
    part.cyl(0.38, 0.38, 0.03, centre - Vector((0.01, 0, 0)), IRON, top=IRON_LIGHT, rot=rot, segs=18, bone="forearm.L", jitter=0.0, smooth=True)
    part.ball((0.06, 0.09, 0.09), centre + Vector((0.05, 0, 0)), CRIMSON, top=CRIMSON_LIGHT, bone="forearm.L", **SMOOTH)
    rig.bind(part.finish())

    stand = P(_loc={"hips": (0, 0, -0.04)}, hips=(6, 0, 16), spine=(10, 0, 10), head=(-10, 0, -22),
              thigh_L=(-22, 0, 6), shin_L=(22, 0, 0), thigh_R=(10, 0, -12), shin_R=(16, 0, 0), foot_R=(-22, 0, 0),
              upper_arm_R=(-16, 16, 0), forearm_R=(-74, 0, 0), weapon=(-84, 0, 0),
              upper_arm_L=(-38, -30, 20), forearm_L=(-72, 0, 30))
    def level(body_pitch, body_yaw):
        # spear couched under the arm, kept level and pointing where the body is heading
        return P(upper_arm_R=(14, 22, -body_yaw), forearm_R=(-98, 0, 0), weapon=(-6 - body_pitch, 0, 0))
    lower = P(stand, level(30, 36), _loc={"hips": (0, 0.03, -0.12)}, hips=(12, 0, 22), spine=(18, 0, 14), head=(-24, 0, -32),
              thigh_L=(-40, 0, 6), shin_L=(46, 0, 0), thigh_R=(16, 0, -12), shin_R=(30, 0, 0), foot_R=(-34, 0, 0),
              upper_arm_L=(-58, -22, 34), forearm_L=(-70, 0, 40))
    braced = P(lower, level(44, 40), _loc={"hips": (0, 0.08, -0.2)}, hips=(18, 0, 24), spine=(26, 0, 16), head=(-38, 0, -36),
               thigh_L=(-54, 0, 6), shin_L=(64, 0, 0), thigh_R=(24, 0, -12), shin_R=(36, 0, 0), foot_R=(-46, 0, 0))
    rock = P(braced, _loc={"hips": (0, 0.11, -0.22)}, spine=(30, 0, 16))
    clip_idle(rig, stand)
    clip_move(rig, stand, "walk", frames=36, stride=0.9, lean=9)
    rig.clip("brace", [(0, stand), (14, lower), (34, braced), (41, rock), (48, braced)])
    # charge: a leaning sprint with the spear couched
    dash = P(stand, level(54, 18), hips=(30, 0, 10), spine=(24, 0, 8), head=(-48, 0, -16), upper_arm_L=(-66, -18, 40), forearm_L=(-64, 0, 40))
    clip_move(rig, dash, "charge", frames=20, stride=1.35, lean=0.0, bounce=0.04)
    skid = P(stand, level(0, 18), _loc={"hips": (0, 0.1, -0.16)}, hips=(-6, 0, 10), spine=(-10, 0, 8), head=(-4, 0, -16),
             thigh_L=(-58, 0, 6), shin_L=(30, 0, 0), foot_L=(20, 0, 0), thigh_R=(-20, 0, -10), shin_R=(60, 0, 0),
             upper_arm_R=(-10, 30, 0), forearm_R=(-70, 0, 0), weapon=(-30, 0, 0))
    winded = P(stand, _loc={"hips": (0, -0.04, -0.14)}, hips=(16, 0, 10), spine=(34, 0, 6), head=(-10, 0, -10),
               thigh_L=(-34, 0, 6), shin_L=(40, 0, 0), thigh_R=(-6, 0, -10), shin_R=(34, 0, 0),
               upper_arm_R=(-10, 18, 0), forearm_R=(-60, 0, 0), weapon=(-70, 0, 0), upper_arm_L=(-20, -24, 10), forearm_L=(-50, 0, 20))
    rig.clip("recover", [(0, dash), (6, skid), (22, winded), (40, P(winded, spine=(30, 0, 6))), (60, stand)])
    clip_hit(rig, stand)
    clip_death(rig, stand, MEDIUM["hip_z"])
    return rig


# ------------------------------------------------------------------------------------------
# Banner: support
# ------------------------------------------------------------------------------------------
def build_banner():
    rig, grip, d = make_rig("Banner", MEDIUM)
    part = sg.Part("BannerBody", "Character", seed=34)
    head = body(part, rig, PLUM, PLUM_LIGHT, limb=0.065, torso=0.23)
    H, T = rig.heads, rig.tails
    # long robe, bone mask, feathered headband
    part.cyl(0.3, 0.2, 0.46, (0, 0, H["hips"].z - 0.4), PLUM, top=PLUM_LIGHT, segs=10, bone="hips", **SMOOTH)
    part.ball((0.14, 0.07, 0.15), head + Vector((0, -0.15, 0.02)), BONE, bone="head", **SMOOTH)
    part.box((0.36, 0.38, 0.05), head + Vector((0, 0.02, 0.11)), CRIMSON, top=CRIMSON_LIGHT, bevel=0.015, bone="head", jitter=0.0)
    for sx in (-1, 0, 1):
        part.cone(0.035, 0.24, head + Vector((sx * 0.07, 0.17, 0.13)), BONE, rot=(0.5, sx * 0.3, 0), segs=5, bone="head", **SMOOTH)
    # banner pole continues the right forearm; the flag hangs from a crossbar near the top
    across = Vector((d.z, 0.0, -d.x))
    top = grip + d * 1.75
    part.limb(grip - d * 0.75, top, 0.026, 0.024, WOOD, top=WOOD_LIGHT, segs=8, bone="weapon", jitter=0.0)
    part.ball((0.06, 0.06, 0.08), top + d * 0.05, sg.srgb("#e3b04b"), bone="weapon", **SMOOTH)
    bar = top - d * 0.12
    part.limb(bar - across * 0.06, bar + across * 0.66, 0.018, 0.018, WOOD, top=WOOD_LIGHT, segs=6, bone="weapon", jitter=0.0)
    a, b = bar + across * 0.04, bar + across * 0.64
    drop = -d * 0.86
    part.quad([a, b, b + drop, (a + b) / 2.0 + drop * 1.18, a + drop], CRIMSON, top=CRIMSON_LIGHT, bone="weapon", jitter=0.0, grad=(0.85, 1.05))
    part.quad([a + drop, (a + b) / 2.0 + drop * 1.18, b + drop, b, a], CRIMSON, top=CRIMSON_LIGHT, bone="weapon", jitter=0.0, grad=(0.85, 1.05))
    centre = (a + b) / 2.0 + drop * 0.5
    part.ball((0.13, 0.13, 0.13) , centre, BONE, bone="weapon", smooth=True, jitter=0.0)   # bone-white roundel, visible from both sides
    rig.bind(part.finish())

    stand = P(_loc={"hips": (0, 0, -0.02)}, hips=(2, 0, 0), spine=(6, 0, 0), head=(-6, 0, 0),
              thigh_L=(-8, 0, 6), shin_L=(10, 0, 0), thigh_R=(-2, 0, -6), shin_R=(8, 0, 0),
              upper_arm_R=(-34, 18, 0), forearm_R=(-58, 0, 0), weapon=(-88, 0, 0),
              upper_arm_L=(10, -34, 0), forearm_L=(-70, 0, 60))
    lift = P(stand, _loc={"hips": (0, 0, 0.03)}, spine=(-4, 0, 0), head=(-16, 0, 0),
             upper_arm_R=(-78, 14, 0), forearm_R=(-52, 0, 0), weapon=(-50, 0, 0),
             upper_arm_L=(-110, -30, 0), forearm_L=(-40, 0, 0))
    plant = P(stand, _loc={"hips": (0, 0, -0.07)}, spine=(12, 0, 0), head=(2, 0, 0),
              thigh_L=(-18, 0, 6), shin_L=(24, 0, 0), thigh_R=(-12, 0, -6), shin_R=(22, 0, 0),
              upper_arm_R=(-28, 18, 0), forearm_R=(-60, 0, 0), weapon=(-92, 0, 0))
    clip_idle(rig, stand)
    clip_move(rig, stand, "walk", frames=40, stride=0.7, lean=5, bounce=0.02, swing={})
    rig.clip("chant", [(0, stand), (22, lift), (30, lift), (36, plant), (44, stand), (70, stand)])
    clip_hit(rig, stand)
    clip_death(rig, stand, MEDIUM["hip_z"])
    return rig


BUILDERS = {"crossbow": build_crossbow, "brute": build_brute, "charger": build_charger, "banner": build_banner}

if __name__ == "__main__":
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    flags = [a for a in raw if a.startswith("--")]
    args = [a for a in raw if not a.startswith("--")]
    only = [f.split("=", 1)[1] for f in flags if f.startswith("--only=")]
    for name, builder in BUILDERS.items():
        if only and name not in only:
            continue
        scene = sg.reset_scene()
        scene.render.fps = sc.FPS
        sc.REPORT = "--report" in flags
        rig = builder()
        if len(args) > 1:
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args[1], name + "_temp.blend"))
        if args:
            os.makedirs(args[0], exist_ok=True)
            path = os.path.join(args[0], name + "_temp.glb")
            sg.export_glb(path, animations=True)
            print("EXPORTED", path)
