"""Strict offline validation of the implemented training build definitions.

The runtime counterpart is game/content/builds/build_loader.gd. This module also
checks localization placeholders against the parameters supplied by the choice UI.
"""

from __future__ import annotations

from build_shop_preview_content import DATA, ROOT, placeholders, read_json, validate


UI_PARAMETERS = {
    "build.title": set(),
    "build.test.arrow_hint": set(),
    "build.test.mechanism_hint": set(),
    "build.subtitle": set(),
    "build.choose": set(),
    "build.rank": {"rank", "max_rank"},
    "build.owned": set(),
    "build.empty": set(),
    "build.error": set(),
    "build.test_offer": set(),
    "build.next": {"rank"},
    "build.no_candidates": set(),
    "combat.choosing": set(),
}


def validate_builds(manifest: dict) -> None:
    """Raise ValueError for invalid schema, references, budgets or translations."""
    source = manifest.get("build_prototype_file")
    if (
        not isinstance(source, str)
        or not source.startswith("res://data/builds/")
        or not source.endswith(".json")
        or ".." in source
    ):
        raise ValueError("manifest: invalid or missing build_prototype_file")
    path = ROOT / "game" / source.removeprefix("res://")
    data = read_json(path)
    validate(data, read_json(DATA / "schemas/build_prototype.schema.json"), "build")
    _validate_semantics(data)
    if data["status_rules"]["actor_responses"]:
        actors = read_json(ROOT / "game" / manifest["combat_prototype_file"].removeprefix("res://"))["actors"]
        if set(data["status_rules"]["actor_responses"]) - {a["id"] for a in actors}:
            raise ValueError("unknown status response actor")
    locales = {}
    for locale in ("zh_CN", "en"):
        source_locale = read_json(DATA / f"locales/{locale}.json")
        if source_locale.get("locale") != locale:
            raise ValueError(f"build: locale filename and identifier differ: {locale}")
        messages = source_locale.get("messages")
        if not isinstance(messages, dict):
            raise ValueError(f"build: {locale} messages must be an object")
        locales[locale] = messages
    _validate_messages(data, locales)


def _validate_semantics(data: dict) -> None:
    definitions = {d["id"]: d for d in data["projectiles"]}
    if len(definitions) != len(data["projectiles"]):
        raise ValueError("duplicate projectile id")
    for definition in definitions.values():
        if definition["child_id"] and definition["child_id"] not in definitions:
            raise ValueError("unknown child projectile")
    ids = set()
    for attack in data["test_attacks"]:
        if attack["id"] in ids or attack["projectile_id"] not in definitions:
            raise ValueError("invalid test attack reference/id")
        ids.add(attack["id"])
    for entry in data["upgrades"]:
        if entry["effect_type"] == "projectile":
            for rank in entry["ranks"]:
                if rank["projectile_id"] not in definitions:
                    raise ValueError("unknown upgrade projectile")
    statuses = {s["id"]: s for s in data["statuses"]}
    responses = {v["id"]: v for v in data["status_rules"]["responses"]}
    if len(statuses) != len(data["statuses"]) or len(responses) != len(data["status_rules"]["responses"]):
        raise ValueError("duplicate status/response")
    for status in statuses.values():
        if status["duration_sec"] > status["max_duration_sec"] or (status["kind"] == "freeze" and status["move_scale"] != 0) or (status["kind"] == "slow" and status["move_scale"] <= 0):
            raise ValueError("invalid status duration/movement")
    for response in [data["status_rules"]["default_response_id"], *data["status_rules"]["actor_responses"].values()]:
        if response not in responses:
            raise ValueError("unknown status response")
    for entry in data["upgrades"]:
        if entry["effect_type"] in ("status", "status_duration"):
            for rank in entry["ranks"]:
                if rank["status_id"] not in statuses:
                    raise ValueError("unknown status reference")
    upgrades = data["upgrades"]
    by_id = {entry["id"]: entry for entry in upgrades}
    if len(by_id) != len(upgrades):
        raise ValueError("build.upgrades: duplicate id")
    offer = data["offer"]
    limits = data["limits"]
    stats = data["stats"]
    if (
        offer["initial_offers"] > offer["max_queued_offers"]
        or offer["rewards_per_wave"] > offer["max_queued_offers"]
    ):
        raise ValueError("build.offer: initial/reward offers exceed queue limit")
    if limits["max_projectiles_per_root"] > limits["max_projectiles"]:
        raise ValueError("build.limits: per-root projectiles exceed global limit")
    for prefix in ("damage", "move"):
        low, high = stats[f"{prefix}_scale_min"], stats[f"{prefix}_scale_max"]
        if low > high:
            raise ValueError(f"build.stats: {prefix} minimum exceeds maximum")
        if not low <= 1 <= high:
            raise ValueError(f"build.stats: {prefix} range excludes unmodified scale 1")
    for field in ("pool_ids", "fallback_ids"):
        unknown = set(offer[field]) - by_id.keys()
        if unknown:
            raise ValueError(f"build.offer.{field}: unknown IDs {sorted(unknown)}")
    available_tags = {tag for entry in upgrades for tag in entry["granted_tags"]}
    for entry in upgrades:
        location = f"build.upgrades.{entry['id']}"
        for rank in entry["ranks"]:
            for selector in ("allowed_origins", "status_id"):
                if selector in rank and rank[selector] != entry["ranks"][0][selector]:
                    raise ValueError("effect selectors must remain stable across ranks")
        if len(entry["ranks"]) != entry["max_rank"]:
            raise ValueError(f"{location}.ranks: length must equal max_rank")
        for field in ("requires", "excludes"):
            for referenced in entry[field]:
                if referenced not in by_id or referenced == entry["id"]:
                    raise ValueError(f"{location}.{field}: invalid reference {referenced}")
                if field == "excludes" and entry["id"] not in by_id[referenced]["excludes"]:
                    raise ValueError(f"{location}: exclusion must be symmetric with {referenced}")
        if set(entry["requires"]) & set(entry["excludes"]):
            raise ValueError(f"{location}: required upgrade is excluded")
        unknown_tags = set(entry["required_tags"]) - available_tags
        if unknown_tags:
            raise ValueError(f"{location}: unknown required tags {sorted(unknown_tags)}")
        if entry["effect_type"] in ("explosion", "status"):
            for rank in entry["ranks"]:
                if not rank["max_per_parent"] <= rank["max_per_root"] <= limits["root_effect_budget"]:
                    raise ValueError("explosion trigger limits inconsistent")
        if entry["effect_type"] == "chain":
            if any(rank["jumps"] > limits["max_chain_jumps"] for rank in entry["ranks"]):
                raise ValueError(f"{location}: jumps exceed limit")
        if entry["effect_type"] == "split":
            for rank in entry["ranks"]:
                if (
                    rank["max_generation"] > limits["max_split_generation"]
                    or rank["count"] > limits["max_projectiles_per_root"]
                    or rank["count"] > limits["max_projectiles"]
                ):
                    raise ValueError(f"{location}: split exceeds limits")
    visiting, visited = set(), set()

    def visit(upgrade_id: str) -> None:
        if upgrade_id in visiting:
            raise ValueError(f"build.upgrades.{upgrade_id}: prerequisite cycle")
        if upgrade_id in visited:
            return
        visiting.add(upgrade_id)
        for required in by_id[upgrade_id]["requires"]:
            visit(required)
        visiting.remove(upgrade_id)
        visited.add(upgrade_id)

    for upgrade_id in by_id:
        visit(upgrade_id)
    _validate_reachability(data, by_id)


