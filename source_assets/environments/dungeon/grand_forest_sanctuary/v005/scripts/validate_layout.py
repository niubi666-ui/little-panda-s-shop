"""Read the loaded v005 blend and write reports/validation.json only.

Run with Blender --background <v005.blend> --python validate_layout.py.
No objects, meshes, frames, settings or blend files are changed by this script.
The route check is a trunk/roots surface-intersection check, not Godot navigation.
"""
import hashlib
import json
import math
import re
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[4]
PROFILE_PATH = ROOT / 'scripts/layout_profile.json'
REPORT_PATH = ROOT / 'reports/validation.json'
PROFILE = json.loads(PROFILE_PATH.read_text(encoding='utf-8'))
BUILD = json.loads((ROOT / 'reports/layout_revision.json').read_text(encoding='utf-8'))
SCENE = bpy.context.scene
CHECKS = []
EPS = 1e-4


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def check(name, function):
    """Record independent failures so a report survives a missing scene object."""
    try:
        passed, details = function()
        CHECKS.append({'name': name, 'passed': bool(passed), 'details': details})
    except Exception as error:
        CHECKS.append({'name': name, 'passed': False, 'error': str(error),
                       'traceback': traceback.format_exc()})


def required(name):
    obj = SCENE.objects.get(name)
    if obj is None:
        raise ValueError('Missing object: ' + name)
    return obj


def bounds(points):
    points = list(points)
    if not points:
        raise ValueError('Cannot measure empty geometry')
    return [[min(p[k] for p in points), max(p[k] for p in points)] for k in range(3)]


def world_bounds(obj):
    return bounds(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)


def hidden(obj):
    return bool(obj.hide_render and obj.hide_get())


def angle_error(a, b):
    return abs((a - b + math.pi) % math.tau - math.pi)


def rigid_map(old, new, angle):
    return (Matrix.Translation(Vector(new)) @ Matrix.Rotation(angle, 4, 'Z')
            @ Matrix.Translation(-Vector(old)))


def provenance():
    expected_output = ROOT / 'blender/grand_forest_sanctuary_v005_layout.blend'
    source = Path(PROFILE['source'])
    actual_hash = sha256(source)
    values = {
        'background': bool(bpy.app.background),
        'loaded_blend': bpy.data.filepath,
        'expected_blend': str(expected_output),
        'source': str(source),
        'source_sha256_actual': actual_hash,
        'source_sha256_build_report': BUILD['source_sha256'],
        'source_sha256_scene': SCENE.get('layout_source_sha256'),
        'profile_matches_build_report': PROFILE == BUILD['profile'],
    }
    valid = (values['background']
             and Path(bpy.data.filepath).resolve() == expected_output.resolve()
             and Path(BUILD['output']).resolve() == expected_output.resolve()
             and Path(BUILD['source']).resolve() == source.resolve()
             and actual_hash == BUILD['source_sha256'] == SCENE.get('layout_source_sha256')
             and values['profile_matches_build_report'])
    return valid, values


def forest_hidden():
    roots = [required('Forest_oak_' + str(i)) for i in range(12)]
    exact_roots = [o for o in SCENE.objects if re.fullmatch(r'Forest_oak_\d+', o.name)]
    descendants = {child for root in roots for child in root.children_recursive}
    offenders = [o.name for o in set(roots) | descendants if not hidden(o)]
    unparented_parts = [o.name for o in SCENE.objects
                        if o.name.startswith('Forest_oak_') and '__' in o.name
                        and o not in descendants]
    children_per_root = {root.name: len(root.children_recursive) for root in roots}
    return (len(exact_roots) == 12 and all(n == 62 for n in children_per_root.values())
            and not offenders and not unparented_parts), {
                'roots': len(exact_roots), 'descendants': len(descendants),
                'children_per_root': children_per_root,
                'not_hidden_in_both_viewport_and_render': offenders,
                'parts_without_expected_parent': unparented_parts,
            }


