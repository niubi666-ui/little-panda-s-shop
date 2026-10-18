"""Export authored card motion to Godot Resources and small vector masks.

Only writes the catalog's own runtime/source masks, profiles and path index.
The three approved core profiles and original illustrations are never rewritten.
Run from any directory; standard Python only (no DCC or image package required).
"""
from pathlib import Path
import json
import re
import zlib
from html import escape

ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / "source_assets/ui/build_selection/animated_v001"
RUNTIME = ROOT / "game/presentation/builds/card_art_motion"
MASKS = ROOT / "game/assets/ui/build_cards/v001/motion"
CORE = {"fire_core": "fire", "ice_core": "ice", "thunder_core": "thunder"}
TYPES = dict(re.findall(r'var (\w+): ([^\r\n=]+)', (RUNTIME / "profile.gd").read_text(encoding="utf-8")))


def raw_base(kind):
    source_kind = kind if kind in ("fire", "ice", "thunder") else "fire"
    body = (RUNTIME / (source_kind + ".tres")).read_text(encoding="utf-8").split("[resource]", 1)[1]
    result = dict(re.findall(r"(?m)^(\w+) = (.+)$", body))
    for key in ("script", "shader", "mask"):
        result.pop(key)
    if kind in ("energy", "earth"):
        result.update({"kind": json.dumps(kind), "flow_px": "0.0", "flow_emission": "0.0",
            "flow_period_sec": "2.0", "glow_variation": "0.34", "noise_scale": "Vector2(52, -38)",
            "noise_speed": "3.5", "particle_count": "12" if kind == "earth" else "0",
            "particle_life": "Vector2(1.2, 2.1)", "particle_drift": "Vector2(3, -15)",
            "particle_radius": "Vector2(0.9, 1.6)", "particle_sway": "Vector2(3, 1)",
            "particle_opacity": "0.8", "particle_tail_sec": "0.0",
            "tint": "Color(1, 0.68, 0.22, 1)" if kind == "earth" else "Color(0.76, 1, 0.7, 1)",
            "particle_core": "Color(1, 0.86, 0.48, 1)" if kind == "earth" else "Color(0.94, 1, 0.84, 1)"})
        result.pop("emission_path")  # must be authored if particles are enabled
    return result


def vec(values, constructor):
    return constructor + "(" + ", ".join(str(v) for v in values) + ")"


def godot_value(key, value):
    if key not in TYPES:
        raise ValueError("Unknown Profile field: " + key)
    field_type = TYPES[key].strip()
    if field_type in ("Vector2", "Vector3", "Vector4", "Color"):
        return vec(value, field_type)
    if field_type == "PackedVector2Array":
        return vec([v for point in value for v in point], field_type)
    if field_type == "PackedInt32Array":
        return vec(value, field_type)
    if field_type == "Array[PackedVector2Array]":
        return "Array[PackedVector2Array]([" + ", ".join(vec([v for p in path for v in p], "PackedVector2Array") for path in value) + "])"
    if field_type in ("int", "float", "bool", "String"):
        return json.dumps(value, ensure_ascii=False)
    raise ValueError((key, field_type))


def validate_points(points):
    assert len(points) >= 2
    for p in points:
        assert len(p) == 2 and all(0 <= x <= 1 for x in p), p


def make_mask(mask, title):
    # Same 4:3 UV mapping as the 1448x1086 artwork, 1/8 its pixel count.
    text = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="384" viewBox="0 0 1000 1000" preserveAspectRatio="none">',
        '<title>' + escape(title) + '</title>', '<rect width="1000" height="1000" fill="black"/>',
        '<defs><radialGradient id="soft"><stop offset="0" stop-color="#d80000"/><stop offset="0.55" stop-color="#840000"/><stop offset="1" stop-color="#000000"/></radialGradient></defs>']
    for path in mask.get("paths", []):
        validate_points(path["points"])
        assert 0 < path["width"] < 1
        points = " ".join(f"{x*1000:.2f},{y*1000:.2f}" for x, y in path["points"])
        for scale, color in ((1.4, "#200000"), (1.0, "#740000"), (0.58, "#c80000")):
            text.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="{path["width"]*1000*scale:.2f}" stroke-linecap="round" stroke-linejoin="round"/>')
    for x, y, rx, ry in mask.get("ellipses", []):
        assert all(0 <= v <= 1 for v in (x, y, rx, ry)) and rx > 0 and ry > 0
        text.append(f'<ellipse cx="{x*1000:.2f}" cy="{y*1000:.2f}" rx="{rx*1000:.2f}" ry="{ry*1000:.2f}" fill="url(#soft)"/>')
    assert mask.get("paths") or mask.get("ellipses"), title
    return "\n".join(text + ["</svg>", ""])


