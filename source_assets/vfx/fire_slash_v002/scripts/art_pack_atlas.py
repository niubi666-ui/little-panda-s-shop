"""Pack the 16 actual transparent Blender renders without colour conversion."""
from pathlib import Path
from PIL import Image
import json, shutil, hashlib
BASE=Path(__file__).resolve().parents[1]
ROOT=BASE.parents[2]
atlas=Image.new('RGBA',(1024,1024),(0,0,0,0))
report={'layout':[4,4],'cell_px':256,'first_frame':'top left','frames':[]}
for f in range(16):
    im=Image.open(BASE/'bakes/flame_frames'/f'flame_{f:02d}.png').convert('RGBA')
    assert im.size==(256,256)
    atlas.paste(im,((f%4)*256,(f//4)*256))
    a=im.getchannel('A')
    report['frames'].append({'frame':f,'alpha_bbox':a.getbbox(),'alpha_max':a.getextrema()[1]})
path=BASE/'bakes/flame_atlas.png';atlas.save(path)
shutil.copy2(path,ROOT/'game/assets/vfx/fire_slash_v002/flame_atlas.png')
report['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
(BASE/'reports/art_atlas_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
# A neutral contact sheet lets reviewers see the alpha silhouette.
bg=Image.new('RGBA',atlas.size,(24,29,38,255));bg.alpha_composite(atlas);bg.convert('RGB').save(BASE/'blender_previews/flame_atlas_contact.jpg',quality=94)
print('ATLAS_PACKED',path)
