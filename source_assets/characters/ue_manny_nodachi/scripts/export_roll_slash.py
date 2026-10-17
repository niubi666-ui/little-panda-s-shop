"""Export the requested counter animation without changing UE project assets."""
import json
from pathlib import Path
import unreal

root = Path('E:/ShopGame/source_assets/characters/ue_manny_nodachi')
path = '/Game/Nodachi/Animations/Sequence/02_Attack/17_Parry_Counter_Attack/AS_Parry_Counter_L_Seq'
asset = unreal.load_asset(path)
assert asset, path
options = unreal.FbxExportOption()
for key, value in {'ascii': False, 'level_of_detail': False, 'collision': False,
                   'export_preview_mesh': False, 'export_morph_targets': False,
                   'map_skeletal_motion_to_root': False,
                   'bake_material_inputs': unreal.FbxMaterialBakeMode.DISABLED}.items():
    options.set_editor_property(key, value)
task = unreal.AssetExportTask()
task.object = asset
task.filename = str(root / 'fbx/roll_slash.fbx')
task.automated = True
task.prompt = False
task.replace_identical = True
task.options = options
task.exporter = unreal.AnimSequenceExporterFBX()
assert unreal.Exporter.run_asset_export_task(task), path
record = [{'name': 'roll_slash', 'source': path,
           'seconds': asset.get_play_length(), 'file': task.filename}]
(root / 'roll_slash.json').write_text(json.dumps(record, indent=2), encoding='utf8')
unreal.log('ROLL_SLASH_EXPORTED')
