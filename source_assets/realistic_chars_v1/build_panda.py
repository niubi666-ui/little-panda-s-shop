"""Realistic red panda for combat: the textured, skinned model plus the toy panda's move set.

    blender --background --python build_panda.py -- <out.glb> [<out.blend>]

Inputs (all in the repository):
    source_assets/combat_visual_v1/blend/red_panda_temp.blend   the clips
    game/assets/characters/red_panda/red_panda_v008.glb         the model
    game/assets/weapons/longsword_v001/longsword.glb            the sword
To swap the model later: change MODEL and MAPPING to the new rig's bone names.
"""
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import retarget as rt  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
CLIPS = os.path.join(REPO, "source_assets", "combat_visual_v1", "blend", "red_panda_temp.blend")
MODEL = os.path.join(REPO, "game", "assets", "characters", "red_panda", "red_panda_v008.glb")
SWORD = os.path.join(REPO, "game", "assets", "weapons", "longsword_v001", "longsword.glb")

MAPPING = {
    "hips": "Hip", "spine": "Waist", "head": "Head",
    "upper_arm.L": "L_Upperarm", "forearm.L": "L_Forearm", "hand.L": "L_Hand",
    "upper_arm.R": "R_Upperarm", "forearm.R": "R_Forearm", "hand.R": "R_Hand",
    "thigh.L": "L_Thigh", "shin.L": "L_Calf", "foot.L": "L_Foot",
    "thigh.R": "R_Thigh", "shin.R": "R_Calf", "foot.R": "R_Foot",
    "tail1": "Tail_01", "tail2": "Tail_03", "tail3": "Tail_05",
    "weapon": "Weapon",
}
UPRIGHT = {"hips", "spine", "head", "weapon"}
SWORD_SCALE = 0.62
SWORD_GRIP_Y = -0.68            # where the hand holds it, in the sword's own units


def add_sword(armature, source_rest):
    """A Weapon bone in the right hand that keeps the toy sword's exact world orientation,
    and the longsword skinned to it."""
    world = armature.matrix_world
    hand = armature.data.bones["R_Hand"]
    forearm = armature.data.bones["R_Forearm"]
    reach = (world @ hand.head_local) - (world @ forearm.head_local)
    palm = world @ hand.head_local + reach.normalized() * 0.055
    orientation = source_rest["weapon"].to_3x3().normalized()
    rt.add_bone(armature, "Weapon", "R_Hand", palm, orientation, 0.3)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SWORD)
    parts = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    sword = bpy.context.view_layer.objects.active
    sword.name = "Longsword"
    for stray in [o for o in bpy.data.objects if o not in before and o is not sword]:
        bpy.data.objects.remove(stray, do_unlink=True)
    sword.parent = None
    sword.matrix_world = (Matrix.Translation(palm) @ orientation.to_4x4() @ Matrix.Scale(SWORD_SCALE, 4)
                          @ Matrix.Translation((0, -SWORD_GRIP_Y, 0)))
    bpy.ops.object.select_all(action="DESELECT")
    sword.select_set(True)
    bpy.context.view_layer.objects.active = sword
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    rt.bind_rigid(sword, armature, "Weapon")
    return sword


if __name__ == "__main__":
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
    source = rt.open_source(CLIPS)
    source_rest = rt.rest_matrices(source)
    clips = rt.read_clips(source)
    armature, meshes = rt.import_target(MODEL, -90.0, drop=("Icosphere",))
    meshes.append(add_sword(armature, source_rest))
    rt.retarget(source_rest, clips, armature, MAPPING, UPRIGHT, "hips")
    rt.export(args[0], armature, meshes, args[1] if len(args) > 1 else None)
