"""Temporary red panda hero: segmented toy model, shared humanoid rig, full combat clip set.

Run:  blender --background --factory-startup --python build_panda.py -- <out.glb> [<out.blend>]

Clip contract read by Godot (presentation/combat/rigs): see CLIPS at the bottom. Attack
clips are split by two cut times (end of wind-up, end of the active swing); the game maps
its own wind-up / active / recovery durations onto those three segments, so retiming an
attack in data never needs a re-export.
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

ORANGE = sg.srgb("#cf5a26")
ORANGE_LIGHT = sg.srgb("#f29242")
RUST = sg.srgb("#8f381c")
DARK = sg.srgb("#2f1f1e")
DARK_LIGHT = sg.srgb("#4a302b")
CREAM = sg.srgb("#f8eedc")
GREEN = sg.srgb("#257f66")
GREEN_LIGHT = sg.srgb("#58bb92")
LEATHER = sg.srgb("#6f4a2e")
LEATHER_LIGHT = sg.srgb("#a5774a")
STEEL = sg.srgb("#c9d3df")
STEEL_LIGHT = sg.srgb("#ffffff")
GOLD = sg.srgb("#e3b04b")
INK = sg.srgb("#1a1214")

PROPORTIONS = dict(hip_z=0.40, neck_z=0.74, head_len=0.26, shoulder_x=0.20, shoulder_z=0.69, arm_out=0.10,
                   upper_arm=0.15, forearm=0.14, hand=0.07, leg_x=0.10, thigh=0.18, shin=0.15, foot=0.13)
SWORD_LENGTH = 0.98


def build_rig():
    bones = sc.humanoid_bones(PROPORTIONS)
    table = {name: (Vector(head), Vector(tail)) for name, head, tail, parent in bones}
    bones += [
        ("ear.L", (0.17, 0.0, 1.12), (0.25, 0.0, 1.27), "head"),
        ("ear.R", (-0.17, 0.0, 1.12), (-0.25, 0.0, 1.27), "head"),
        ("tail1", (0, 0.13, 0.42), (0, 0.33, 0.47), "hips"),
        ("tail2", (0, 0.33, 0.47), (0, 0.55, 0.58), "tail1"),
        ("tail3", (0, 0.55, 0.58), (0, 0.74, 0.74), "tail2"),
    ]
    # The sword continues the forearm, so a straight arm is a straight reach.
    elbow, wrist = table["forearm.R"]
    direction = (wrist - elbow).normalized()
    grip = table["hand.R"][0] + direction * 0.05
    bones += [
        ("weapon", grip, grip + direction * 0.3, "hand.R"),
        ("weapon_tip", grip + direction * SWORD_LENGTH, grip + direction * (SWORD_LENGTH + 0.1), "weapon"),
    ]
    return sc.Rig("RedPanda", bones), grip, direction


def build_mesh(rig, grip, direction):
    body = sg.Part("PandaBody", "Character", seed=21)
    H, T = rig.heads, rig.tails
    smooth = dict(smooth=True, jitter=0.0)

    # torso: dark belly and legs like a real red panda, orange back and head
    body.ball((0.185, 0.165, 0.17), (0, 0.0, 0.42), DARK, top=DARK_LIGHT, bone="hips", **smooth)
    body.ball((0.2, 0.175, 0.2), (0, 0.0, 0.60), ORANGE, top=ORANGE_LIGHT, bone="spine", **smooth)
    body.ball((0.15, 0.06, 0.15), (0, -0.14, 0.58), DARK, top=DARK_LIGHT, bone="spine", **smooth)       # chest patch
    # shopkeeper apron and scarf
    body.box((0.25, 0.035, 0.2), (0, -0.175, 0.56), GREEN, top=GREEN_LIGHT, bevel=0.015, bone="spine", jitter=0.0)
    body.box((0.3, 0.035, 0.2), (0, -0.168, 0.4), GREEN, top=GREEN, bevel=0.015, taper=1.12, bone="hips", jitter=0.0)
    body.box((0.11, 0.02, 0.08), (0, -0.2, 0.42), GREEN_LIGHT, bevel=0.01, bone="hips", jitter=0.0)      # pocket
    body.ball((0.215, 0.195, 0.075), (0, 0.0, 0.745), GREEN, top=GREEN_LIGHT, bone="spine", **smooth)
    body.ball((0.07, 0.05, 0.12), (0.1, 0.17, 0.66), GREEN, top=GREEN_LIGHT, bone="spine", **smooth)     # scarf tail
    # belt pouch
    body.ball((0.1, 0.075, 0.09), (0.15, 0.13, 0.46), LEATHER, top=LEATHER_LIGHT, bone="hips", **smooth)

    # head
    body.ball((0.275, 0.25, 0.235), (0, 0.0, 0.98), ORANGE, top=ORANGE_LIGHT, sub=3, bone="head", **smooth)
    for sx in (-1, 1):
        body.ball((0.12, 0.1, 0.105), (sx * 0.2, -0.07, 0.9), CREAM, bone="head", **smooth)              # cheek tuft
        body.ball((0.036, 0.022, 0.048), (sx * 0.105, -0.225, 1.0), INK, bone="head", **smooth)          # eye
        body.ball((0.038, 0.02, 0.03), (sx * 0.12, -0.212, 1.075), CREAM, bone="head", **smooth)         # brow spot
        body.ball((0.03, 0.02, 0.07), (sx * 0.135, -0.2, 0.915), RUST, bone="head", **smooth)            # tear mark
        ear = "ear.L" if sx > 0 else "ear.R"
        body.ball((0.105, 0.05, 0.115), (sx * 0.2, 0.0, 1.185), ORANGE, top=ORANGE_LIGHT, bone=ear, **smooth)
        body.ball((0.07, 0.03, 0.08), (sx * 0.2, -0.035, 1.185), CREAM, bone=ear, **smooth)
    body.ball((0.115, 0.09, 0.085), (0, -0.2, 0.925), CREAM, bone="head", **smooth)                      # muzzle
    body.ball((0.034, 0.026, 0.026), (0, -0.285, 0.95), INK, bone="head", **smooth)                      # nose

    # limbs
    for side, sx in ((".L", 1), (".R", -1)):
        body.limb(H["upper_arm" + side], T["upper_arm" + side], 0.07, 0.062, DARK, top=DARK_LIGHT, bone="upper_arm" + side, **smooth)
        body.ball((0.072, 0.072, 0.072), H["upper_arm" + side], ORANGE, bone="upper_arm" + side, **smooth)
        body.ball((0.064, 0.064, 0.064), H["forearm" + side], DARK, bone="forearm" + side, **smooth)
        body.limb(H["forearm" + side], T["forearm" + side], 0.062, 0.058, DARK, top=DARK_LIGHT, bone="forearm" + side, **smooth)
        body.ball((0.072, 0.072, 0.072), (H["hand" + side] + T["hand" + side]) / 2.0, DARK, top=DARK_LIGHT, bone="hand" + side, **smooth)
        body.limb(H["thigh" + side], T["thigh" + side], 0.092, 0.08, DARK, top=DARK_LIGHT, bone="thigh" + side, **smooth)
        body.ball((0.08, 0.08, 0.08), H["shin" + side], DARK, bone="shin" + side, **smooth)
        body.limb(H["shin" + side], T["shin" + side], 0.078, 0.07, DARK, top=DARK_LIGHT, bone="shin" + side, **smooth)
        ankle = H["foot" + side]
        body.ball((0.078, 0.125, 0.058), (ankle.x, ankle.y - 0.05, 0.05), DARK, top=DARK_LIGHT, bone="foot" + side, **smooth)

    # ringed tail: five blobs along three bones
    rings = [("tail1", 0.25, 0.115, ORANGE), ("tail1", 0.95, 0.135, RUST), ("tail2", 0.55, 0.15, ORANGE),
             ("tail3", 0.2, 0.145, RUST), ("tail3", 0.85, 0.12, DARK)]
    for bone, t, radius, color in rings:
        center = H[bone].lerp(T[bone], t)
        body.ball((radius, radius * 1.15, radius), center, color, top=sg.mix(color, ORANGE_LIGHT, 0.35), bone=bone, **smooth)

    # sword: flat of the blade lies in the swing plane when the arm is level
    width_axis = Vector((direction.z, 0.0, -direction.x))
    guard = grip + direction * 0.1
    body.limb(grip - direction * 0.08, guard, 0.024, 0.024, LEATHER, top=LEATHER_LIGHT, segs=8, bone="weapon", jitter=0.0)
    body.ball((0.04, 0.04, 0.04), grip - direction * 0.1, GOLD, bone="weapon", **smooth)
    body.blade(guard - direction * 0.02, guard + direction * 0.03, width_axis, 0.26, 0.05, GOLD, taper=1.0, bevel=0.01, bone="weapon", jitter=0.0)
    body.blade(guard + direction * 0.03, grip + direction * SWORD_LENGTH, width_axis, 0.115, 0.03, STEEL, top=STEEL_LIGHT,
               taper=0.3, bone="weapon", jitter=0.0, grad=(1.0, 1.0))

    obj = body.finish()
    rig.bind(obj)
    return obj


# ------------------------------------------------------------------------------------------
# Poses. (pitch, roll, yaw) in degrees; see sg_char for what each sign does.
# ------------------------------------------------------------------------------------------
def look(body_yaw, keep=0.85):
    """Head counter-turn so the face keeps pointing where the attack goes."""
    return (-10, 0, -body_yaw * keep)


READY = P(
    _loc={"hips": (0, 0, -0.035)},
    hips=(6, 0, -16), spine=(8, 0, -10), head=(-10, 0, 22),
    thigh_L=(-30, 0, 14), shin_L=(32, 0, 0), foot_L=(-4, 0, 0),
    thigh_R=(14, 0, -8), shin_R=(24, 0, 0), foot_R=(-28, 0, 0),
    upper_arm_R=(-18, 16, 24), forearm_R=(-62, 0, 0), weapon=(-38, 0, 0),
    upper_arm_L=(-22, -16, 0), forearm_L=(-58, 0, 0),
    tail1=(8, 0, 0), tail2=(8, 0, 0), tail3=(6, 0, 0),
)


def legs_lunge(depth=1.0):
    return P(thigh_L=(-48 * depth, 0, 8), shin_L=(46 * depth, 0, 0), foot_L=(0, 0, 0),
             thigh_R=(34 * depth, 0, -6), shin_R=(14, 0, 0), foot_R=(-42 * depth, 0, 0))


def legs_back():
    return P(thigh_L=(-36, 0, 10), shin_L=(22, 0, 0), foot_L=(10, 0, 0),
             thigh_R=(2, 0, -12), shin_R=(40, 0, 0), foot_R=(-36, 0, 0))


def clips_basic(rig):
    breathe = P(READY, _loc={"hips": (0, 0, -0.05)}, spine=(11, 0, -10), head=(-12, 0, 22),
                tail1=(8, 0, 9), tail2=(10, 0, 9), tail3=(8, 0, 8), upper_arm_R=(-16, 18, 0), weapon=(-34, 0, 0),
                **{"ear.L": (0, 0, 6), "ear.R": (0, 0, -6)})
    sway = P(READY, tail1=(8, 0, -9), tail2=(6, 0, -9), tail3=(4, 0, -8))
    rig.clip("idle", [(0, sway), (60, breathe), (120, sway)])

    # run: 32 frames per cycle. Sword trails low behind the right hip.
    carry = P(upper_arm_R=(22, 14, 0), forearm_R=(-34, 0, 0), weapon=(48, 0, -42))
    def stride(lead, drop):
        other = ".R" if lead == ".L" else ".L"
        sign = 1 if lead == ".L" else -1
        return P(carry, _loc={"hips": (0, 0, drop)},
                 hips=(14, 0, 10 * sign), spine=(14, 0, -16 * sign), head=(-20, 0, 6 * sign),
                 upper_arm_L=(46 if lead == ".L" else -40, -14, 0), forearm_L=(-70, 0, 0),
                 tail1=(4, 0, -12 * sign), tail2=(10, 0, -10 * sign), tail3=(12, 0, -8 * sign),
                 **{"thigh" + lead: (-54, 0, 0), "shin" + lead: (24, 0, 0), "foot" + lead: (-12, 0, 0),
                    "thigh" + other: (38, 0, 0), "shin" + other: (62, 0, 0), "foot" + other: (26, 0, 0)})
    def passing(support, rise):
        other = ".R" if support == ".L" else ".L"
        sign = 1 if support == ".L" else -1
        return P(carry, _loc={"hips": (0, 0, rise)},
                 hips=(12, 0, 0), spine=(12, 0, 0), head=(-18, 0, 0),
                 upper_arm_L=(0, -14, 0), forearm_L=(-80, 0, 0), upper_arm_R=(16, 26, 0),
                 tail1=(14, 0, 0), tail2=(4, 0, 0), tail3=(0, 0, 0),
                 **{"thigh" + support: (8, 0, 0), "shin" + support: (10, 0, 0), "foot" + support: (-8, 0, 0),
                    "thigh" + other: (-22, 0, 0), "shin" + other: (92, 0, 0), "foot" + other: (10, 0, 0)})
    rig.clip("run", [(0, stride(".L", -0.05)), (8, passing(".L", 0.035)), (16, stride(".R", -0.05)),
                     (24, passing(".R", 0.035)), (32, stride(".L", -0.05))])

    # dodge: 12 frames, sampled by dodge progress. A low, stretched dash.
    launch = P(_loc={"hips": (0, -0.04, -0.15)}, _scale={"root": (1.08, 0.86, 1.08)},
               hips=(26, 0, 0), spine=(34, 0, 0), head=(-42, 0, 0),
               thigh_L=(-70, 0, 0), shin_L=(96, 0, 0), thigh_R=(-20, 0, 0), shin_R=(80, 0, 0),
               upper_arm_L=(50, -24, 0), forearm_L=(-20, 0, 0), upper_arm_R=(46, 26, 0), forearm_R=(-10, 0, 0), weapon=(30, 0, 0),
               tail1=(26, 0, 0), tail2=(14, 0, 0), tail3=(8, 0, 0))
    fly = P(_loc={"hips": (0, -0.1, -0.1)}, _scale={"root": (0.9, 1.16, 0.9)},
            hips=(46, 0, 0), spine=(22, 0, 0), head=(-56, 0, 0),
            thigh_L=(-58, 0, 0), shin_L=(30, 0, 0), foot_L=(30, 0, 0), thigh_R=(40, 0, 0), shin_R=(20, 0, 0), foot_R=(40, 0, 0),
            upper_arm_L=(70, -20, 0), forearm_L=(-8, 0, 0), upper_arm_R=(64, 22, 0), forearm_R=(-6, 0, 0), weapon=(18, 0, 0),
            tail1=(-28, 0, 0), tail2=(-8, 0, 0), tail3=(-4, 0, 0))
    land = P(READY, _loc={"hips": (0, 0, -0.1)}, _scale={"root": (1.06, 0.92, 1.06)}, spine=(18, 0, -10))
    rig.clip("dodge", [(0, READY), (2, launch), (8, fly), (12, land)])

    # hit: 12 frames, sampled by stagger progress.
    recoil = P(_loc={"hips": (0, 0.1, -0.05)}, hips=(-14, 0, -6), spine=(-24, 0, 8), head=(-22, 0, 0),
               thigh_L=(-36, 0, 12), shin_L=(40, 0, 0), thigh_R=(-4, 0, -10), shin_R=(34, 0, 0),
               upper_arm_L=(-30, -70, 0), forearm_L=(-30, 0, 0), upper_arm_R=(-10, 58, 0), forearm_R=(-30, 0, 0), weapon=(-10, 0, 0),
               tail1=(-20, 0, 0), tail2=(-10, 0, 0),
               **{"ear.L": (20, 0, 0), "ear.R": (20, 0, 0)})
    rig.clip("hit", [(0, READY), (3, recoil), (12, READY)])

    # death: knocked onto the back; the last pose is held by the game.
    reel = P(recoil, _loc={"hips": (0, 0.16, 0.02)}, hips=(-34, 0, 0), spine=(-30, 0, 0))
    fall = P(_loc={"hips": (0, 0.36, -0.2)}, hips=(-74, 0, 0), spine=(-12, 0, 0), head=(-16, 0, 0),
             thigh_L=(-50, -14, 0), shin_L=(50, 0, 0), thigh_R=(-30, 14, 0), shin_R=(30, 0, 0),
             upper_arm_L=(-60, -70, 0), upper_arm_R=(-40, 70, 0), forearm_R=(-20, 0, 0), weapon=(30, 0, 0),
             tail1=(40, 0, 0))
    lie = P(_loc={"hips": (0, 0.46, -0.245)}, hips=(-90, 0, 0), spine=(2, 0, 0), head=(6, 0, 18),
            thigh_L=(-8, -16, 0), shin_L=(10, 0, 0), thigh_R=(-22, 16, 0), shin_R=(34, 0, 0),
            upper_arm_L=(-10, -74, 0), forearm_L=(-20, 0, 0), upper_arm_R=(-6, 66, 0), forearm_R=(-10, 0, 0), weapon=(20, 0, 30),
            tail1=(70, 0, 20), tail2=(10, 0, 20))
    bounce = P(lie, _loc={"hips": (0, 0.5, -0.215)}, hips=(-86, 0, 0))
    rig.clip("death", [(0, READY), (5, reel), (18, fall), (24, lie), (29, bounce), (36, lie), (48, lie)])


def clips_attacks(rig):
    # --- attack_1: forehand, right to left ------------------------------------------------
    a1_wind = P(READY, legs_back(), _loc={"hips": (0, 0.06, -0.08)},
                hips=(4, 0, -44), spine=(6, -6, -40), head=look(-84),
                upper_arm_R=(-82, 0, -88), forearm_R=(0, -32, 0), weapon=(0, 0, 0),
                upper_arm_L=(-64, -10, 34), forearm_L=(-30, 0, 0),
                tail1=(6, 0, 24), tail2=(6, 0, 22), tail3=(4, 0, 18))
    a1_hit = P(READY, legs_lunge(0.7), _loc={"hips": (0, -0.07, -0.07)},
               hips=(8, 0, -6), spine=(10, 0, 0), head=look(-6),
               upper_arm_R=(-86, 0, -26), forearm_R=(0, -4, 0), weapon=(0, 0, 0),
               upper_arm_L=(-20, -40, 0), forearm_L=(-40, 0, 0),
               tail1=(6, 0, -6), tail2=(6, 0, -10), tail3=(4, 0, -10))
    a1_through = P(READY, legs_lunge(1.0), _loc={"hips": (0, -0.15, -0.08)},
                   hips=(8, 0, 28), spine=(10, 4, 38), head=look(66),
                   upper_arm_R=(-86, 0, 20), forearm_R=(0, -6, 0), weapon=(0, 0, 0),
                   upper_arm_L=(30, -46, 0), forearm_L=(-30, 0, 0),
                   tail1=(6, 0, -30), tail2=(6, 0, -28), tail3=(4, 0, -22))
    a1_end = P(a1_through, hips=(8, 0, 34), spine=(10, 6, 48), head=look(82),
               upper_arm_R=(-82, 0, 33), forearm_R=(0, -20, 0), weapon=(0, 0, 0))
    a1_settle = P(a1_end, _loc={"hips": (0, -0.12, -0.06)}, hips=(8, 0, 26), spine=(9, 3, 34), head=look(60),
                  upper_arm_R=(-76, 0, 26), forearm_R=(0, -24, 0), weapon=(0, 0, 0),
                  tail1=(6, 0, -8), tail2=(6, 0, -6), tail3=(4, 0, -4))
    rig.clip("attack_1", [(0, READY), (12, a1_wind), (15, a1_hit), (19, a1_through), (24, a1_end), (48, a1_settle)])

    # --- attack_2: backhand, left to right; starts where attack_1 ends -------------------------
    a2_wind = P(a1_settle, _loc={"hips": (0, -0.08, -0.09)}, hips=(6, 0, 38), spine=(8, 6, 52), head=look(90),
                upper_arm_R=(-84, 0, 34), forearm_R=(0, -26, 0), weapon=(0, 0, 0),
                upper_arm_L=(40, -40, 0), tail1=(6, 0, -26), tail2=(6, 0, -24), tail3=(4, 0, -18))
    a2_hit = P(READY, legs_lunge(0.85), _loc={"hips": (0, -0.16, -0.07)},
               hips=(8, 0, 6), spine=(10, 0, 6), head=look(12),
               upper_arm_R=(-86, 0, 8), forearm_R=(0, -10, 0), weapon=(0, 0, 0),
               upper_arm_L=(-10, -50, 0), forearm_L=(-50, 0, 0))
    a2_through = P(a2_hit, _loc={"hips": (0, -0.2, -0.08)}, hips=(8, 0, -26), spine=(10, -4, -38), head=look(-64),
                   upper_arm_R=(-86, 0, -28), forearm_R=(0, -2, 0), weapon=(0, 0, 0),
                   upper_arm_L=(-56, -30, 30), forearm_L=(-40, 0, 0),
                   tail1=(6, 0, 30), tail2=(6, 0, 28), tail3=(4, 0, 22))
    a2_end = P(a2_through, hips=(8, 0, -32), spine=(10, -6, -48), head=look(-80),
               upper_arm_R=(-82, 0, -58), forearm_R=(0, -4, 0), weapon=(0, 0, 0))
    a2_settle = P(a2_end, _loc={"hips": (0, -0.16, -0.06)}, hips=(8, 0, -26), spine=(9, -3, -34), head=look(-60),
                  upper_arm_R=(-78, 0, -46), forearm_R=(0, -8, 0), weapon=(0, 0, 0),
                  tail1=(6, 0, 8), tail2=(6, 0, 6), tail3=(4, 0, 4))
    rig.clip("attack_2", [(0, a1_settle), (12, a2_wind), (15, a2_hit), (19, a2_through), (24, a2_end), (48, a2_settle)])

    # --- attack_3: thrust; starts where attack_2 ends ------------------------------------------
    a3_wind = P(READY, legs_back(), _loc={"hips": (0, 0.06, -0.12)},
                hips=(10, 0, -50), spine=(14, 0, -34), head=look(-84, 0.9),
                upper_arm_R=(34, 22, 82), forearm_R=(-122, 0, 0), weapon=(-2, 0, 0),
                upper_arm_L=(-84, 0, 30), forearm_L=(-6, 0, 0),
                tail1=(20, 0, 10), tail2=(14, 0, 8), tail3=(10, 0, 6))
    a3_hit = P(READY, legs_lunge(1.25), _loc={"hips": (0, -0.3, -0.13)},
               hips=(16, 0, 14), spine=(20, 0, 22), head=(-34, 0, -32),
               upper_arm_R=(-122, 0, -36), forearm_R=(2, 0, 0), weapon=(0, 0, 0),
               upper_arm_L=(52, -36, 0), forearm_L=(-12, 0, 0),
               tail1=(-16, 0, -6), tail2=(-10, 0, -4), tail3=(-6, 0, 0))
    a3_end = P(a3_hit, _loc={"hips": (0, -0.34, -0.14)}, hips=(18, 0, 18), spine=(22, 0, 26), head=(-38, 0, -40),
               upper_arm_R=(-126, 0, -44), tail1=(-22, 0, -8))
    a3_settle = P(READY, _loc={"hips": (0, -0.14, -0.06)}, hips=(8, 0, -4), spine=(10, 0, -2), head=(-12, 0, 6),
                  upper_arm_R=(-50, 10, 0), forearm_R=(-36, 0, 0), weapon=(-16, 0, 0))
    rig.clip("attack_3", [(0, a2_settle), (16, a3_wind), (20, a3_hit), (28, a3_end), (56, a3_settle)])

    # --- heavy: hop and overhead chop ---------------------------------------------------------
    h_wind = P(_loc={"hips": (0, 0.05, 0.14)}, _scale={"root": (0.94, 1.1, 0.94)},
               hips=(-10, 0, -8), spine=(-22, 0, -6), head=(4, 0, 14),
               thigh_L=(-46, 0, 8), shin_L=(78, 0, 0), foot_L=(30, 0, 0), thigh_R=(-14, 0, -8), shin_R=(70, 0, 0), foot_R=(30, 0, 0),
               upper_arm_R=(-160, 10, 0), forearm_R=(-20, 0, 0), weapon=(-10, 0, 0),
               upper_arm_L=(-150, -22, 0), forearm_L=(-30, 0, 0),
               tail1=(-24, 0, 0), tail2=(-14, 0, 0), tail3=(-10, 0, 0))
    h_hit = P(legs_lunge(1.15), _loc={"hips": (0, -0.2, -0.16)}, _scale={"root": (1.08, 0.9, 1.08)},
              hips=(22, 0, 6), spine=(36, 0, 8), head=(-48, 0, -12),
              upper_arm_R=(-116, 0, 4), forearm_R=(-5, 0, 0), weapon=(0, 0, 0),
              upper_arm_L=(20, -44, 0), forearm_L=(-30, 0, 0),
              tail1=(34, 0, 0), tail2=(20, 0, 0), tail3=(12, 0, 0))
    h_end = P(h_hit, _loc={"hips": (0, -0.22, -0.18)}, spine=(40, 0, 8), upper_arm_R=(-112, 0, 4), weapon=(8, 0, 0))
    h_settle = P(READY, _loc={"hips": (0, -0.14, -0.08)}, hips=(10, 0, -6), spine=(16, 0, -4),
                 upper_arm_R=(-34, 10, 0), forearm_R=(-40, 0, 0), weapon=(-10, 0, 0))
    rig.clip("heavy", [(0, READY), (10, P(READY, _loc={"hips": (0, 0.02, -0.12)}, spine=(16, 0, -10), upper_arm_R=(-60, 14, 0))),
                       (22, h_wind), (26, h_hit), (30, h_end), (54, h_settle)])

    # --- cast: rising flick that throws the sword wave. Game wind-up is zero. ---------------------
    c_wind = P(READY, legs_back(), _loc={"hips": (0, 0.02, -0.1)}, hips=(8, 0, 20), spine=(12, 6, 30), head=look(50),
               upper_arm_R=(-45, 0, 40), forearm_R=(0, -20, 0), weapon=(25, 0, 0),
               upper_arm_L=(30, -36, 0))
    c_hit = P(READY, legs_lunge(0.8), _loc={"hips": (0, -0.12, 0.0)}, hips=(2, 0, -14), spine=(-6, -4, -26), head=look(-36),
              upper_arm_R=(-110, 0, 30), forearm_R=(0, -4, 0), weapon=(0, 0, 0),
              upper_arm_L=(-10, -56, 0), forearm_L=(-30, 0, 0),
              tail1=(4, 0, 22), tail2=(4, 0, 20), tail3=(4, 0, 14))
    c_end = P(c_hit, _loc={"hips": (0, -0.14, 0.02)}, spine=(-10, -6, -34), upper_arm_R=(-150, 0, 10))
    c_settle = P(READY, _loc={"hips": (0, -0.08, -0.04)}, hips=(6, 0, -18), spine=(6, 0, -16),
                 upper_arm_R=(-70, 14, -20), forearm_R=(-40, 0, 0), weapon=(-30, 0, 0))
    rig.clip("cast", [(0, READY), (4, c_wind), (8, c_hit), (12, c_end), (34, c_settle)])

    # --- charge: held pose while the skill is charging ------------------------------------------
    charge_a = P(READY, legs_back(), _loc={"hips": (0, 0.04, -0.12)}, hips=(8, 0, -40), spine=(12, 0, -30), head=look(-70, 0.9),
                 upper_arm_R=(-70, 0, -70), forearm_R=(0, 40, 0), weapon=(-14, 20, 0),
                 upper_arm_L=(-70, -8, 30), forearm_L=(-30, 0, 0))
    charge_b = P(charge_a, _loc={"hips": (0, 0.05, -0.135)}, spine=(14, 0, -33), weapon=(-18, 22, 0))
    rig.clip("charge", [(0, charge_a), (20, charge_b), (40, charge_a)])


# Clip contract for Godot: name -> (wind-up end, active end) in seconds for attacks.
CLIPS = {
    "attack_1": (12 / 60, 24 / 60),
    "attack_2": (12 / 60, 24 / 60),
    "attack_3": (16 / 60, 28 / 60),
    "heavy": (22 / 60, 30 / 60),
    "cast": (4 / 60, 12 / 60),
}


def build():
    scene = sg.reset_scene()
    scene.render.fps = sc.FPS
    rig, grip, direction = build_rig()
    if "--report" in sys.argv:
        rig.report_bones = ["weapon"]
    build_mesh(rig, grip, direction)
    clips_basic(rig)
    clips_attacks(rig)
    return rig


if __name__ == "__main__":
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
    build()
    if len(args) > 1:
        bpy.ops.wm.save_as_mainfile(filepath=args[1])
    if args:
        os.makedirs(os.path.dirname(args[0]), exist_ok=True)
        sg.export_glb(args[0], animations=True)
        print("EXPORTED", args[0])
