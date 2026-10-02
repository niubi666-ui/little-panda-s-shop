"""Export the reviewed v008 character only; never save or modify the source blend.

Run with Blender background mode and --python-exit-code 1. Outputs are derived
candidates under the character exports directory, then copied to game/assets.
"""
from pathlib import Path
import argparse
import json
import math
import shutil
import struct
import sys

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "source_assets/characters/red_panda"
SOURCE = BASE / "blender/red_panda_run_v008.blend"
OUTPUT = BASE / "exports"
GAME_OUTPUT = ROOT / "game/assets/characters/red_panda"


def vector(value):
    return [round(float(x), 8) for x in value]


def inspect():
    report = {
        "source": str(SOURCE),
        "blender_version": bpy.app.version_string,
        "active_scene": bpy.context.scene.name,
        "scenes": [],
        "actions": [
            {"name": a.name, "frames": vector(a.frame_range)}
            for a in bpy.data.actions
        ],
    }
    for scene in bpy.data.scenes:
        report["scenes"].append({
            "name": scene.name,
            "objects": [{
                "name": o.name, "type": o.type,
                "location": vector(o.location),
                "rotation": vector(o.rotation_euler),
                "scale": vector(o.scale),
                "dimensions": vector(o.dimensions),
                "parent": o.parent.name if o.parent else None,
                "action": o.animation_data.action.name
                if o.animation_data and o.animation_data.action else None,
            } for o in scene.objects],
        })
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "red_panda_v008_source_inspection.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


def bounds(mesh):
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.to_mesh()
    points = [evaluated.matrix_world @ v.co for v in data.vertices]
    evaluated.to_mesh_clear()
    minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return {"minimum": vector(minimum), "maximum": vector(maximum),
            "dimensions": vector(maximum - minimum)}


def aim_bone(rig, name, child_name, direction):
    bone = rig.pose.bones[name]
    current = rig.pose.bones[child_name].head - bone.head
    rotation = current.normalized().rotation_difference(Vector(direction).normalized())
    transform = bone.matrix.copy()
    location = transform.translation.copy()
    transform = rotation.to_matrix().to_4x4() @ transform
    transform.translation = location
    bone.matrix = transform
    bpy.context.view_layer.update()


