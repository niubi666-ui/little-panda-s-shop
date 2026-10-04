"""Inspect real exported glTF buffers, skinning, and animation data."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

parser = argparse.ArgumentParser()
parser.add_argument('asset', type=Path)
parser.add_argument('--report', type=Path, required=True)
args = parser.parse_args()
raw = args.asset.read_bytes()
magic, version, declared = struct.unpack_from('<4sII', raw)
assert magic == b'glTF' and version == 2 and declared == len(raw)
chunks = {}
offset = 12
while offset < len(raw):
    length, kind = struct.unpack_from('<II', raw, offset)
    offset += 8
    chunks[kind] = raw[offset:offset + length]
    offset += length
doc = json.loads(chunks[0x4E4F534A])
binary = chunks.get(0x004E4942, b'')
assert doc.get('asset', {}).get('version') == '2.0'
assert doc.get('meshes') and doc.get('skins'), 'Missing mesh or real skeleton'
assert len(doc.get('animations', [])) >= 3, 'Missing required animation clips'

types = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
components = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2),
              5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}

def values(index):
    accessor = doc['accessors'][index]
    assert 'sparse' not in accessor, 'Sparse accessor needs an explicit audit path'
    view = doc['bufferViews'][accessor['bufferView']]
    assert view.get('buffer', 0) == 0
    fmt, width = components[accessor['componentType']]
    size = types[accessor['type']]
    stride = view.get('byteStride', size * width)
    start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * size, binary, start + n * stride)
            for n in range(accessor['count'])]

skin_nodes = [n for n in doc['nodes'] if 'skin' in n and 'mesh' in n]
assert skin_nodes, 'No mesh is actually attached to a skin'
weighted_vertices = 0
triangles = 0
for node in skin_nodes:
    skin = doc['skins'][node['skin']]
    assert len(skin['joints']) >= 15, 'Insufficient humanoid skeleton'
    for primitive in doc['meshes'][node['mesh']]['primitives']:
        attributes = primitive['attributes']
        assert 'JOINTS_0' in attributes and 'WEIGHTS_0' in attributes
        weights = values(attributes['WEIGHTS_0'])
        joints = values(attributes['JOINTS_0'])
        assert len(weights) == len(joints)
        normalized = doc['accessors'][attributes['WEIGHTS_0']].get('normalized', False)
        ct = doc['accessors'][attributes['WEIGHTS_0']]['componentType']
        factor = (255 if ct == 5121 else 65535) if normalized else 1
        for weight, joint in zip(weights, joints):
            assert all(math.isfinite(x) and x >= 0 for x in weight)
            assert abs(sum(weight) / factor - 1) < .025, 'Bad skin weight sum'
            assert all(0 <= j < len(skin['joints']) for j, w in zip(joint, weight) if w)
        weighted_vertices += len(weights)
for mesh in doc['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode', 4) == 4, 'Unexpected non-triangle geometry'
        count = doc['accessors'][primitive['indices']]['count'] if 'indices' in primitive else doc['accessors'][primitive['attributes']['POSITION']]['count']
        triangles += count // 3

clips = []
for animation in doc['animations']:
    samplers = animation['samplers']
    assert animation['channels']
    duration = 0
    animated_nodes = set()
    for channel in animation['channels']:
        sampler = samplers[channel['sampler']]
        times = [x[0] for x in values(sampler['input'])]
        assert len(times) >= 2 and times[-1] > times[0]
        assert abs(times[0]) < 1e-6, 'Exported clip does not start at zero'
        assert all(math.isfinite(x) and x >= 0 for x in times)
        assert all(a <= b for a, b in zip(times, times[1:]))
        assert all(math.isfinite(x) for row in values(sampler['output']) for x in row)
        duration = max(duration, times[-1])
        animated_nodes.add(channel['target']['node'])
    clips.append({'name': animation.get('name'), 'duration_seconds': duration,
                  'channels': len(animation['channels']), 'animated_nodes': len(animated_nodes)})
expected_lengths = {'Idle': 3.0, 'Run': .8, 'Attack': 1.55, 'Hit': .28}
assert set(c['name'] for c in clips) == set(expected_lengths)
assert all(abs(c['duration_seconds'] - expected_lengths[c['name']]) < 1e-5 for c in clips)
report = {'file': args.asset.name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
          'triangles': triangles, 'meshes': len(doc['meshes']), 'materials': len(doc.get('materials', [])),
          'embedded_images': len(doc.get('images', [])), 'skins': len(doc['skins']),
          'joint_counts': [len(s['joints']) for s in doc['skins']],
          'skinned_mesh_nodes': len(skin_nodes), 'weighted_vertices': weighted_vertices,
          'clips': clips, 'result': 'PASS'}
args.report.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