def _validate_reachability(data: dict, by_id: dict) -> None:
    # Mirror the sampler: zero-weight random entries cannot supply prerequisites;
    # an explicit fallback remains obtainable irrespective of its random weight.
    remaining = {
        upgrade_id for upgrade_id in data["offer"]["pool_ids"]
        if by_id[upgrade_id]["weight"] > 0
    } | set(data["offer"]["fallback_ids"])
    reached, tags = set(), set()
    changed = True
    while changed:
        changed = False
        for upgrade_id in sorted(remaining):
            entry = by_id[upgrade_id]
            if set(entry["requires"]) <= reached and set(entry["required_tags"]) <= tags:
                reached.add(upgrade_id)
                tags.update(entry["granted_tags"])
                remaining.remove(upgrade_id)
                changed = True
    # This overapproximates reachability across mutually exclusive branches.
    # It deliberately does not reject individually obtainable alternate builds.
    if remaining:
        raise ValueError(
            "build.upgrades: unreachable prerequisites/tags in configured offer pool: "
            + ", ".join(sorted(remaining))
        )


def _translated_fields(locales: dict, key: str) -> set[str]:
    fields_by_locale = {}
    for locale, messages in locales.items():
        message = messages.get(key)
        if not isinstance(message, str) or not message.strip():
            raise ValueError(f"build: missing or empty {locale} translation {key}")
        fields_by_locale[locale] = placeholders(message, f"{locale}.{key}")
    if fields_by_locale["zh_CN"] != fields_by_locale["en"]:
        raise ValueError(f"build: {key} named placeholders differ across languages")
    return fields_by_locale["zh_CN"]


def _validate_messages(data: dict, locales: dict) -> None:
    for key, expected in UI_PARAMETERS.items():
        actual = _translated_fields(locales, key)
        if actual != expected:
            raise ValueError(
                f"build: {key} expects placeholders {sorted(expected)}, got {sorted(actual)}"
            )
    for entry in data["upgrades"]:
        if _translated_fields(locales, entry["name_key"]):
            raise ValueError(f"build: {entry['name_key']} must not contain placeholders")
        required = _translated_fields(locales, entry["description_key"])
        for rank_index, rank in enumerate(entry["ranks"], start=1):
            supplied = set(rank) | {"rank", "max_rank"}
            if entry["effect_type"] == "status":
                supplied |= {"duration_sec", "slow_percent"}
            # Keep in sync with BuildChoicePanel.refresh_text(); no defaults or
            # unrelated effect parameters are implicitly available to messages.
            for parameter, derived in (
                ("bonus", "bonus_percent"),
                ("damage_ratio", "damage_percent"),
                ("falloff", "falloff_percent"),
            ):
                if parameter in rank:
                    supplied.add(derived)
            missing = required - supplied
            if missing:
                raise ValueError(
                    f"build: {entry['description_key']} rank {rank_index} references "
                    f"unavailable parameters {sorted(missing)}"
                )
