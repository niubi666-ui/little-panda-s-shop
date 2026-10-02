"""Offline syntax and dependency checks only; never starts or stops Godot."""
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "builds/decorating_lint"))
from gdtoolkit.parser import parser
files = []
for folder in ["game/shop/decorating", "game/content/decorating", "game/presentation/decorating"]:
    files.extend((ROOT / folder).glob("*.gd"))
files += [ROOT / path for path in ["game/app/shop_decoration.gd", "game/app/main.gd", "game/presentation/foliage/foliage_ui.gd", "game/presentation/shop_preview/shop_camera_controller.gd", "game/content/shop_preview/shop_preview_loader.gd", "game/content/shop_preview/shop_preview_definition.gd", "game/tests/decorating_rules.gd", "game/tests/shop_decorating.gd", "game/tests/foliage_ui.gd"]]
for path in files:
    source = path.read_text(encoding="utf-8-sig")
    parser.parse(source)
    for resource in re.findall(r'(?:preload|load)\("(res://[^"%]+)"\)', source):
        target = ROOT / "game" / resource.removeprefix("res://")
        if not target.exists(): raise ValueError(f"{path}: missing {resource}")
for path in (ROOT / "game/presentation/decorating").glob("*.tres"):
    for resource in re.findall(r'path="(res://[^"]+)"', path.read_text(encoding="utf-8")):
        if not (ROOT / "game" / resource.removeprefix("res://")).exists(): raise ValueError(resource)
print(f"DECORATING_STATIC: {len(files)} GDScript files parsed, literal resource references exist. No engine/type/render test run.")
