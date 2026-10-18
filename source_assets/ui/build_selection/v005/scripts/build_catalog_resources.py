from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[5]
SOURCE=Path(__file__).resolve().parents[1]
SPEC=json.loads((SOURCE/"generation/card_copy.json").read_text(encoding="utf-8-sig"))
BODIES=json.loads((SOURCE/"generation/card_body_copy.json").read_text(encoding="utf-8-sig"))
data=json.loads((ROOT/"game/data/builds/prototype.json").read_text(encoding="utf-8-sig"))
groups=json.loads((ROOT/"game/data/builds/reward_groups.json").read_text(encoding="utf-8-sig"))
meta={x["id"]:x for x in SPEC["cards"]}
assert set(meta)=={x["id"] for x in data["upgrades"]}
# Only presentation keys are added; existing gameplay and translated rules stay intact.
for index,locale in enumerate(["zh_CN","en"]):
    path=ROOT/f"game/data/locales/{locale}.json"
    text=path.read_text(encoding="utf-8")
    current=json.loads(text)["messages"]
    additions={f"build.card.headline.{k}":v[index] for k,v in SPEC["summaries"].items()}
    additions.update({f"build.card.body.{k}":v[index] for k,v in BODIES.items()})
    for entry in data["upgrades"]:
        old=current[entry["name_key"]]
        if entry["name_key"].startswith("build.test."):
            additions["build.card.name."+entry["id"]]=old.replace("试验 · ","").replace("Test · ","").replace("Test - ","")
    additions["build.card.choose"]=["选择此祝福","Choose blessing"][index]
    additions["build.card.title"]=["选择你的成长","Choose your growth"][index]
    additions["build.card.subtitle"]=["选择一项祝福，强化本次冒险","Choose one blessing to shape this journey."][index]
    pending={k:v for k,v in additions.items() if k not in current}
    for k,v in additions.items():
        if k in current: assert current[k]==v, f"Conflicting translation: {k}"
    if pending:
        marker='"messages": {'
        insertion="\n"+",\n".join("    "+json.dumps(k,ensure_ascii=False)+": "+json.dumps(v,ensure_ascii=False) for k,v in pending.items())+","
        text=text.replace(marker,marker+insertion,1)
        path.write_text(text,encoding="utf-8")
rarities=["common","rare","epic","legendary"]
lines=['[gd_resource type="Resource" load_steps=6 format=3]','',
'[ext_resource type="Script" path="res://presentation/builds/build_card_art_library.gd" id="script"]']
for r in rarities:
    lines.append(f'[ext_resource type="Texture2D" path="res://assets/ui/build_cards/v001/frames/{r}.png" id="{r}"]')
lines+=['','[resource]','script = ExtResource("script")','cards = {']
index=[]
for entry in data["upgrades"]:
    cid=entry["id"]; info=meta[cid]
    default_rarity=groups["upgrade_groups"].get(cid)
    if default_rarity is None:
        assert cid in ["wave","chain","contact_slow"]
        default_rarity="common"
    title="build.card.name."+cid if entry["name_key"].startswith("build.test.") else entry["name_key"]
    record={"art":f"res://assets/ui/build_cards/v001/illustrations/{info['category']}/{cid}.png",
       "category":info["category"],"headline_key":"build.card.headline."+info["headline"],
       "title_key":title,"body_key":"build.card.body."+cid,"default_rarity":default_rarity}
    lines.append(json.dumps(cid)+": "+json.dumps(record,ensure_ascii=False)+",")
    index.append(dict(id=cid,name_key=title,description_key=entry["description_key"],
                     rarity=default_rarity,category=info["category"],
                     enabled_in_pool=cid in data["offer"]["pool_ids"] and entry["weight"]>0,
                     image=f"illustrations/{info['category']}/{cid}.png",ranks=entry["max_rank"]))
lines+=['}','rarity_skins = {',
'"common": {"frame": ExtResource("common"), "color": Color(0.87, 0.91, 0.83, 1), "surface_top": 43.0, "label_rect": Rect2(130, 23, 120, 44)},',
'"rare": {"frame": ExtResource("rare"), "color": Color(0.40, 0.77, 1, 1), "surface_top": 60.0, "label_rect": Rect2(125, 51, 130, 37)},',
'"epic": {"frame": ExtResource("epic"), "color": Color(0.84, 0.57, 1, 1), "surface_top": 53.0, "label_rect": Rect2(120, 50, 140, 36)},',
'"legendary": {"frame": ExtResource("legendary"), "color": Color(1, 0.70, 0.27, 1), "surface_top": 91.0, "label_rect": Rect2(125, 88, 130, 34)},',
'"awakening": {"frame": ExtResource("common"), "color": Color(0.95, 0.84, 0.56, 1), "surface_top": 43.0, "label_rect": Rect2(130, 23, 120, 44)}',
'}']
(ROOT/"game/presentation/builds/build_card_art_library.tres").write_text("\n".join(lines)+"\n",encoding="utf-8")
(SOURCE/"catalog.json").write_text(json.dumps({"cards":index,"count":len(index)},ensure_ascii=False,indent=2),encoding="utf-8")
print("Authored presentation records:",len(index))

