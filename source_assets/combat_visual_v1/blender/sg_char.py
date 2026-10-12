"""Rig + keyframe helpers for the temporary combat characters.

Characters face Blender -Y, stand on Z = 0, and are segmented toys: every primitive is
rigidly weighted to one bone, so there is no skin weighting to maintain.

Poses are written as rotations in ARMATURE axes, relative to the parent's posed frame:
    (pitch_x, roll_y, yaw_z) in degrees, applied as  Rz(yaw) @ Rx(pitch) @ Ry(roll)
With the character facing -Y and its left side at +X:
    +X pitch  : upright bones lean forward; hanging limbs swing backward
    +Z yaw    : turn to the character's left (counter-clockwise from above)
    +Y roll   : upright bones lean to the left; the RIGHT arm lifts sideways (left arm: -Y)
Clips are authored at 60 fps.
"""
import math

import bpy
from mathutils import Matrix, Vector

FPS = 60


def humanoid_bones(p):
    """Bone table from a proportion dict. Shared by the panda and every humanoid enemy,
    so animation functions can be reused across characters."""
    bones = [
        ("root", (0, 0, 0), (0, 0, 0.15), None),
        ("hips", (0, 0, p["hip_z"]), (0, 0, p["hip_z"] + 0.12), "root"),
        ("spine", (0, 0, p["hip_z"] + 0.12), (0, 0, p["neck_z"] - 0.06), "hips"),
        ("head", (0, 0, p["neck_z"]), (0, 0, p["neck_z"] + p["head_len"]), "spine"),
    ]
    for side, sx in ((".L", 1.0), (".R", -1.0)):
        sh = Vector((sx * p["shoulder_x"], 0, p["shoulder_z"]))
        el = sh + Vector((sx * p["arm_out"], 0, -p["upper_arm"]))
        wr = el + Vector((sx * p["arm_out"] * 0.7, -0.02, -p["forearm"]))
        hd = wr + Vector((sx * 0.02, -0.01, -p["hand"]))
        bones += [
            ("upper_arm" + side, sh, el, "spine"),
            ("forearm" + side, el, wr, "upper_arm" + side),
            ("hand" + side, wr, hd, "forearm" + side),
        ]
        hip = Vector((sx * p["leg_x"], 0, p["hip_z"]))
        knee = hip + Vector((sx * 0.01, -0.01, -p["thigh"]))
        ankle = knee + Vector((0, 0.01, -p["shin"]))
        toe = ankle + Vector((0, -p["foot"], -0.03))
        bones += [
            ("thigh" + side, hip, knee, "hips"),
            ("shin" + side, knee, ankle, "thigh" + side),
            ("foot" + side, ankle, toe, "shin" + side),
        ]
    return bones


class Rig:
    def __init__(self, name, bones):
        """bones: (name, head, tail, parent or None). Order must list parents first."""
        armature = bpy.data.armatures.new(name + "Armature")
        self.obj = bpy.data.objects.new(name, armature)
        bpy.context.scene.collection.objects.link(self.obj)
        bpy.context.view_layer.objects.active = self.obj
        bpy.ops.object.mode_set(mode="EDIT")
        for bone_name, head, tail, parent in bones:
            bone = armature.edit_bones.new(bone_name)
            bone.head = head
            bone.tail = tail
            bone.roll = 0.0
            if parent is not None:
                bone.parent = armature.edit_bones[parent]
                bone.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        self.rest = {bone.name: bone.matrix_local.to_3x3() for bone in armature.bones}
        self.heads = {bone.name: bone.head_local.copy() for bone in armature.bones}
        self.tails = {bone.name: bone.tail_local.copy() for bone in armature.bones}
        for pose_bone in self.obj.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"
        self.obj.animation_data_create()
        self._last = {}
        self.report_bones = []     # e.g. ["weapon"]: print world direction/tip per key while authoring

    def bind(self, mesh_obj):
        mesh_obj.parent = self.obj
        modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = self.obj

    def _apply(self, pose):
        loc = pose.get("_loc", {})
        scale = pose.get("_scale", {})
        for pose_bone in self.obj.pose.bones:
            name = pose_bone.name
            rest = self.rest[name]
            pitch, roll, yaw = pose.get(name, (0.0, 0.0, 0.0))
            delta = (Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X")
                     @ Matrix.Rotation(math.radians(roll), 3, "Y"))
            quat = (rest.inverted() @ delta @ rest).to_quaternion()
            last = self._last.get(name)
            if last is not None and last.dot(quat) < 0.0:
                quat.negate()                       # keep interpolation on the short arc
            self._last[name] = quat.copy()
            pose_bone.rotation_quaternion = quat
            pose_bone.location = rest.inverted() @ Vector(loc.get(name, (0.0, 0.0, 0.0)))
            pose_bone.scale = Vector(scale.get(name, (1.0, 1.0, 1.0)))

    def clip(self, name, keys, loop=False):
        """keys: [(frame, pose)]. For loops, repeat the first pose at the last frame."""
        action = bpy.data.actions.new(name)
        self.obj.animation_data.action = action
        self._last = {}
        for frame, pose in keys:
            self._apply(pose)
            if self.report_bones:
                bpy.context.view_layer.update()
                for bone_name in self.report_bones:
                    bone = self.obj.pose.bones[bone_name]
                    d = (bone.tail - bone.head).normalized()
                    print("POSE %-9s f%-3d %-11s fwd=%+.2f right=%+.2f up=%+.2f  head=(%+.2f,%+.2f,%+.2f)" % (name, frame, bone_name, -d.y, -d.x, d.z, -bone.head.x, -bone.head.y, bone.head.z))
            for pose_bone in self.obj.pose.bones:
                pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
                pose_bone.keyframe_insert("location", frame=frame)
                pose_bone.keyframe_insert("scale", frame=frame)
        self.obj.animation_data.action = None
        track = self.obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(keys[0][0]), action)
        if hasattr(strip, "action_slot") and strip.action_slot is None and len(action.slots):
            strip.action_slot = action.slots[0]
        strip.name = name
        track.mute = True
        self._apply({})
        return action


def P(*poses, **bones):
    """Merge pose dicts left to right; '_loc' and '_scale' sub-dicts are merged too."""
    out = {}
    for pose in poses + (bones,):
        for key, value in pose.items():
            if key in ("_loc", "_scale"):
                merged = dict(out.get(key, {}))
                merged.update(value)
                out[key] = merged
            else:
                out[key.replace("_L", ".L").replace("_R", ".R")] = value
    return out


def mirror(pose):
    """Swap .L/.R and flip roll/yaw: the same pose on the other side."""
    out = {}
    for key, value in pose.items():
        if key in ("_loc", "_scale"):
            out[key] = {swap(k): ((-v[0], v[1], v[2]) if key == "_loc" else v) for k, v in value.items()}
        else:
            out[swap(key)] = (value[0], -value[1], -value[2])
    return out


def swap(name):
    if name.endswith(".L"):
        return name[:-2] + ".R"
    if name.endswith(".R"):
        return name[:-2] + ".L"
    return name
