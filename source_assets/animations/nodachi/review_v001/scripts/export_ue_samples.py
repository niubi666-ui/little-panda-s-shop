"""Read Nodachi source assets and export a small FBX review set. Never save UE assets."""
import unreal
import json
import traceback
from pathlib import Path

ROOT = Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
for part in ('fbx', 'blender', 'reports', 'previews'):
    (ROOT / part).mkdir(parents=True, exist_ok=True)
report = {'project': 'D:/UE5 test/Test58/Test58.uproject', 'exports': [], 'errors': []}

def save():
    (ROOT / 'reports/ue_export.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')

def prop(obj, name):
    try:
        value = obj.get_editor_property(name)
        return value.get_path_name() if isinstance(value, unreal.Object) else str(value)
    except Exception as e:
        return str(e)

options = unreal.FbxExportOption()
for name, value in {'ascii': False, 'fbx_export_compatibility': unreal.FbxExportCompatibility.FBX_2018,
                    'level_of_detail': False, 'collision': False, 'export_preview_mesh': True,
                    'export_morph_targets': False, 'map_skeletal_motion_to_root': False,
                    'bake_material_inputs': unreal.FbxMaterialBakeMode.DISABLED}.items():
    try:
        options.set_editor_property(name, value)
    except Exception as e:
        report['errors'].append({'option': name, 'error': str(e)})

base = '/Game/Nodachi/Animations/Sequence/'
paths = [('00_Combat_Idle', base + '01_Idle/02_Idle_Combat/AS_Idle_Combat_Seq')]
paths += [(f'0{i}_Combo_Attack_01_{i:02}', base + f'02_Attack/01_Combo_Attack_01/AS_Combo_Attack_01_{i:02}_Seq') for i in range(1, 5)]
paths += [('05_Combo_Attack_01_Full', base + '02_Attack/01_Combo_Attack_01/AS_Combo_Attack_01_All_Seq')]

def export(asset, filename, exporter=None):
    task = unreal.AssetExportTask()
    task.object = asset
    task.filename = str(ROOT / 'fbx' / (filename + '.fbx'))
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    task.options = options
    if exporter:
        task.exporter = exporter
    ok = unreal.Exporter.run_asset_export_task(task)
    return {'ok': bool(ok), 'file': task.filename, 'bytes': Path(task.filename).stat().st_size if Path(task.filename).exists() else 0,
            'task_errors': list(task.errors)}

for label, path in paths:
    try:
        asset = unreal.load_asset(path)
        if asset is None:
            raise RuntimeError('Asset not found: ' + path)
        entry = {'label': label, 'asset': path, 'class': asset.get_class().get_name(),
                 'skeleton': prop(asset, 'skeleton'), 'preview_skeletal_mesh': prop(asset, 'preview_skeletal_mesh'),
                 'enable_root_motion': prop(asset, 'enable_root_motion'), 'sequence_length': prop(asset, 'sequence_length')}
        if not report.get('animation_api'):
            report['animation_api'] = [x for x in dir(asset) if any(k in x for k in ('preview', 'sample', 'frame', 'length', 'skeleton'))]
            skeleton = asset.get_editor_property('skeleton')
            report['skeleton_api'] = [x for x in dir(skeleton) if any(k in x for k in ('socket', 'preview', 'bone'))]
            report['skeleton_preview'] = prop(skeleton, 'preview_skeletal_mesh')
            try:
                report['sockets'] = [str(x) for x in skeleton.get_editor_property('sockets')]
            except Exception as e:
                report['socket_error'] = str(e)
        report['exports'].append(entry)
        save()
        entry.update(export(asset, label, unreal.AnimSequenceExporterFBX()))
        unreal.log('NODACHI_EXPORT ' + json.dumps(entry))
    except Exception:
        report['errors'].append({'asset': path, 'traceback': traceback.format_exc()})
    save()

for path, label in [('/Game/Nodachi/Demo/Characters/Mannequins/Meshes/SKM_Manny_Simple', 'UE5_Manny_Reference'),
                    ('/Game/Nodachi/Demo/Characters/Mannequins/Meshes/Nodachi_Sword', 'Nodachi_Sword')]:
    try:
        asset = unreal.load_asset(path)
        if asset:
            entry = {'label': label, 'asset': path, 'class': asset.get_class().get_name(), 'skeleton': prop(asset, 'skeleton')}
            entry.update(export(asset, label))
            report['exports'].append(entry)
    except Exception:
        report['errors'].append({'asset': path, 'traceback': traceback.format_exc()})
    save()
unreal.log('NODACHI_EXPORT_COMPLETE ' + str(ROOT / 'reports/ue_export.json'))