def old_tree_walls_hidden():
    prefixes = ('Boundary_3_', 'Boundary_4_',
                'West_lower_course', 'West_lower_pier',
                'West_upper_course', 'West_upper_pier')
    counts = {prefix: 0 for prefix in prefixes}
    offenders = []
    for obj in SCENE.objects:
        for prefix in prefixes:
            if obj.name.startswith(prefix):
                counts[prefix] += 1
                if not hidden(obj):
                    offenders.append(obj.name)
    return all(counts.values()) and not offenders, {
        'matched_objects_per_prefix': counts, 'not_hidden': offenders,
    }


def gate_transform():
    matrix = rigid_map((17.4, 9.75, 0), PROFILE['gate_location'],
                       math.radians(PROFILE['gate_angle_degrees']))
    originals = [(17.4, 6.35, .03), (17.4, 13.15, .03)]
    pillars = [required('East_gateway_tall_pillar_' + str(i)) for i in range(2)]
    positions = [o.matrix_world.translation.copy() for o in pillars]
    location_errors = [(positions[i] - matrix @ Vector(p)).length
                       for i, p in enumerate(originals)]
    distance = (positions[1] - positions[0]).length
    yaws = [o.matrix_world.to_euler().z for o in pillars]
    yaw_errors = [angle_error(yaw, math.radians(PROFILE['gate_angle_degrees'])) for yaw in yaws]
    return abs(distance - 6.8) < EPS and max(location_errors + yaw_errors) < EPS, {
        'centres_m': [list(p) for p in positions], 'centre_spacing_m': distance,
        'expected_centre_spacing_m': 6.8, 'position_errors_m': location_errors,
        'world_yaw_degrees': [math.degrees(yaw) for yaw in yaws],
    }


def shrine_transform():
    yaw = math.radians(PROFILE['shrine_angle_degrees'])
    matrix = rigid_map((0, 13.45, 0), PROFILE['shrine_location'], yaw)
    original_locations = {
        'North_Guardian_Shrine': (0, 13.45, .02),
        'Shrine_recess_stone_back': (0, 14.05, 3),
        'Robed_Guardian': (0, 12.94, .67),
        'Shrine_approach_steps': (0, 11.97, -.12),
    }
    records = []
    for name, origin in original_locations.items():
        obj = required(name)
        actual_yaw = obj.matrix_world.to_euler().z
        records.append({'object': name,
                        'location_error_m': (obj.matrix_world.translation - matrix @ Vector(origin)).length,
                        'world_yaw_degrees': math.degrees(actual_yaw),
                        'yaw_error_radians': angle_error(actual_yaw, yaw)})
    valid = all(max(r['location_error_m'], r['yaw_error_radians']) < EPS for r in records)
    return valid, {'expected_yaw_degrees': PROFILE['shrine_angle_degrees'], 'objects': records}


def player_scale():
    visual_path = PROJECT / 'game/presentation/combat/player_visual.tscn'
    visual = visual_path.read_text(encoding='utf-8')
    match = re.search(r'^scale\s*=\s*Vector3\(([^)]+)\)', visual, re.MULTILINE)
    if match is None:
        raise ValueError('Current player visual has no explicit scale')
    game_scale = [float(part.strip()) for part in match.group(1).split(',')]
    authoring_path = ROOT.parent / 'v002/scripts/player_reference.py'
    authoring = authoring_path.read_text(encoding='utf-8')
    match = re.search(r'player_root\.scale\s*=\s*\(([0-9.]+),\)\s*\*\s*3', authoring)
    if match is None:
        raise ValueError('Cannot read the existing preview actor scale without executing its authoring script')
    reference_scale = float(match.group(1))
    meshes = [o for o in SCENE.objects if o.type == 'MESH' and o.name.startswith('Player_reference_')]
    body_bounds = bounds(o.matrix_world @ v.co for o in meshes for v in o.data.vertices)
    actual_height = body_bounds[2][1] - body_bounds[2][0]
    recorded_height = float(SCENE['player_height_m'])
    original_build = json.loads((ROOT.parent / 'v002/reports/build_report.json').read_text(encoding='utf-8'))
    source_height = float(original_build['player_height_m'])
    valid = (bool(meshes) and all(abs(scale - reference_scale) < 1e-7 for scale in game_scale)
             and abs(actual_height - recorded_height) < EPS
             and abs(actual_height - source_height) < EPS
             and 'res://assets/characters/red_panda/red_panda_v008.glb' in visual)
    return valid, {
        'current_game_visual': str(visual_path), 'current_game_scale': game_scale,
        'preview_authoring_scale': reference_scale,
        'body_meshes': [o.name for o in meshes], 'body_world_bounds_m': body_bounds,
        'actual_height_m': actual_height, 'recorded_height_m': recorded_height,
        'original_preview_height_m': source_height,
        'world_scales': {o.name: list(o.matrix_world.to_scale()) for o in meshes},
        'weapon_excluded_from_height_measurement': True,
    }


