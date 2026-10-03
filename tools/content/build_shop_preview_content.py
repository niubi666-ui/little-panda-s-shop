"""Validate this small preview slice and generate deterministic PO files.

Uses the pinned jsonschema package from requirements.txt with Draft 2020-12.
Install dependencies in the project-private builds/content_venv environment.

Usage: python tools/content/build_shop_preview_content.py [--check]
"""

from __future__ import annotations

import argparse
from importlib.metadata import version
import json
import math
from pathlib import Path
import re
from string import Formatter
import sys

try:
    from jsonschema import Draft202012Validator
    from jsonschema.exceptions import SchemaError
except ImportError as error:
    raise SystemExit("Install tools/content/requirements.txt in the project-private Python environment.") from error


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "data"
GENERATED = ROOT / "game" / "generated" / "locales"
EXPECTED_JSONSCHEMA_VERSION = "4.25.1"


def object_without_duplicates(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON number: {value}")


def finite_float(value: str) -> float:
    number = float(value)
    if not math.isfinite(number):
        raise ValueError(f"non-finite JSON number: {value}")
    return number


def read_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"),
                          object_pairs_hook=object_without_duplicates,
                          parse_float=finite_float,
                          parse_constant=reject_constant)
    except (ValueError, OSError) as error:
        raise ValueError(f"{path.relative_to(ROOT)}: {error}") from error


def validate(value: object, schema: dict, location: str) -> None:
    Draft202012Validator.check_schema(schema)
    errors = sorted(Draft202012Validator(schema).iter_errors(value), key=lambda error: error.json_path)
    if errors:
        raise ValueError("\n".join(f"{location}{error.json_path[1:]}: {error.message}" for error in errors))


def placeholders(message: str, location: str) -> set[str]:
    fields = set()
    for _, field, spec, conversion in Formatter().parse(message):
        if field is None:
            continue
        if not re.fullmatch(r"[a-z_][a-z0-9_]*", field) or spec or conversion:
            raise ValueError(f"{location}: use plain named placeholders")
        fields.add(field)
    return fields


def po_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def build_po(locale: str, messages: dict[str, str]) -> str:
    plurals = "nplurals=1; plural=0;" if locale == "zh_CN" else "nplurals=2; plural=(n != 1);"
    lines = [
        "# GENERATED from game/data/locales; edit JSON and rerun the build tool.",
        'msgid ""', 'msgstr ""',
        po_quote(f"Language: {locale}\n"),
        po_quote("MIME-Version: 1.0\n"),
        po_quote("Content-Type: text/plain; charset=UTF-8\n"),
        po_quote("Content-Transfer-Encoding: 8bit\n"),
        po_quote(f"Plural-Forms: {plurals}\n"), "",
    ]
    for key in sorted(messages):
        lines.extend(["msgid " + po_quote(key), "msgstr " + po_quote(messages[key]), ""])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if generated PO differs; do not write.")
    args = parser.parse_args()
    try:
        installed_version = version("jsonschema")
        if installed_version != EXPECTED_JSONSCHEMA_VERSION:
            raise ValueError(f"jsonschema {installed_version} installed; require {EXPECTED_JSONSCHEMA_VERSION}. Install tools/content/requirements.txt.")
        manifest = read_json(DATA / "manifest.json")
        validate(manifest, read_json(DATA / "schemas" / "shop_preview_manifest.schema.json"), "manifest")
        config_path = ROOT / "game" / manifest["shop_preview_file"].removeprefix("res://")
        validate(read_json(config_path), read_json(DATA / "schemas" / "shop_preview.schema.json"), str(config_path))
        from validate_combat import validate_combat
        validate_combat(manifest)
        from validate_enemies import validate_enemies
        validate_enemies(manifest)
        from validate_builds import validate_builds
        validate_builds(manifest)
        from validate_room_props import validate_room_props
        validate_room_props(manifest)
        from validate_run import validate_run
        validate_run(manifest)
        locale_schema = read_json(DATA / "schemas" / "shop_preview_locale.schema.json")
        locales = {}
        for locale in ("zh_CN", "en"):
            path = DATA / "locales" / f"{locale}.json"
            source = read_json(path)
            validate(source, locale_schema, str(path))
            if source["locale"] != locale:
                raise ValueError(f"{path}: filename and locale differ")
            locales[locale] = source["messages"]
        if set(locales["zh_CN"]) != set(locales["en"]):
            raise ValueError("Translation key sets differ between zh_CN and en")
        foliage = read_json(ROOT / "game" / manifest["foliage_preview_file"].removeprefix("res://"))
        validate(foliage, read_json(DATA / "schemas/foliage_preview.schema.json"), "foliage_preview")
        for section in ("inventory", "orders", "decoration"):
            ids = set()
            for entry in foliage[section]:
                if entry["id"] in ids:
                    raise ValueError(f"{section}: duplicate sample ID")
                ids.add(entry["id"])
                for field in ("name_key", "description_key"):
                    if entry[field] not in locales["zh_CN"]:
                        raise ValueError(f"{section}: missing translation {entry[field]}")
                if not (ROOT / "game" / entry["icon"].removeprefix("res://")).is_file():
                    raise ValueError(f"{section}: missing icon {entry['icon']}")
        for key in locales["zh_CN"]:
            if not re.fullmatch(r"[a-z_][a-z0-9_.]*", key):
                raise ValueError(f"Invalid translation key: {key}")
            if placeholders(locales["zh_CN"][key], key) != placeholders(locales["en"][key], key):
                raise ValueError(f"{key}: named placeholders differ across languages")
        controller = (ROOT / "game/presentation/shop_preview/shop_preview_controller.gd").read_text(encoding="utf-8")
        static_keys = set(re.findall(r'_message\("([a-z0-9_.]+)"', controller))
        foliage_ui = (ROOT / "game/presentation/foliage/foliage_ui.gd").read_text(encoding="utf-8")
        static_keys.update(re.findall(r'message\("([a-z0-9_.]+)"\)', foliage_ui))
        commission_ui = (ROOT / "game/presentation/foliage/commission_board.gd").read_text(encoding="utf-8")
        static_keys.update(re.findall(r'"(ui\.commission\.[a-z_]+)"', commission_ui))
        missing_keys = static_keys - set(locales["zh_CN"])
        if missing_keys:
            raise ValueError(f"Controller references untranslated keys: {sorted(missing_keys)}")
        for locale, messages in locales.items():
            path = GENERATED / f"{locale}.po"
            expected = build_po(locale, messages)
            if args.check:
                if not path.is_file() or path.read_text(encoding="utf-8") != expected:
                    raise ValueError(f"{path.relative_to(ROOT)} differs; regenerate content")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(expected, encoding="utf-8", newline="\n")
        print(f"Shop preview content valid; {len(locales['zh_CN'])} bilingual keys; PO {'matches' if args.check else 'generated'}.")
        return 0
    except (ValueError, KeyError, TypeError, SchemaError) as error:
        print(f"CONTENT ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
