import unreal,json,traceback
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/roll_8dir_v001')
for folder in ('fbx','blender','godot','reports','previews'): (ROOT/folder).mkdir(parents=True,exist_ok=True)
directions=[('forward','前','F_0'),('forward_right','右前','F_R_45'),('right','右','R_90'),('back_right','右后','B_R_45'),
            ('back','后','B_180'),('back_left','左后','B_L_45'),('left','左','L_90'),('forward_left','左前','F_L_45')]
report={'exports':[],'errors':[],'variant':'IP','source_group':'07_Roll/02_Roll_Combat/02_IP'}
opts=unreal.FbxExportOption()
for k,v in {'ascii':False,'fbx_export_compatibility':unreal.FbxExportCompatibility.FBX_2018,'level_of_detail':False,
 'collision':False,'export_preview_mesh':False,'export_morph_targets':False,'map_skeletal_motion_to_root':False,
 'bake_material_inputs':unreal.FbxMaterialBakeMode.DISABLED}.items(): opts.set_editor_property(k,v)
for index,(direction,label,suffix) in enumerate(directions):
    name='AS_Roll_Combat_'+suffix+'_Seq'
    asset_path='/Game/Nodachi/Animations/Sequence/07_Roll/02_Roll_Combat/02_IP/'+name
    try:
        asset=unreal.load_asset(asset_path)
        assert asset,asset_path
        dest=ROOT/'fbx'/('roll_'+direction+'.fbx')
        task=unreal.AssetExportTask()
        task.object=asset
        task.filename=str(dest)
        task.automated=True
        task.prompt=False
        task.replace_identical=True
        task.options=opts
        task.exporter=unreal.AnimSequenceExporterFBX()
        ok=unreal.Exporter.run_asset_export_task(task)
        report['exports'].append({'direction':direction,'label_zh':label,'source_name':name,'asset':asset_path,
          'action':'roll_'+direction,'file':str(dest),'ok':bool(ok),'bytes':dest.stat().st_size if dest.exists() else 0,
          'sequence_length':asset.get_play_length(),'skeleton':asset.get_skeleton().get_path_name(),'errors':list(task.errors)})
    except Exception: report['errors'].append({'asset':asset_path,'error':traceback.format_exc()})
    (ROOT/'reports/ue_export.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    unreal.log(f'ROLL_EXPORT {index+1}/8 '+name)
unreal.log('ROLL_EXPORT_DONE')