def hero_transform_and_shared_trunk():
    hero = required('Hero_Sacred_Oak_v005')
    trunk = required('Hero_Sacred_Oak_v005__SacredOak_Trunk_Preserved')
    peers = [required('Forest_oak_' + str(i) + '__SacredOak_Trunk_Preserved') for i in range(12)]
    records = json.loads((ROOT.parent / 'v004/reports/breeze_source_inspection.json').read_text(encoding='utf-8'))
    source = next(r for r in records if r['object'] == trunk.name)
    local_bounds = bounds(vertex.co for vertex in trunk.data.vertices)
    bound_error = max(abs(local_bounds[k][side] - source['bbox'][k][side])
                      for k in range(3) for side in range(2))
    transform_error = max((Vector(source['location']) - trunk.location).length,
                          (Vector(source['scale']) - trunk.scale).length)
    sharing = all(other.data is trunk.data for other in peers)
    expected_scale = Vector((PROFILE['hero_scale'] * PROFILE['hero_width_multiplier'],
                             PROFILE['hero_scale'] * PROFILE['hero_width_multiplier'],
                             PROFILE['hero_scale']))
    hero_error = max((hero.location - Vector(PROFILE['hero_location'])).length,
                     (hero.scale - expected_scale).length,
                     angle_error(hero.rotation_euler.z, math.radians(PROFILE['hero_angle_degrees'])))
    world = world_bounds(trunk)
    valid = (trunk.parent == hero and sharing and bound_error < 1e-6
             and transform_error < EPS and hero_error < EPS)
    return valid, {
        'hero_scale': list(hero.scale), 'expected_hero_scale': list(expected_scale),
        'hero_transform_error': hero_error, 'trunk_mesh': trunk.data.name,
        'shared_with_all_12_retained_source_instances': sharing,
        'local_bounds_match_v004_inspection_error': bound_error,
        'authored_trunk_local_transform_error': transform_error,
        'vertex_count': len(trunk.data.vertices), 'polygon_count': len(trunk.data.polygons),
        'trunk_world_bounds_m': world, 'actual_trunk_height_m': world[2][1] - world[2][0],
        'scope': 'Shared source mesh identity and local bounds/transforms; no source blend is opened or modified. This is not a full cross-blend vertex hash comparison.',
    }


def built_route(points, step=2.0):
    """Reproduce the authoring route centreline without importing its writer."""
    points = [Vector((x, y, 0)) for x, y in points]
    dense = []
    for i in range(len(points) - 1):
        p0, p1, p2, p3 = points[max(0, i - 1)], points[i], points[i + 1], points[min(len(points) - 1, i + 2)]
        for j in range(40):
            t = j / 40
            dense.append((p1 * 2 + (-p0 + p2) * t
                          + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t * t
                          + (-p0 + p1 * 3 - p2 * 3 + p3) * t * t * t) * .5)
    dense.append(points[-1])
    output = [dense[0]]
    accumulated = 0
    for a, b in zip(dense, dense[1:]):
        accumulated += (b - a).length
        if accumulated >= step:
            output.append(b)
            accumulated = 0
    if (output[-1] - dense[-1]).length > .2:
        output.append(dense[-1])
    return output