def write_card(card):
    layers = card["layers"]
    assert 1 <= len(layers) <= 2
    ext = ['[ext_resource type="Script" path="res://presentation/builds/card_art_motion/profile.gd" id="script"]',
        '[ext_resource type="Shader" path="res://presentation/builds/card_art_motion/local_art.gdshader" id="shader"]']
    subs, bodies = [], []
    for i, layer in enumerate(layers):
        kind = layer["kind"]
        assert kind in ("fire", "ice", "thunder", "energy", "earth")
        suffix = "" if len(layers) == 1 else "_" + kind
        relative = Path(card["category"]) / (card["id"] + suffix + ".svg")
        svg = make_mask(layer["mask"], card["id"] + " / " + kind)
        for directory in (SOURCE / "masks", MASKS):
            path = directory / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(svg, encoding="utf-8")
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/ui/build_cards/v001/motion/{relative.as_posix()}" id="mask_{i}"]')
        params = raw_base(kind)
        params["seed"] = str(zlib.crc32((card["id"] + kind).encode()) & 0x7fffffff)
        for key, value in layer["params"].items():
            params[key] = godot_value(key, value)
        if int(params["particle_count"]) > 0:
            assert "emission_path" in layer["params"], card["id"] + " needs its own particle origin"
        if kind == "ice":
            assert "mist_emission_path" in layer["params"] and "sparkle_points" in layer["params"]
            subs.extend([f'[sub_resource type="FastNoiseLite" id="noise_{i}"]\nseed = 2053\nnoise_type = 1\nfrequency = 0.055\nfractal_octaves = 3',
                f'[sub_resource type="NoiseTexture2D" id="vapor_{i}"]\nwidth = 128\nheight = 128\nseamless = true\nnoise = SubResource("noise_{i}")'])
            params["mist_noise"] = f'SubResource("vapor_{i}")'
        if kind == "thunder":
            assert len(layer["params"]["arc_paths"]) >= 4
            assert "arc_branches" in layer["params"] and "branch_parents" in layer["params"]
        body = ['script = ExtResource("script")', 'shader = ExtResource("shader")', f'mask = ExtResource("mask_{i}")']
        body.extend(key + " = " + value for key, value in params.items())
        bodies.append("\n".join(body))
    if len(layers) == 1:
        resource = "[resource]\n" + bodies[0]
    else:
        for i, body in enumerate(bodies):
            subs.append(f'[sub_resource type="Resource" id="layer_{i}"]\n' + body)
        resource = '[resource]\nscript = ExtResource("script")\nkind = "composite"\nlayers = Array[Resource]([SubResource("layer_0"), SubResource("layer_1")])'
    text = f'[gd_resource type="Resource" load_steps={len(ext)+len(subs)+1} format=3]\n\n' + "\n\n".join(ext + subs + [resource]) + "\n"
    relative = Path("profiles") / card["category"] / (card["id"] + ".tres")
    destination = RUNTIME / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text, encoding="utf-8")
    return "res://presentation/builds/card_art_motion/" + relative.as_posix()


def main():
    catalog_text = (ROOT / "game/presentation/builds/build_card_art_library.tres").read_text(encoding="utf-8")
    catalog = dict(re.findall(r'"([^\"]+)": \{"art": "res://[^\"]+", "category": "([^\"]+)"', catalog_text))
    cards = []
    for path in sorted((SOURCE / "authoring").glob("*.json")):
        cards.extend(json.loads(path.read_text(encoding="utf-8"))["cards"])
    ids = [card["id"] for card in cards]
    assert len(ids) == len(set(ids)), "Duplicate authored cards"
    assert set(ids) == set(catalog) - set(CORE), (set(catalog) - set(CORE) - set(ids), set(ids) - set(catalog))
    paths = {key: "res://presentation/builds/card_art_motion/" + value + ".tres" for key, value in CORE.items()}
    for card in cards:
        assert card["category"] == catalog[card["id"]]
        paths[card["id"]] = write_card(card)
    index = '[gd_resource type="Resource" load_steps=2 format=3]\n[ext_resource type="Script" path="res://presentation/builds/card_art_motion/library.gd" id="script"]\n[resource]\nscript = ExtResource("script")\nprofile_paths = {\n'
    index += ",\n".join(json.dumps(key) + ": " + json.dumps(paths[key]) for key in catalog)
    index += '\n}\nstatic_ids = PackedStringArray()\n'
    (RUNTIME / "library.tres").write_text(index, encoding="utf-8")
    # Existing approved masks keep their authored SVGs; lower only their raster import.
    for kind in CORE.values():
        path = MASKS / (kind + "_mask.svg.import")
        text = path.read_text(encoding="utf-8")
        text = re.sub(r'(?m)^svg/scale=.*$', 'svg/scale=0.35359116022099446', text)
        path.write_text(text, encoding="utf-8")
    print(json.dumps({"animated_cards": len(paths), "new_authored_cards": len(cards), "new_layers": sum(len(c["layers"]) for c in cards), "mask_size": [512, 384]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
