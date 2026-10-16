"""One forest run (prototype): schema and references."""
from build_shop_preview_content import ROOT, DATA, read_json, validate


def validate_forest_run(manifest: dict) -> None:
    source = manifest.get("forest_run_file")
    if not isinstance(source, str) or not source.startswith("res://data/run/") or not source.endswith(".json") or ".." in source:
        raise ValueError("manifest: invalid or missing forest_run_file")
    data = read_json(ROOT / "game" / source.removeprefix("res://"))
    validate(data, read_json(DATA / "schemas/forest_run.schema.json"), "forest_run")
    validate(data["map"], read_json(DATA / "schemas/map_preview.schema.json"), "forest_run.map")
    builds = read_json(ROOT / "game" / manifest["build_prototype_file"].removeprefix("res://"))
    groups = read_json(ROOT / "game" / manifest["build_reward_groups_file"].removeprefix("res://"))
    roles = read_json(ROOT / "game" / manifest["enemy_roles_file"].removeprefix("res://"))
    if data["start_preset"] not in {p["id"] for p in builds["test_presets"]}:
        raise ValueError("forest_run: unknown start_preset")
    profiles = [data[k] for k in ("battle_profile", "elite_profile", "boss_profile", "upgrade_profile")]
    profiles += [data["event"]["card_profile"], data["event"]["blood_card_profile"], data["shop"]["card_profile"]]
    for profile in profiles:
        if profile not in groups["reward_profiles"]:
            raise ValueError(f"forest_run: unknown reward profile {profile}")
    actors = {p["actor_id"] for p in roles["profiles"]}
    for area in data["areas"]:
        if area["boss_actor_id"] not in actors:
            raise ValueError("forest_run: unknown boss_actor_id")
    if data["awakening_after_area"] >= len(data["areas"]):
        raise ValueError("forest_run: awakening_after_area outside areas")
    outcomes = data["event"]["outcomes"]
    if len({o["kind"] for o in outcomes}) != len(outcomes) or sum(o["weight"] for o in outcomes) <= 0:
        raise ValueError("forest_run: event outcomes need unique kinds and a positive total weight")
    rows = data["map"]["rows"]
    for kind in data["map"]["room_types"]:
        if kind["max_layer"] >= rows or kind["min_layer"] > kind["max_layer"]:
            raise ValueError("forest_run.map: room type layers outside rows")