def root_route_intersections():
    trunk = required('Hero_Sacred_Oak_v005__SacredOak_Trunk_Preserved')
    enabled_modifiers = [modifier.name for modifier in trunk.modifiers if modifier.show_render]
    if enabled_modifiers:
        raise ValueError('Static-trunk BVH cannot certify unapplied render modifiers: ' + ', '.join(enabled_modifiers))
    vertices = [trunk.matrix_world @ v.co for v in trunk.data.vertices]
    polygons = [tuple(p.vertices) for p in trunk.data.polygons]
    tree = BVHTree.FromPolygons(vertices, polygons, all_triangles=False, epsilon=1e-5)
    records = []
    z_min, z_max = .15, 1.5
    for key in ('west_lower_route', 'west_upper_route'):
        centreline = built_route(PROFILE[key])
        curtain_vertices, curtain_triangles = [], []
        for a, b in zip(centreline, centreline[1:]):
            base = len(curtain_vertices)
            curtain_vertices.extend(((a.x, a.y, z_min), (b.x, b.y, z_min),
                                     (b.x, b.y, z_max), (a.x, a.y, z_max)))
            curtain_triangles.extend(((base, base + 1, base + 2), (base, base + 2, base + 3)))
        curtain = BVHTree.FromPolygons(curtain_vertices, curtain_triangles,
                                      all_triangles=True, epsilon=1e-5)
        overlaps = tree.overlap(curtain)
        segment_ids = sorted({curtain_triangle // 2 for _, curtain_triangle in overlaps})
        records.append({
            'route': key, 'centreline': [list(p) for p in centreline],
            'surface_overlap_pairs': len(overlaps), 'intersecting_segment_count': len(segment_ids),
            'intersecting_segments': [{'segment': i, 'from': list(centreline[i]),
                                       'to': list(centreline[i + 1])} for i in segment_ids],
            'clear': not overlaps,
        })
    return all(record['clear'] for record in records), {
        'method': 'BVH overlap against the continuous vertical curtain along each authored route centreline.',
        'world_height_band_m': [z_min, z_max], 'routes': records,
        'scope': 'Only the hero trunk/roots surface is tested. No route width, character radius, ground support, other obstacles, collision layers or Godot navigation is certified. Open/non-manifold source geometry or a curtain fully enclosed in a solid can limit a surface-intersection test.',
    }


check('source_v004_sha_and_loaded_v005', provenance)
check('12_peripheral_tree_roots_and_all_descendants_hidden', forest_hidden)
check('old_tree_side_walls_hidden', old_tree_walls_hidden)
check('double_pillar_spacing_and_rigid_transform', gate_transform)
check('shrine_statue_and_steps_share_transform', shrine_transform)
check('current_protagonist_visual_scale', player_scale)
check('hero_transform_and_shared_source_trunk', hero_transform_and_shared_trunk)
check('root_route_centreline_height_band', root_route_intersections)

REPORT = {
    'validation_version': 1,
    'timestamp_utc': datetime.now(timezone.utc).isoformat(),
    'blender_version': bpy.app.version_string,
    'loaded_blend': bpy.data.filepath,
    'passed': all(item['passed'] for item in CHECKS),
    'passed_count': sum(item['passed'] for item in CHECKS),
    'check_count': len(CHECKS),
    'checks': CHECKS,
    'operation_scope': 'Scene and asset files read only; only this JSON report is written. No blend save, frame change, scene edit, rendering or Godot process.',
    'godot_navigation_certified': False,
}
REPORT_PATH.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding='utf-8')
print('V005_LAYOUT_VALIDATION', json.dumps({
    'passed': REPORT['passed'], 'report': str(REPORT_PATH),
    'failed_checks': [item['name'] for item in CHECKS if not item['passed']],
}, ensure_ascii=False), flush=True)
if not REPORT['passed']:
    sys.exit(1)
