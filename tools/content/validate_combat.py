"""Strict schema, reference and translation validation for implemented combat only."""
from build_shop_preview_content import ROOT, DATA, read_json, validate

def validate_combat(manifest):
    data = read_json(ROOT / "game" / manifest["combat_prototype_file"].removeprefix("res://"))
    validate(data, read_json(DATA / "schemas/combat_prototype.schema.json"), "combat")
    abilities = {entry["id"] for entry in data["abilities"]}
    actors = {entry["id"] for entry in data["actors"]}
    if len(abilities) != len(data["abilities"]) or len(actors) != len(data["actors"]):
        raise ValueError("combat: duplicate IDs")
    if data["player_id"] not in actors:
        raise ValueError("combat: unknown player_id")
    for ability in data["abilities"]:
        if len(set(ability["dodge_cancel_phases"])) != len(ability["dodge_cancel_phases"]):
            raise ValueError(f"combat: {ability['id']} duplicate dodge cancel phase")
        if ability["hit_shape"] == "sector" and (ability["angle_deg"] <= 0 or ability["thrust_width_m"] != 0):
            raise ValueError(f"combat: {ability['id']} sector requires positive angle and zero thrust width")
        if ability["hit_shape"] == "thrust" and (ability["angle_deg"] != 0 or ability["thrust_width_m"] <= 0):
            raise ValueError(f"combat: {ability['id']} thrust requires zero angle and positive width")
        if (ability["knockback_speed_mps"] == 0) != (ability["knockback_duration_sec"] == 0):
            raise ValueError(f"combat: {ability['id']} knockback speed/duration mismatch")
    for actor in data["actors"]:
        if not set(actor["attack_ids"]) <= abilities:
            raise ValueError(f"combat: {actor['id']} unknown ability")
        for lang in ("zh_CN", "en"):
            if actor["name_key"] not in read_json(DATA / f"locales/{lang}.json")["messages"]:
                raise ValueError(f"combat: {actor['name_key']} missing translation")
    for wave in data["waves"]:
        if not set(wave) <= actors - {data["player_id"]}:
            raise ValueError("combat: unknown enemy in wave")
    if data["dodge"]["invulnerable_sec"] > data["dodge"]["duration_sec"]:
        raise ValueError("combat: invulnerability exceeds dodge duration")
