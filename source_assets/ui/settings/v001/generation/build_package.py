from pathlib import Path
import shutil,json,hashlib,html,xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path('E:/ShopGame'); BASE=ROOT/'source_assets/ui/settings/v001'; RUN=ROOT/'game/assets/ui/settings/v001'
GEN=Path('C:/Users/陈旭辉/.codex/generated_images/01a0dbbb-e5a8-7b32-a068-ebcadcf5d960')
OLD=ROOT/'source_assets/ui/inventory/v001/exports'
for d in ['reference','exports/chrome','exports/icons','previews','reports']: (BASE/d).mkdir(parents=True,exist_ok=True)
shutil.copy2(GEN/'exec-9c30cce7-f039-4d3c-8c3e-772cb10f7312.png',BASE/'reference/settings_concept.png')
sources={}
for name in ['window_panel','tab_regular','tab_selected','button_primary','button_secondary','close_socket','header_leaf_sprig']:
    src=OLD/'chrome'/f'{name}.png';dst=BASE/'exports/chrome'/src.name;shutil.copy2(src,dst);sources[dst.name]=str(src)
for name,raw in [('controls_parchment','exec-1eead3c1-c0df-428d-8bb0-272cb76daf80.png'),('keycap','exec-85327403-4a28-40b9-9979-4e9d7c577b8d.png')]:
    dst=BASE/'exports/chrome'/f'{name}.png';shutil.copy2(GEN/raw,dst);sources[dst.name]=str(GEN/raw)
for name in ['close','divider_gold','divider_ink']:
    src=OLD/'icons'/f'{name}.svg';dst=BASE/'exports/icons'/src.name;shutil.copy2(src,dst);sources[dst.name]=str(src)
icons={
 'language': '<g fill="none" stroke="#d9bd77" stroke-width="3"><circle cx="32" cy="32" r="25"/><ellipse cx="32" cy="32" rx="12" ry="25"/><path d="M7 32h50 M12 18h40 M12 46h40"/></g>',
 'mouse_wheel':'<g fill="none" stroke="#dfc68e" stroke-width="3" stroke-linecap="round"><rect x="17" y="9" width="30" height="47" rx="15"/><path d="M32 9v20 M17 30h30"/><rect x="29" y="15" width="6" height="12" rx="3" fill="#dfc68e"/></g>',
 'control_row':'<g fill="none" stroke="#a08d63" stroke-width="1"><path d="M12 2h456l10 10v52l-10 10H12L2 64V12Z"/><path d="M9 17V9h8 M463 9h8v8 M9 59v8h8 M463 67h8v-8"/></g>',
 'focus_ring':'<rect x="3" y="3" width="314" height="74" rx="8" fill="none" stroke="#fff2bb" stroke-width="3" stroke-dasharray="6 4"/>'}
for name,body in icons.items():
    w,h=(480,76) if name=='control_row' else (320,80) if name=='focus_ring' else (64,64)
    dst=BASE/'exports/icons'/f'{name}.svg';dst.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>',encoding='utf-8');sources[dst.name]='Project-native SVG supplement matching existing icon palette'
assets=[]
for path in sorted((BASE/'exports').rglob('*')):
    if not path.is_file():continue
    rel=path.relative_to(BASE/'exports');dest=RUN/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,dest)
    entry={'file':str(rel).replace('\\','/'),'source':sources[path.name],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'runtime':'res://assets/ui/settings/v001/'+str(rel).replace('\\','/'),'runtime_hash_match':path.read_bytes()==dest.read_bytes()}
    if path.suffix=='.png':
        im=Image.open(path);assert im.mode=='RGBA',(path,im.mode)
        alpha=im.getchannel('A');box=alpha.getbbox();assert box and alpha.getextrema()[0]==0,path
        entry.update(size=list(im.size),alpha_bbox_xyxy=list(box),atlas_region_xywh=[box[0],box[1],box[2]-box[0],box[3]-box[1]],alpha_extrema=list(alpha.getextrema()))
    else:ET.parse(path)
    assets.append(entry)
(BASE/'manifest.json').write_text(json.dumps({'stage':'art assets only; not integrated','assets':assets},ensure_ascii=False,indent=2),encoding='utf-8')
(BASE/'reports/asset_validation.json').write_text(json.dumps({'png_rgba_and_transparent':True,'svg_xml_parsed':True,'runtime_copies_match':all(a['runtime_hash_match'] for a in assets),'png_count':sum('size' in a for a in assets),'svg_count':sum('size' not in a for a in assets),'pixel_edits':False,'godot_integration_tested':False},indent=2),encoding='utf-8')
def sprite(name,cls=''):
    a=next(a for a in assets if a['file']==f'chrome/{name}.png');x,y,w,h=a['atlas_region_xywh'];iw,ih=a['size']
    return f'<svg class="{cls}" viewBox="{x} {y} {w} {h}" preserveAspectRatio="none"><image href="../exports/chrome/{name}.png" width="{iw}" height="{ih}"/></svg>'
