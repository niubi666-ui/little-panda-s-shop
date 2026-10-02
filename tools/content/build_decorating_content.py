"""Validate decorating content and generate its isolated locale PO files; no Godot run."""
import argparse
from pathlib import Path
from build_shop_preview_content import ROOT, DATA, read_json, validate, build_po, placeholders

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    shop = read_json(DATA / "shop/shop_preview.json")
    path = ROOT / "game" / shop["decorating_file"].removeprefix("res://")
    data = read_json(path)
    validate(data, read_json(DATA / "schemas/decorating.schema.json"), "decorating")
    ids = [item["id"] for item in data["furniture"]]
    if len(set(ids)) != len(ids): raise ValueError("duplicate furniture ID")
    locales = {lang: read_json(DATA / f"locales/decorating/{lang}.json") for lang in ("zh_CN", "en")}
    for lang, locale in locales.items():
        validate(locale, read_json(DATA / "schemas/shop_preview_locale.schema.json"), lang)
        if locale["locale"] != lang: raise ValueError("locale filename mismatch")
    if locales["zh_CN"]["messages"].keys() != locales["en"]["messages"].keys(): raise ValueError("locale keys differ")
    for key, message in locales["zh_CN"]["messages"].items():
        if placeholders(message, key) != placeholders(locales["en"]["messages"][key], key): raise ValueError("placeholder mismatch: " + key)
    for item in data["furniture"]:
        if item["name_key"] not in locales["en"]["messages"]: raise ValueError("untranslated furniture")
    for lang, locale in locales.items():
        target = ROOT / f"game/generated/locales/decorating/{lang}.po"
        expected = build_po(lang, locale["messages"])
        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != expected: raise ValueError("regenerate " + str(target))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(expected, encoding="utf-8")
    print(f"DECORATING_CONTENT valid: {len(ids)} furniture, {len(locales['en']['messages'])} bilingual keys")
if __name__ == "__main__": main()
