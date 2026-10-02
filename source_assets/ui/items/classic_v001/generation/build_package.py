"""Index and verify generated sheets without editing their pixels."""
import hashlib
import html
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / 'generation/prompts_and_sources.json').read_text(encoding='utf-8-sig'))
all_ids = [item['art_id'] for cat in data['categories'] for item in cat['items']]
assert len(data['categories']) == 4 and len(all_ids) == 36
assert len(set(all_ids)) == 36
manifest = {'version': data['version'], 'date': data['date'],
            'asset_type': 'annotated_reference_sheets', 'runtime_ready': False,
            'provenance': 'generation/prompts_and_sources.json', 'categories': []}
report = {'date': data['date'], 'sheet_count': 4, 'item_count': 36,
          'unique_art_ids': True, 'pixel_operations': 'none', 'files': []}
sections = []
readme = ['# 经典物品材料图集 v001', '', '日期：2026-10-01。使用内置 imagegen，参考已选树叶风格背包 UI 制作。共四张 3×3 图集、36 种物品；每件包含中文名称和外观说明。', '',
          '## 浏览与文件', '', '[打开全部图集预览](previews/index.html)。PNG 按类别存放，原始生成文件保留；本目录中的副本与原件字节一致。', '',
          '| 分类 | 图片 | 内容 |', '| --- | --- | --- |']
for cat in data['categories']:
    path = ROOT / cat['image_path']
    original = Path(cat['original_path'])
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    assert sha == hashlib.sha256(original.read_bytes()).hexdigest()
    with Image.open(path) as im:
        size, mode = list(im.size), im.mode
        im.verify()
    assert len(cat['items']) == 9
    assert {(i['row'], i['column']) for i in cat['items']} == {(r,c) for r in range(1,4) for c in range(1,4)}
    manifest['categories'].append({'category': cat['category'], 'title': cat['title'],
                                 'image_path': cat['image_path'], 'image_size': size,
                                 'image_mode': mode, 'sha256': sha, 'items': cat['items']})
    report['files'].append({'path': cat['image_path'], 'size': size, 'mode': mode,
                            'png_readable': True, 'copy_matches_original': True,
                            'row_column_index_valid': True, 'sha256': sha})
    e = html.escape
    items = ''.join(f"<li><strong>{e(i['name_zh'])}</strong><span>{e(i['visual_description_zh'])}</span><code>{e(i['art_id'])}</code></li>" for i in cat['items'])
    sections.append(f"<section id='{e(cat['category'])}'><h2>{e(cat['title'])} · 9 种</h2><a href='../{e(cat['image_path'])}'><img src='../{e(cat['image_path'])}' alt='{e(cat['title'])}九宫格图集'></a><ul>{items}</ul></section>")
    readme.append(f"| {cat['title']} | [{cat['category']}]({cat['image_path']}) | {'、'.join(i['name_zh'] for i in cat['items'])} |")
    category_readme = [f"# {cat['title']}", '', f"[查看图集]({Path(cat['image_path']).name})。从上到下、从左到右排列。", '',
                       '| 行 | 列 | 美术 ID | 中文名 | 英文候选名 |', '| --- | --- | --- | --- | --- |']
    category_readme += [f"| {i['row']} | {i['column']} | `{i['art_id']}` | {i['name_zh']} | {i['name_en_candidate']} |" for i in cat['items']]
    (ROOT / cat['category'] / 'README.md').write_text('\n'.join(category_readme)+'\n', encoding='utf-8')
readme += ['', '## 使用范围', '',
           '- 图集采用暖羊皮纸背景，保留名称说明，供物品设计确认和后续图标制作参考。当前不是独立透明游戏图标。正式接入时需单独提取物品、去除纸张与文字并检查透明边缘。',
           '- 药水名称、材料外观和英文名均为美术候选，不定义实际效果、掉落、价格或制作配方。权威内容仍由项目 JSON 管理。',
           '- `art_id` 是本套美术索引，不等同于已注册的游戏内容 ID。后续通过显式映射接入；中英文名称应由游戏翻译系统绘制。',
           '- 药水使用瓶形、配件和液体颜色共同区分，避免只依赖颜色辨识。', '',
           '## 记录与验收', '',
           '[素材清单](manifest.json)记录图片尺寸、SHA-256、36 个美术 ID 及行列位置；未提供未经人工确认的图标裁切框。', '',
           '[完整提示词与生成来源](generation/prompts_and_sources.json)包含生成工具、风格参考、每张图提示词和原始文件路径。', '',
           '[文件检查报告](reports/asset_validation.json)：PNG 可读、复制一致、数量和行列索引检查。图集在生成后已人工查看；这不等于游戏内缩小显示与透明图标验收。', '',
           '本次交付仅涉及项目外美术目录，未修改 Godot 资源或代码。']
(ROOT / 'README.md').write_text('\n'.join(readme)+'\n', encoding='utf-8')
for filename, obj in [('manifest.json', manifest), ('reports/asset_validation.json', report)]:
    (ROOT / filename).write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
nav = ''.join(f"<a href='#{html.escape(c['category'])}'>{html.escape(c['title'])}</a>" for c in data['categories'])
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>小熊猫的小店 · 经典物品材料</title>
<style>body{margin:0;background:#0d211b;color:#eddfb9;font:16px/1.6 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1200px;margin:auto;padding:32px 24px}h1,h2{color:#e4c77b}nav{display:flex;gap:14px;flex-wrap:wrap;margin:24px 0}a{color:#e4c77b}nav a{padding:8px 18px;border:1px solid #8c7644;border-radius:8px;text-decoration:none}section{margin:36px 0;padding:24px;background:#152c23;border:1px solid #655b38;border-radius:14px}img{display:block;width:100%;height:auto;border-radius:8px}ul{padding:0;list-style:none;display:grid;grid-template-columns:repeat(3,1fr);gap:14px}li{padding:12px;border-bottom:1px solid #495439}span,code{display:block}span{color:#ccc9ac}code{font-size:12px;color:#9ca991;overflow-wrap:anywhere}@media(max-width:650px){ul{grid-template-columns:1fr}main{padding:14px}section{padding:12px}}</style>
<main><h1>经典物品材料 · 36 种</h1><p>延续树叶风格 UI 的暖光、手绘材质与奇幻日常物件。点击图集可查看原图。</p><p>带文字的设计参考图集；名称与外观说明不定义游戏数值或实际效果。</p><nav>''' + nav + '</nav>' + ''.join(sections) + '<p><a href="../README.md">归档说明</a> · <a href="../manifest.json">素材清单</a></p></main></html>'
(ROOT / 'previews/index.html').write_text(page, encoding='utf-8')
print(json.dumps({'status': 'passed', 'sheets': report['files'], 'item_count': 36}, ensure_ascii=False))
