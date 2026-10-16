"""Elements and reactions (data/builds/elements.json): schema, references and field consistency."""
from build_shop_preview_content import ROOT, DATA, read_json, validate


def validate_elements(manifest: dict) -> None:
    source = manifest.get("build_elements_file")
    if not isinstance(source, str) or not source.startswith("res://data/builds/") or not source.endswith(".json") or ".." in source:
        raise ValueError("manifest: invalid or missing build_elements_file")
    data = read_json(ROOT / "game" / source.removeprefix("res://"))
    validate(data, read_json(DATA / "schemas/build_elements.schema.json"), "elements")
    builds = read_json(ROOT / "game" / manifest["build_prototype_file"].removeprefix("res://"))
    statuses = {s["id"]: s for s in builds["statuses"]}
    elements = {}
    for e in data["elements"]:
        if e["id"] in elements:
            raise ValueError(f"elements: duplicate {e['id']}")
        elements[e["id"]] = e
        if (e["tick_sec"] > 0) != (e["damage_per_tick_per_stack"] > 0):
            raise ValueError(f"elements: {e['id']} tick fields must both be set or both 0")
        if (e["discharge_damage"] > 0) != (e["discharge_radius_m"] > 0 and e["discharge_max_targets"] > 0):
            raise ValueError(f"elements: {e['id']} discharge fields must all be set or all 0")
        for key, kind in (("slow_status_id", "slow"), ("freeze_status_id", "freeze")):
            if e[key] and (e[key] not in statuses or statuses[e[key]]["kind"] != kind):
                raise ValueError(f"elements: {e['id']}.{key} must name a {kind} status")
    pairs = set()
    for r in data["reactions"]:
        a, b = r["elements"]
        if a == b or a not in elements or b not in elements:
            raise ValueError(f"elements: reaction {r['id']} needs two different known elements")
        required, trigger = r['required_status_id'], r['trigger_element_id']
        if trigger and trigger not in r['elements']:
            raise ValueError(f"elements: reaction {r['id']} trigger must belong to reaction")
        if required:
            if required not in statuses or statuses[required]['kind'] != 'freeze':
                raise ValueError(f"elements: reaction {r['id']} requires a freeze status")
            if not trigger or not any(elements[e]['freeze_status_id'] == required and e != trigger for e in r['elements']):
                raise ValueError(f"elements: reaction {r['id']} requires a trigger and a different freeze provider")
        key = tuple(sorted((a, b)))
        if key in pairs:
            raise ValueError(f"elements: duplicate reaction for {key}")
        pairs.add(key)
        if (r["radius_m"] > 0) != (r["max_targets"] > 0):
            raise ValueError(f"elements: reaction {r['id']} radius/max_targets mismatch")
        zone = [r["zone_radius_m"], r["zone_sec"], r["zone_tick_sec"], r["zone_damage_per_tick"]]
        if any(v > 0 for v in zone) and not all(v > 0 for v in zone):
            raise ValueError(f"elements: reaction {r['id']} zone fields must all be set or all 0")
    boostable = {"max_stacks", "duration_sec", "damage_per_tick_per_stack", "discharge_damage", "discharge_radius_m", "discharge_max_targets", "damage_taken_per_stack", "poise_damage_ratio"}
    reaction_ids = {r["id"] for r in data["reactions"]}
    for entry in builds["upgrades"]:
        for rank in entry["ranks"]:
            if entry["effect_type"] in ("element", "element_boost") and rank["element_id"] not in elements:
                raise ValueError(f"elements: upgrade {entry['id']} names unknown element")
            if entry["effect_type"] == "element_boost" and rank["field"] not in boostable:
                raise ValueError(f"elements: upgrade {entry['id']} boosts an unsupported field")
            if entry["effect_type"] == "reaction_boost" and rank["reaction_id"] not in reaction_ids:
                raise ValueError(f"elements: upgrade {entry['id']} names unknown reaction")
    for lang in ("zh_CN", "en"):
        messages = read_json(DATA / f"locales/{lang}.json")["messages"]
        for key in [e["name_key"] for e in elements.values()] + [r["name_key"] for r in data["reactions"]]:
            if key not in messages:
                raise ValueError(f"elements: {key} missing {lang} translation")