def bind_action(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = action
    # Blender 4.4+ layered actions retain their original object slot name.
    # A renamed export copy needs an explicit binding to evaluate the action.
    if action is not None and len(action.slots):
        rig.animation_data.action_slot = action.slots[0]


def render_previews(scene, rig, run, idle):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("ExportPreviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.17, 0.19, 0.23, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4
    camera = bpy.data.objects.new("ExportPreviewCamera", bpy.data.cameras.new("ExportPreviewCamera"))
    scene.collection.objects.link(camera)
    camera.location = (3.6, -4.1, 2.6)
    camera.rotation_euler = (Vector((0, 0, 0.48)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.45
    scene.camera = camera
    for name, position, energy, size in (("Key", (2, -3, 4), 450, 4), ("Fill", (-2, 1, 3), 220, 3)):
        lamp = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        lamp.location = position
        lamp.rotation_euler = (Vector((0, 0, 0.5)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
        lamp.data.energy = energy
        lamp.data.shape = "DISK"
        lamp.data.size = size
        scene.collection.objects.link(lamp)
    for name, action, frame in (("idle", idle, 1), ("run", run, 7)):
        bind_action(rig, action)
        scene.frame_set(frame)
        scene.render.filepath = str(OUTPUT / ("red_panda_v008_" + name + "_preview.png"))
        bpy.ops.render.render(write_still=True)


def export_character(previews=False):
    source_scene = bpy.data.scenes["RedPanda_Run_v008"]
    bpy.context.window.scene = source_scene
    source_scene.frame_set(1)
    original_rig = source_scene.objects["RedPanda_RunRig_v008"]
    original_mesh = source_scene.objects["RedPanda_RunMesh_v008"]
    original_run = original_rig.animation_data.action
    report = {
        "source": str(SOURCE), "blender_version": bpy.app.version_string,
        "original_vertex_count": len(original_mesh.data.vertices),
        "original_polygon_count": len(original_mesh.data.polygons),
        "original_bone_count": len(original_rig.data.bones),
        "source_mesh_parent": original_mesh.parent.name if original_mesh.parent else None,
        "source_run_action": original_run.name,
        "source_bounds_frame_1": bounds(original_mesh),
        "source_forward": "+X", "gltf_forward": "+X",
        "gltf_up": "+Y", "source_geometry_scale_modified": False,
    }
    export_scene = bpy.data.scenes.new("RedPanda_Runtime_v008")
    export_scene.render.fps = 30
    export_scene.frame_start = 1
    export_scene.frame_end = 31
    rig = original_rig.copy()
    rig.data = original_rig.data.copy()
    rig.animation_data_clear()
    rig.name = "RedPandaRig"
    mesh = original_mesh.copy()
    mesh.data = original_mesh.data.copy()
    mesh.name = "RedPandaMesh"
    export_scene.collection.objects.link(rig)
    export_scene.collection.objects.link(mesh)
    mesh_world = original_mesh.matrix_world.copy()
    mesh.parent = rig
    mesh.matrix_world = mesh_world
    for modifier in mesh.modifiers:
        if modifier.type == "ARMATURE":
            modifier.object = rig
    bpy.context.window.scene = export_scene
    # Only the new rig's actions are published, never historical review actions.
    run = original_run.copy()
    run.name = "run"
    run.use_fake_user = True
    bind_action(rig, run)
    export_scene.frame_set(1)
    bpy.context.view_layer.update()
    tail_pose = {b.name: b.matrix_basis.copy() for b in rig.pose.bones
                 if b.name.startswith("Tail_")}
    report["export_bounds_run_frame_1"] = bounds(mesh)
    run_samples = []
    for frame in range(1, 26):
        export_scene.frame_set(frame)
        run_samples.append({"frame": frame, "bounds": bounds(mesh),
                            "root": vector(rig.pose.bones["Root"].location)})
    report["run_bounds_samples"] = run_samples
    if len({tuple(s["root"]) for s in run_samples}) < 2:
        raise RuntimeError("Run action is not evaluating on the export skeleton")

    # Create a neutral held pose on the revised skeleton. This is deliberately
    # an idle placeholder, not a retargeted or artist-approved idle animation.
    bind_action(rig, None)
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.matrix_basis = Matrix.Identity(4)
    for name, pose in tail_pose.items():
        rig.pose.bones[name].matrix_basis = pose
    bpy.context.view_layer.update()
    for side, side_sign in (("L", 1), ("R", -1)):
        aim_bone(rig, side + "_Upperarm", side + "_Forearm", (0.025, side_sign * 0.18, -1))
        aim_bone(rig, side + "_Forearm", side + "_Hand", (0.06, side_sign * 0.10, -1))
    floor = bounds(mesh)["minimum"][2]
    root = rig.pose.bones["Root"]
    root_transform = root.matrix.copy()
    root_transform.translation.z -= floor
    root.matrix = root_transform
    bpy.context.view_layer.update()
    neutral_pose = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy())
                    for b in rig.pose.bones}
    for frame in (1, 31):
        export_scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.location, bone.rotation_quaternion, bone.scale = neutral_pose[bone.name]
            for channel in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(data_path=channel, frame=frame)
    idle = rig.animation_data.action
    idle.name = "idle"
    idle.use_fake_user = True
    export_scene.frame_set(1)
    report["idle_bounds"] = bounds(mesh)
    report["suggested_uniform_scale_for_height_1_2m"] = round(1.2 / report["idle_bounds"]["dimensions"][2], 8)
    report["idle_is_static_placeholder"] = True
    report["bone_names"] = [b.name for b in rig.data.bones]
    report["materials"] = [m.name for m in mesh.data.materials if m]
    for action in list(bpy.data.actions):
        if action not in (run, idle):
            bpy.data.actions.remove(action)
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "red_panda_v008.glb"
    result = bpy.ops.export_scene.gltf(
        filepath=str(target), export_format="GLB", use_selection=True,
        use_active_scene=True, export_yup=True, export_cameras=False,
        export_lights=False, export_animations=True,
        export_animation_mode="ACTIONS", export_frame_range=False,
        export_force_sampling=True, export_frame_step=1,
        export_anim_slide_to_zero=True, export_optimize_animation_size=False,
        export_skins=True, export_all_influences=True, export_apply=False,
        export_extras=False,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF export failed: {result}")
    payload = target.read_bytes()
    length, kind = struct.unpack_from("<II", payload, 12)
    if kind != 0x4E4F534A:
        raise RuntimeError("GLB JSON chunk missing")
    gltf = json.loads(payload[20:20 + length])
    report["gltf_summary"] = {
        "file_bytes": len(payload),
        "meshes": len(gltf.get("meshes", [])),
        "skins": len(gltf.get("skins", [])),
        "nodes": len(gltf.get("nodes", [])),
        "animations": [{"name": a["name"], "channels": len(a["channels"])}
                       for a in gltf.get("animations", [])],
        "images": len(gltf.get("images", [])),
        "external_image_uris": [i["uri"] for i in gltf.get("images", []) if "uri" in i],
    }
    animation_names = {a["name"] for a in gltf.get("animations", [])}
    if animation_names != {"idle", "run"}:
        raise RuntimeError(f"Unexpected exported actions: {animation_names}")
    if len(gltf.get("skins", [])) != 1 or len(gltf.get("meshes", [])) != 1:
        raise RuntimeError("Character GLB must contain exactly one mesh and one skin")
    if report["gltf_summary"]["external_image_uris"]:
        raise RuntimeError("Character GLB contains external texture references")
    GAME_OUTPUT.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, GAME_OUTPUT / target.name)
    (OUTPUT / "red_panda_v008_export_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k not in ("run_bounds_samples", "bone_names")},
                     indent=2, ensure_ascii=False))
    if previews:
        render_previews(export_scene, rig, run, idle)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--previews", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if args.inspect:
        inspect()
        return
    export_character(previews=args.previews)


if __name__ == "__main__":
    main()
