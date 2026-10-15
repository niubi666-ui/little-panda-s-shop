"""Realistic stand-ins for the four role enemies: the jackal body, each role's toy move set
and the toy's own prop (crossbow, maul, lance, banner) in the right hand.

    blender --background --python build_enemies.py -- <out_dir> [<blend_dir>] [role ...]

Inputs:
    source_assets/combat_visual_v1/blend/<role>_temp.blend           clips and prop
    game/assets/characters/jackal_scout/melee_scout_v001/jackal_scout.glb   the body
To swap a body later: change MODEL / MAPPING (per role if they differ).
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import retarget as rt  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
TOYS = os.path.join(REPO, "source_assets", "combat_visual_v1", "blend")
MODEL = os.path.join(REPO, "game", "assets", "characters", "jackal_scout", "melee_scout_v001", "jackal_scout.glb")
ROLES = ("crossbow", "brute", "charger", "banner")

M = "mixamorig:"
MAPPING = {
    "hips": M + "Hips", "spine": M + "Spine", "head": M + "Head",
    "upper_arm.L": M + "LeftArm", "forearm.L": M + "LeftForeArm", "hand.L": M + "LeftHand",
    "upper_arm.R": M + "RightArm", "forearm.R": M + "RightForeArm", "hand.R": M + "RightHand",
    "thigh.L": M + "LeftUpLeg", "shin.L": M + "LeftLeg", "foot.L": M + "LeftFoot",
    "thigh.R": M + "RightUpLeg", "shin.R": M + "RightLeg", "foot.R": M + "RightFoot",
    "weapon": "Weapon",
}
UPRIGHT = {"hips", "spine", "head", "weapon"}
PALM = 0.045                 # wrist to the middle of the palm, in metres on the unscaled body
PROP_BOOST = 1.15            # props a touch oversized so the role reads from the game camera


def build(role, out_dir, blend_dir):
    source = rt.open_source(os.path.join(TOYS, role + "_temp.blend"))
    toy_mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() is source)
    source_rest = rt.rest_matrices(source)
    clips = rt.read_clips(source)
    armature, meshes = rt.import_target(MODEL, -90.0, drop=("Icosphere", "Jackal_Scout_Saber"))
    world = armature.matrix_world
    hand = armature.data.bones[M + "RightHand"]
    forearm = armature.data.bones[M + "RightForeArm"]
    reach = (world @ hand.head_local) - (world @ forearm.head_local)
    palm = world @ hand.head_local + reach.normalized() * PALM
    rt.add_bone(armature, "Weapon", M + "RightHand", palm, source_rest["weapon"].to_3x3().normalized(), 0.3)
    # props follow overall height, not hip height: the jackal is long-legged next to the toys
    body_top = max((mesh.matrix_world @ vert.co).z for mesh in meshes for vert in mesh.data.vertices)
    toy_top = max((toy_mesh.matrix_world @ vert.co).z for vert in toy_mesh.data.vertices if vert.groups)
    ratio = body_top / toy_top * PROP_BOOST
    meshes.append(rt.carry_props(toy_mesh, ("weapon",), source_rest["weapon"].translation, palm, ratio, armature, "Weapon",
                                 name=role.capitalize() + "Prop"))
    rt.retarget(source_rest, clips, armature, MAPPING, UPRIGHT, "hips")
    rt.export(os.path.join(out_dir, role + "_real.glb"), armature, meshes,
              os.path.join(blend_dir, role + "_real.blend") if blend_dir else None)


if __name__ == "__main__":
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
    out_dir = args[0]
    blend_dir = args[1] if len(args) > 1 else None
    for role in (args[2:] or ROLES):
        build(role, out_dir, blend_dir)
