import unreal,json
from pathlib import Path
root=Path('E:/ShopGame/source_assets/characters/ue_manny_nodachi')
(root/'fbx').mkdir(parents=True,exist_ok=True)
out=[]
for name,rel in [('hit','02_Hit_Combat/AS_Hit_Combat_F_Seq'),('death','02_Hit_Combat/AS_Hit_Combat_Death_Seq'),('charge','14_Block/AS_Block_Loop_Seq')]:
 path='/Game/Nodachi/Animations/Sequence/08_Hit/'+rel
 asset=unreal.load_asset(path);assert asset,path
 opt=unreal.FbxExportOption()
 for k,v in {'ascii':False,'level_of_detail':False,'collision':False,'export_preview_mesh':False,'export_morph_targets':False,'map_skeletal_motion_to_root':False,'bake_material_inputs':unreal.FbxMaterialBakeMode.DISABLED}.items():opt.set_editor_property(k,v)
 task=unreal.AssetExportTask();task.object=asset;task.filename=str(root/'fbx'/f'{name}.fbx');task.automated=True;task.prompt=False;task.replace_identical=True;task.options=opt;task.exporter=unreal.AnimSequenceExporterFBX()
 assert unreal.Exporter.run_asset_export_task(task),path
 out.append({'name':name,'source':path,'seconds':asset.get_play_length(),'file':task.filename})
(root/'reactions.json').write_text(json.dumps(out,indent=2),encoding='utf8')
unreal.log('REACTIONS_EXPORTED')
