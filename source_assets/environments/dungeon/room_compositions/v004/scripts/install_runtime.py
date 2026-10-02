"""Publish the export's measured geometry as presentation Resources.
Gameplay values are explicitly inherited from the existing JSON content definitions.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[6]
BASE=ROOT/'source_assets/environments/dungeon/room_compositions/v004'
DATA=ROOT/'game/data/rooms/props_prototype.json'
report=json.loads((BASE/'reports/runtime_export.json').read_text(encoding='utf-8'))
data=json.loads(DATA.read_text(encoding='utf-8'))
old={p['id']:p for p in data['props']}
# Re-running remains possible after the active catalog has been narrowed.
templates={kind:next(p for p in old.values() if p['kind']==kind) for kind in ('obstacle','destructible','searchable')}
def write(path,text):path.write_text(text,encoding='utf-8')
def vec(values):return 'Vector3('+', '.join(format(v,'.8f') for v in values)+')'
root=ROOT/'game/presentation/rooms'
write(root/'compositions/physics_only.tscn','[gd_scene format=3]\n\n[node name="PhysicsOnly" type="Node3D"]\n')
resource=['[gd_resource type="Resource" format=3]',
 '[ext_resource type="Script" path="res://presentation/rooms/props/prop_set.gd" id="set"]',
 '[ext_resource type="Script" path="res://presentation/rooms/props/prop_visual.gd" id="visual"]',
 '[ext_resource type="PackedScene" path="res://presentation/rooms/compositions/physics_only.tscn" id="physics"]']
sub=[];entries=[];defs=[]
for preset in report['compositions']:
 cid=preset['id']
 resource.append(f'[ext_resource type="Resource" path="res://presentation/rooms/compositions/{cid}.tres" id="{cid}"]')
 composition=['[gd_resource type="Resource" format=3]',
 '[ext_resource type="Script" path="res://rogue/rooms/composition.gd" id="preset"]',
 '[ext_resource type="Script" path="res://rogue/rooms/composition_member.gd" id="member"]',
 f'[ext_resource type="PackedScene" path="res://assets/environments/room_compositions_v004/{cid}.glb" id="art"]']
 mids=[]
 for i,m in enumerate(preset['members']):
  pid=m['prop_id'];mid='m'+str(i);mids.append(f'SubResource("{mid}")');entries.append(f'SubResource("{pid}")')
  kind='searchable' if pid=='chest1' else 'destructible' if m['interactive'] else 'obstacle'
  definition=dict(templates[kind]);definition['id']=pid
  definition['name_key']='room.prop.chest1' if kind=='searchable' else 'room.prop.barrel' if 'barrel' in pid else 'room.prop.crate' if kind=='destructible' else 'room.prop.stone_wall'
  defs.append(definition)
  if m['interactive']:
   resource.append(f'[ext_resource type="PackedScene" path="res://assets/environments/room_compositions_v004/{pid}.glb" id="{pid}"]')
  scene=pid if m['interactive'] else 'physics'
  sub.extend([f'[sub_resource type="Resource" id="{pid}"]','script = ExtResource("visual")',f'id = "{pid}"',f'scene = ExtResource("{scene}")','bounds = '+vec(m['bounds'])])
  composition.extend([f'[sub_resource type="Resource" id="{mid}"]','script = ExtResource("member")',f'id = "{m["id"]}"',f'prop_id = "{pid}"','position = '+vec(m['position']),'yaw_radians = 0.0'])
 composition.extend(['[resource]','script = ExtResource("preset")',f'id = "{cid}"','members = Array[Resource](['+', '.join(mids)+'])','decoration = ExtResource("art")'])
 write(root/f'compositions/{cid}.tres','\n'.join(composition)+'\n')
resource.extend(sub)
resource.extend(['[resource]','script = ExtResource("set")','entries = Array[Resource](['+', '.join(entries)+'])','compositions = Array[Resource](['+', '.join(f'ExtResource("{p["id"]}")' for p in report['compositions'])+'])'])
write(root/'props/forest_props.tres','\n'.join(resource)+'\n')
data['props']=defs;data['content_version']='room-presets.4'
write(DATA,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('Installed approved art:',len(report['compositions']),'compositions,',len(defs),'physical members')
