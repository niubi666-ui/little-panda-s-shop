"""Move the hand-authored combat clips from a toy rig onto a realistic, skinned model.

The toy characters (source_assets/combat_visual_v1) carry the whole move set: clips that
were tuned against the combat timing. A realistic model usually arrives with an idle and a
run at best. This script copies the clips across, so swapping the model does not mean
re-authoring the moves.

How a pose is carried over
    Both characters are stood facing Blender -Y. For every mapped bone the source pose is
    read as a rotation away from its rest pose, measured in world axes ("the upper arm swung
    60 degrees forward"). The same world rotation is applied to the target bone. Limbs first
    get a fixed correction that brings the target's rest direction (a T-pose, say) onto the
    source's rest direction (arms hanging), so that "no rotation" means the same stance on
    both. Bones that are not mapped (twist bones, extra spine joints) keep their rest pose
    relative to their parent. The hips also take the source's travel, scaled by hip height.

Run through a character script (build_panda.py, build_enemies.py) that fills in the names.
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

FPS = 60


# ------------------------------------------------------------------------------------------------
# Source: the toy rig and its clips
# ------------------------------------------------------------------------------------------------
def open_source(blend_path):
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    return armature


def read_clips(armature, names=None):
    """{clip: [ {bone: 4x4 pose matrix in armature space} per frame ]}"""
    scene = bpy.context.scene
    data = armature.animation_data
    clips = {}
    for action in list(bpy.data.actions):
        if names is not None and action.name not in names:
            continue
        data.action = action
        if hasattr(data, "action_slot") and len(action.slots):
            data.action_slot = action.slots[0]
        first, last = int(action.frame_range[0]), int(round(action.frame_range[1]))
        frames = []
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            frames.append({bone.name: bone.matrix.copy() for bone in armature.pose.bones})
        clips[action.name] = frames
    data.action = None
    scene.frame_set(0)
    return clips


def rest_matrices(armature):
    return {bone.name: bone.matrix_local.copy() for bone in armature.data.bones}


# ------------------------------------------------------------------------------------------------
# Target: the realistic model
# ------------------------------------------------------------------------------------------------
def import_target(glb_path, turn_deg, drop=()):
    """Import the model and turn it to face -Y. Returns (armature, [meshes])."""
    before = set(bpy.data.objects)
    stale_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    new = [o for o in bpy.data.objects if o not in before]
    armature = next(o for o in new if o.type == "ARMATURE")
    meshes = []
    for obj in new:
        if obj.type == "MESH" and (obj.name in drop or obj.parent is None and obj.find_armature() is None):
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "MESH":
            meshes.append(obj)
    # the model's own clips are replaced by the retargeted set
    if armature.animation_data is not None:
        armature.animation_data.action = None
        for track in list(armature.animation_data.nla_tracks):
            armature.animation_data.nla_tracks.remove(track)
    for action in list(bpy.data.actions):
        if action not in stale_actions:
            bpy.data.actions.remove(action)
    top = armature
    while top.parent is not None:
        top = top.parent
    top.rotation_mode = "XYZ"
    top.rotation_euler.z += math.radians(turn_deg)
    bpy.context.view_layer.update()
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
    return armature, meshes


def add_bone(armature, name, parent, head_world, rotation_world, length):
    """A new bone given in world space: head position, 3x3 orientation (Y = along the bone)."""
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    inverse = armature.matrix_world.inverted()
    scale = armature.matrix_world.to_scale().x
    bone = armature.data.edit_bones.new(name)
    bone.parent = armature.data.edit_bones[parent]
    bone.use_connect = False
    local = (inverse.to_3x3().normalized() @ rotation_world).to_4x4()
    bone.head = (0, 0, 0)
    bone.tail = (0, length / scale, 0)
    bone.matrix = Matrix.Translation(inverse @ head_world) @ local
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.pose.bones[name].rotation_mode = "QUATERNION"


def bind_rigid(obj, armature, bone_name):
    """Skin a prop wholly to one bone."""
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.matrix_world = world
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature


def carry_props(source_mesh, bone_names, source_anchor, target_anchor, ratio, armature, target_bone, name="Props"):
    """Lift the parts of a toy mesh that ride on the given bones (a crossbow, a banner pole)
    and hang them on a bone of the target. The toy is a segmented model, so these parts are
    separate shells; they keep their vertex colours."""
    import bmesh
    groups = {source_mesh.vertex_groups[n].index for n in bone_names if n in source_mesh.vertex_groups}
    mesh = source_mesh.data.copy()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    layer = bm.verts.layers.deform.verify()
    drop = []
    for vert in bm.verts:
        weights = vert[layer]
        top = max(weights.items(), key=lambda item: item[1])[0] if len(weights) else -1
        if top not in groups:
            drop.append(vert)
        else:
            vert.co = target_anchor + (source_mesh.matrix_world @ vert.co - source_anchor) * ratio
            weights.clear()
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.vertex_groups.clear()
    material = bpy.data.materials.new(name + "Paint")
    material.use_nodes = True
    surface = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    paint = material.node_tree.nodes.new("ShaderNodeVertexColor")
    if mesh.color_attributes.active_color is not None:
        paint.layer_name = mesh.color_attributes.active_color.name
    material.node_tree.links.new(paint.outputs["Color"], surface.inputs["Base Color"])
    surface.inputs["Roughness"].default_value = 0.7
    mesh.materials.clear()
    mesh.materials.append(material)
    bind_rigid(obj, armature, target_bone)
    return obj

def retarget(source_rest, clips, armature, mapping, upright, hips, loops=()):
    """mapping: {source bone: target bone}. upright: source bones copied without the rest
    correction (root, hips, spine, head). hips: source hips bone name."""
    world = armature.matrix_world
    world_rot = world.to_3x3().normalized()
    unit = world.to_scale().x
    bones = list(armature.data.bones)                       # parents come first
    rest = {bone.name: (world_rot @ bone.matrix_local.to_3x3()) for bone in bones}
    source_rot = {name: matrix.to_3x3() for name, matrix in source_rest.items()}
    back = {target: source for source, target in mapping.items()}
    correction = {}
    for source, target in mapping.items():
        if source in upright:
            correction[target] = Matrix.Identity(3)
        else:
            want = source_rot[source].col[1].normalized()
            have = rest[target].col[1].normalized()
            correction[target] = have.rotation_difference(want).to_matrix()
    hips_target = mapping[hips]
    hips_bone = armature.data.bones[hips_target]
    ratio = (world @ hips_bone.head_local).z / source_rest[hips].translation.z
    armature.animation_data_create()
    made = []
    for name, frames in clips.items():
        action = bpy.data.actions.new(name)
        armature.animation_data.action = action
        last = {}
        for frame, pose in enumerate(frames):
            posed = {}
            for bone in bones:
                parent = bone.parent.name if bone.parent else None
                if bone.name in back:
                    source = back[bone.name]
                    delta = pose[source].to_3x3().normalized() @ source_rot[source].inverted()
                    posed[bone.name] = delta @ correction[bone.name] @ rest[bone.name]
                elif parent is not None:
                    posed[bone.name] = posed[parent] @ rest[parent].inverted() @ rest[bone.name]
                else:
                    posed[bone.name] = rest[bone.name]
                frame_of_bone = (posed[parent] @ rest[parent].inverted() @ rest[bone.name]) if parent else rest[bone.name]
                quat = (frame_of_bone.inverted() @ posed[bone.name]).to_quaternion()
                previous = last.get(bone.name)
                if previous is not None and previous.dot(quat) < 0.0:
                    quat.negate()
                last[bone.name] = quat.copy()
                pose_bone = armature.pose.bones[bone.name]
                pose_bone.rotation_quaternion = quat
                if bone.name == hips_target:
                    travel = (pose[hips].translation - source_rest[hips].translation) * ratio
                    pose_bone.location = frame_of_bone.inverted() @ travel / unit
                    pose_bone.keyframe_insert("location", frame=frame)
                pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
        armature.animation_data.action = None
        track = armature.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        if hasattr(strip, "action_slot") and strip.action_slot is None and len(action.slots):
            strip.action_slot = action.slots[0]
        strip.name = name
        track.mute = True
        made.append(name)
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_quaternion = (1, 0, 0, 0)
        pose_bone.location = (0, 0, 0)
    print("RETARGET clips:", ", ".join(made), "| hip ratio %.2f" % ratio)


def export(path, armature, meshes, blend_path=None):
    if blend_path:
        os.makedirs(os.path.dirname(blend_path), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.object.select_all(action="DESELECT")
    top = armature
    while top.parent is not None:
        top = top.parent
    for obj in [top, armature] + list(meshes):
        obj.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_yup=True,
        export_animations=True, export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
        export_force_sampling=True, export_optimize_animation_size=False, export_skins=True,
        export_def_bones=False, export_materials="EXPORT", export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("EXPORTED", path)