cards=''.join(f'<figure><div class="check"><img src="../exports/{a["file"]}"></div><figcaption>{a["file"]}</figcaption></figure>' for a in assets)
(BASE/'previews/index.html').write_text('<!doctype html><meta charset="utf-8"><title>设置 UI 素材</title><style>body{background:#17241f;color:#e7dbba;font:16px system-ui;padding:28px}a{color:#e9c87e}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}figure{margin:0}.check{height:220px;background:repeating-conic-gradient(#777 0% 25%,#555 0% 50%) 0/24px 24px;display:grid;place-items:center}img{max-width:96%;max-height:210px}figcaption{padding:12px}</style><h1>设置 UI · 独立组件</h1><p><a href="layout_preview.html">双语拼装示意</a> · <a href="../reference/settings_concept.png">完整概念图</a></p><div class="grid">'+cards+'</div>',encoding='utf-8')
def key(k):return '<span class="key">'+sprite('keycap','bg')+f'<b>{k}</b></span>'
rows=''
for keys,zh,en in [('W A S D','移动','Move'),('F','互动','Interact'),('mouse','缩放','Zoom'),('B','背包','Inventory'),('J','订单','Orders'),('R','装修','Decorate')]:
    content=key('<img src="../exports/icons/mouse_wheel.svg">') if keys=='mouse' else ''.join(key(k) for k in keys.split())
    rows+=f'<div class="row"><div class="keys">{content}</div><span data-zh="{zh}" data-en="{en}">{zh}</span></div>'
layout='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>设置 UI 拼装预览</title><style>
@font-face{font-family:Game;src:url('../../../../../game/assets/fonts/NotoSerifSC-VF.ttf')}*{box-sizing:border-box}body{margin:0;background:#18221d;color:#f1e6c9;font:20px Game,serif} .stage{isolation:isolate;width:1200px;height:800px;position:relative;margin:20px auto;padding:45px 64px}.bg{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}.stage>.bg{z-index:-1}h1{font-size:34px;margin:0}.head{height:78px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #9b8556}.title{display:flex;gap:18px;align-items:center}.sprig{width:48px;height:52px}.button{position:relative;border:0;background:none;color:inherit;font:inherit;cursor:pointer;padding:12px 28px;min-width:225px;height:58px}.button b{position:relative;font-weight:500}.button:focus-visible{outline:3px dashed #fff2bb;outline-offset:3px}.close{min-width:48px;width:48px;padding:10px;height:48px}.close img{position:relative;width:24px}.language{height:112px;display:flex;align-items:center;gap:20px}.language>span{margin-right:auto}.language img{width:35px;vertical-align:middle;margin-right:14px}.paper{position:relative;height:448px;padding:28px 55px;color:#302c20}.paper>*:not(.bg){position:relative}.paper h2{text-align:center;font-size:27px;margin:0 0 12px}.divider{display:block;width:50%;height:15px;margin:0 auto 18px}.rows{display:grid;grid-template-columns:1fr 1fr;gap:14px 24px}.row{height:76px;display:flex;align-items:center;gap:20px;padding:10px 15px;background:url('../exports/icons/control_row.svg') center/100% 100% no-repeat}.keys{display:flex;gap:5px;min-width:175px;justify-content:center}.key{position:relative;display:grid;place-items:center;width:39px;height:43px;color:#f5e7bd;font-size:21px}.key b{position:relative;font-weight:500}.key img{width:26px;height:30px}.footer{height:100px;display:flex;flex-direction:column;align-items:center;gap:10px;padding-top:16px}.note{font-size:14px;color:#d2c39e;margin:0}.notice{font:14px system-ui;text-align:center;color:#bcbcac}a{color:#ddc888}
</style><p class="notice">美术拼装预览 · 点击语言按钮检查双语排版 · 尚未接入 Godot</p><main class="stage">'''
layout+=sprite('window_panel','bg')+'<header class="head"><div class="title">'+sprite('header_leaf_sprig','sprig')+'<h1 data-zh="设置" data-en="Settings">设置</h1></div><button class="button close" aria-label="Close preview">'+sprite('close_socket','bg')+'<img src="../exports/icons/close.svg"></button></header><section class="language"><span><img src="../exports/icons/language.svg"><b data-zh="界面语言" data-en="Language">界面语言</b></span>'
for lang,label,asset in [('zh','简体中文','tab_selected'),('en','English','tab_regular')]:layout+=f'<button class="button lang" data-lang="{lang}">'+sprite(asset,'bg')+f'<b>{label}</b></button>'
layout+='</section><section class="paper">'+sprite('controls_parchment','bg')+'<h2 data-zh="操作指南" data-en="Controls">操作指南</h2><img class="divider" src="../exports/icons/divider_ink.svg"><div class="rows">'+rows+'</div></section><footer class="footer"><p class="note" data-zh="语言切换立即生效，本次运行结束后不保存。" data-en="Language changes apply immediately and are not saved after this session.">语言切换立即生效，本次运行结束后不保存。</p><button class="button">'+sprite('button_primary','bg')+'<b data-zh="返回游戏" data-en="Return to game">返回游戏</b></button></footer></main><p class="notice"><a href="index.html">查看独立组件</a> · 关闭与返回按钮仅作视觉示意；语言切换只影响本页。</p>'
selected=sprite('tab_selected','bg');regular=sprite('tab_regular','bg')
layout+='<script>const skins='+json.dumps({'selected':selected,'regular':regular})+';document.querySelectorAll(".lang").forEach(b=>b.onclick=()=>{let lang=b.dataset.lang;document.documentElement.lang=lang==="zh"?"zh-CN":"en";document.querySelectorAll("[data-zh]").forEach(e=>e.textContent=e.dataset[lang]);document.querySelectorAll(".lang").forEach(x=>{x.querySelector("svg").outerHTML=skins[x===b?"selected":"regular"];x.setAttribute("aria-pressed",x===b)})});</script></html>'
(BASE/'previews/layout_preview.html').write_text(layout,encoding='utf-8')
print(json.dumps({'assets':len(assets),'source':str(BASE),'runtime':str(RUN),'validated':True}))
