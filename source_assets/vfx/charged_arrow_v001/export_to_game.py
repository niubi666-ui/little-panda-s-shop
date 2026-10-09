"""Copy the approved art, stripping standalone UI/models. Does not modify rules."""
from pathlib import Path
import re, shutil
HERE=Path(__file__).resolve().parent
GAME=HERE.parents[2]/'game'
SRC=HERE/'godot_demo/fx'
DST=GAME/'presentation/combat/fx/charged_arrow_v001'
DST.mkdir(parents=True,exist_ok=True)
prefix='res://presentation/combat/fx/charged_arrow_v001/'
files=['lightseeker.gd','rift.gd','rift_curtain.gdshader','rift_source.gdshader','rift_stone.gdshader','ground.gdshader','ribbon.gdshader','sigil.gdshader','flare.gdshader','mote.gdshader','wet_paving.gdshader','rift_underlay.gdshader','rift_water.gdshader']
fields=set()
for name in ['lightseeker.gd','rift.gd']:
 fields.update(re.findall(r'art\.(\w+)',(SRC/name).read_text(encoding='utf-8')))
fields.discard('validate');fields.discard('get');fields.update(['charge_sound','fire_sound','pulse_sound'])
for name in files:
 text=(SRC/name).read_text(encoding='utf-8').replace('res://fx/',prefix)
 if name=='lightseeker.gd':
  text=text.replace('art.validate()','art.validate()')
  text=text.replace('if enabled: voices.charge.play()','if enabled and rules.fire_time < 0.0: voices.charge.play()')
  text=text.replace('fired and age <= flight_sec','fired and not rules.flight_finished')
  text=text.replace('var flying :=','var flying: bool =')
  text=text.replace('age-flight_sec','age-rules.flight_end_age')
  text=text.replace('rules.direction * rules.config.skill.range_m * (float(i)+0.5)/ground_lights.size()', 'rules.direction * travel * (float(i)+0.5)/ground_lights.size()')
  text=text.replace('if enabled: voices.fire.play()','if enabled: voices.fire.play()')
  text=text.replace('point.y = lerpf(rules.origin.y, art.flight_height_m, minf(1.0,distance_m/art.launch_blend_m))','point.y = rules.ground_height + lerpf(rules.origin.y-rules.ground_height, art.flight_height_m, minf(1.0,distance_m/art.launch_blend_m))')
 if name=='rift.gd':
  text=text.replace('Vector3(rules.origin.x,0,rules.origin.z)','Vector3(rules.origin.x,rules.ground_height,rules.origin.z)')
  text=text.replace('Basis(rules.direction,Vector3.UP,rules.direction.cross(Vector3.UP)).scaled(Vector3(1,1,life))','Basis(rules.direction,Vector3.UP,rules.direction.cross(Vector3.UP)*life)')
 (DST/name).write_text(text,encoding='utf-8')
exports=[]
for line in (SRC/'profile.gd').read_text(encoding='utf-8').splitlines():
 if line.startswith('@export var ') and line.split()[2].rstrip(':') in fields:exports.append(line)
script='extends Resource\n'+'\n'.join(exports)+'\n\nfunc validate() -> void:\n'
for line in exports:
 name=line.split()[2].rstrip(':');typ=line.split(':',1)[1].strip()
 if typ in ['PackedScene','ShaderMaterial','Material','AudioStream']:script+=f'\tassert({name} != null,"Missing charged art: {name}")\n'
script+='\tassert(rift_station_count>1 and rift_vertical_segments>1 and rift_height_m.x>0)\n'
(DST/'profile.gd').write_text(script,encoding='utf-8')
lines=(SRC/'profile.tres').read_text(encoding='utf-8').splitlines();result=[]
for line in lines:
 if line.startswith('[gd_resource'):continue
 if line.startswith('[ext_resource'):
  name=re.search(r'id="(.*?)"',line).group(1)
  if name!='script' and name not in fields:continue
 elif ' = ' in line and line.split(' = ')[0] not in fields|{'script'}:continue
 line=line.replace('res://fx/',prefix).replace('res://assets/arrow.glb','res://assets/vfx/elite_ranger_v001/ranger_arrow.glb')
 for cue in ['charge','fire','pulse']:line=line.replace(f'res://assets/{cue}.wav',f'res://assets/vfx/charged_arrow_v001/{cue}.wav')
 result.append(line)
count=sum(x.startswith('[ext_resource') for x in result)
(DST/'profile.tres').write_text(f'[gd_resource type="Resource" load_steps={count+1} format=3]\n'+'\n'.join(result)+'\n',encoding='utf-8')
for name in ['ribbon','flight_core','flight_halo','ground','warning','sigil','flare','mote','body','rift_wall','rift_lip','rift_void','rift_source','rift_curtain']:
 (DST/(name+'.tres')).write_text((SRC/(name+'.tres')).read_text(encoding='utf-8').replace('res://fx/',prefix),encoding='utf-8')
assets=GAME/'assets/vfx/charged_arrow_v001';assets.mkdir(exist_ok=True)
for cue in ['charge','fire','pulse']:shutil.copyfile(HERE/'godot_demo/assets'/f'{cue}.wav',assets/f'{cue}.wav')
print('Approved VFX exported to',DST)
