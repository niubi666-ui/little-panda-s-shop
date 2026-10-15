"""One forest run (prototype): schema and references."""
from build_shop_preview_content import ROOT, DATA, read_json, validate


def validate_forest_run(manifest: dict) -> None:
    source = manifest.get("forest_run_file")
    if not isinstance(source, str) or not source.startswith("res://data/run/") or not source.endswith(".json") or ".." in source:
        raise ValueError("manifest: invalid or missing forest_run_file")
    data = read_json(ROOT / "game" / source.removeprefix("res://"))
    validate(data, read_json(DATA / "schemas/forest_run.schema.json"), "forest_run")
    builds = read_json(ROOT / "game" / manifest["build_prototype_file"].removeprefix("res://"))
    elements = read_json(ROOT / "game" / manifest["build_elements_file"].removeprefix("res://"))
    groups = read_json(ROOT / "game" / manifest["build_reward_groups_file"].removeprefix("res://"))
    roles = read_json(ROOT / "game" / manifest["enemy_roles_file"].removeprefix("res://"))
    if data["start_preset"] not in {p["id"] for p in builds["test_presets"]}:
        raise ValueError("forest_run: unknown start_preset")
    if not set(data["boon_elements"]) <= {e["id"] for e in elements["elements"]}:
        raise ValueError("forest_run: unknown boon element")
    for key in ("boon_profile", "upgrade_profile"):
        if data[key] not in groups["reward_profiles"]:
            raise ValueError(f"forest_run: unknown {key}")
    if data["boss_actor_id"] not in {p["actor_id"] for p in roles["profiles"]}:
        raise ValueError("forest_run: unknown boss_actor_id")
    if data["exit_count_min"] > data["exit_count_max"]:
        raise ValueError("forest_run: exit_count_min exceeds exit_count_max")
    if len({r["kind"] for r in data["rewards"]}) != len(data["rewards"]) or sum(r["weight"] for r in data["rewards"]) <= 0:
        raise ValueError("forest_run: rewards need unique kinds and a positive total weight")
