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
    "build.preset.title": set(),
    "build.preset.hint": set(),
    "build.preset.applied": {"name"},
    "build.preset.error": set(),
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
    combat = read_json(ROOT / "game" / manifest["combat_prototype_file"].removeprefix("res://"))
    ability_ids = {a["id"] for a in combat["abilities"]}
    for form in data["forms"]:
        if set(form["ability_ids"]) - ability_ids:
            raise ValueError("unknown combat ability in form " + form["id"])
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
    groups = data["status_rules"]["control_groups"]
    if len(groups) != 1 or groups[0]["kind"] != "freeze":
        raise ValueError("exactly one shared freeze control group required")
    for status in statuses.values():
        if status["kind"] == "freeze" and (
            status["control_group"] != groups[0]["id"] or status["refresh"] != "reject_active"
        ):
            raise ValueError("all freeze statuses must reject refresh and share the validated group")
        if status["kind"] == "slow" and (status["control_group"] or status["refresh"] != "longest"):
            raise ValueError("slow requires longest refresh and no control group")
    for response in [data["status_rules"]["default_response_id"], *data["status_rules"]["actor_responses"].values()]:
        if response not in responses:
            raise ValueError("unknown status response")
    for entry in data["upgrades"]:
        if entry["effect_type"] in ("status", "status_duration", "area_status"):
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
    area_status_sources = set()
    for entry in upgrades:
        location = f"build.upgrades.{entry['id']}"
        for rank in entry["ranks"]:
            for selector in ("allowed_origins", "status_id", "source_effect_id"):
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
        if entry["effect_type"] == "pierce":
            if any(rank["max_hits"] > limits["max_projectile_hits"] for rank in entry["ranks"]):
                raise ValueError(f"{location}: max_hits exceeds projectile hit limit")
            for other in upgrades:
                if other["effect_type"] == "split" and (
                    other["id"] not in entry["excludes"] or entry["id"] not in other["excludes"]
                ):
                    raise ValueError("all pierce/split definitions require symmetric exclusion")
        if entry["effect_type"] == "area_status":
            rank = entry["ranks"][0]
            source_id = rank["source_effect_id"]
            source = by_id.get(source_id)
            if not source or source["effect_type"] != "explosion":
                raise ValueError("area status requires an explosion source")
            if source_id not in entry["requires"]:
                raise ValueError("area status must require its explosion source")
            if not set(rank["allowed_origins"]) & set(source["ranks"][0]["allowed_origins"]):
                raise ValueError("area status has no compatible source origin")
            if source_id in area_status_sources:
                raise ValueError("only one area status definition is supported per explosion source")
            area_status_sources.add(source_id)
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
    _validate_actions(data, by_id)
    _validate_reachability(data, by_id)
    _validate_presets(data, by_id)


def _validate_presets(data: dict, by_id: dict) -> None:
    ids = set()
    actions = {a["id"]: a for a in data["actions"]}
    for preset in data["test_presets"]:
        if preset["id"] in ids:
            raise ValueError("duplicate test preset id")
        ids.add(preset["id"])
        selected, slots = {}, set()
        for item in preset["selections"]:
            entry = by_id.get(item["upgrade_id"])
            target = item["action_id"]
            if not entry or entry["test_only"]:
                raise ValueError("preset unknown/debug upgrade")
            if (entry["scope"] == "global" and target != "global") or (entry["scope"] == "action" and target not in entry["action_ids"]):
                raise ValueError("preset wrong action binding")
            if target != "global" and actions[target]["test_only"]:
                raise ValueError("preset debug target forbidden")
            identity = (target, entry["id"])
            if identity in selected or not 1 <= item["rank"] <= entry["max_rank"]:
                raise ValueError("preset duplicate binding or invalid rank")
            selected[identity] = item
            if entry["layer"] in ("form", "core"):
                slot = (target, entry["layer"])
                if slot in slots: raise ValueError("preset duplicate slot")
                slots.add(slot)
        for (target, id), item in selected.items():
            entry = by_id[id]
            if any((target, required) not in selected for required in entry["requires"]):
                raise ValueError("preset missing bound prerequisite")
            if any((target, excluded) in selected for excluded in entry["excludes"]):
                raise ValueError("preset incompatible bound upgrade")

        _validate_preset_capabilities(data, preset, by_id)


def _validate_preset_capabilities(data: dict, preset: dict, by_id: dict) -> None:
    # Static content proof, not reward evaluation or state mutation. Runtime
    # preflights every preset through the same combat evaluator as real choices.
    forms = {f["id"]: f for f in data["forms"]}
    projectiles = {p["id"]: p for p in data["projectiles"]}
    for action in data["actions"]:
        items = [s for s in preset["selections"] if s["action_id"] == action["id"]]
        selected = [(by_id[s["upgrade_id"]], by_id[s["upgrade_id"]]["ranks"][s["rank"]-1]) for s in items]
        form_id = action["base_form_id"]
        for entry, params in selected:
            if entry["effect_type"] == "form": form_id = params["form_id"]
        form = forms[form_id]
        projectile = projectiles.get(form["projectile_id"])
        origins = {"direct_projectile" if projectile else "direct_melee"}
        types = {e["effect_type"] for e, _ in selected}
        if "split" in types:
            if not projectile or not projectile["child_id"]: raise ValueError("preset split needs a real child-producing carrier")
            origins.add("split_projectile")
            if "pierce" in types or "area_status" in types: raise ValueError("preset unsupported complete contact strategy")
        if "pierce" in types and not projectile: raise ValueError("preset pierce needs same-action projectile")
        tags = {tag for e, _ in selected for tag in e["granted_tags"]}
        status_ids = set()
        for entry, params in selected:
            if not set(entry["required_tags"]) <= tags: raise ValueError("preset missing same-action tag")
            if entry["effect_type"] in ("status", "explosion") and not origins.intersection(params["allowed_origins"]):
                raise ValueError("preset impact has no compatible carrier")
            if entry["effect_type"] == "status": status_ids.add(params["status_id"])
            if entry["effect_type"] == "area_status":
                source = next((p for e, p in selected if e["id"] == params["source_effect_id"]), None)
                if not source or not origins.intersection(params["allowed_origins"], source["allowed_origins"]):
                    raise ValueError("preset area status has no compatible same-action source")
                status_ids.add(params["status_id"])
        for entry, params in selected:
            if entry["effect_type"] == "status_duration" and params["status_id"] not in status_ids:
                raise ValueError("preset duration has no same-action status carrier")


def _validate_actions(data: dict, by_id: dict) -> None:
    actions = {a["id"]: a for a in data["actions"]}
    forms = {f["id"]: f for f in data["forms"]}
    projectiles = {p["id"]: p for p in data["projectiles"]}
    if len(actions) != len(data["actions"]) or "global" in actions or len(forms) != len(data["forms"]):
        raise ValueError("duplicate/reserved action or form ID")
    for form in forms.values():
        if form["executor"] == "projectile" and form["projectile_id"] not in projectiles:
            raise ValueError("unknown form projectile")
        if form["executor"] == "melee" and (form["projectile_id"] or not form["ability_ids"]):
            raise ValueError("melee form needs abilities and no projectile")
    for action in actions.values():
        if action["base_form_id"] not in action["form_ids"] or set(action["form_ids"]) - forms.keys():
            raise ValueError("invalid action form references")
    for attack in data["test_attacks"]:
        action = actions.get(attack["action_id"])
        if not action or not action["test_only"] or forms[action["base_form_id"]]["projectile_id"] != attack["projectile_id"]:
            raise ValueError("test attack needs matching isolated debug action")
    for entry in by_id.values():
        if entry["scope"] == "global":
            if entry["action_ids"] or entry["layer"] != "support" or entry["effect_type"] not in ("move_scale", "damage_scale"):
                raise ValueError("global supports only unbound numeric actor stats")
        else:
            if not entry["action_ids"] or entry["effect_type"] == "move_scale" or set(entry["action_ids"]) - actions.keys():
                raise ValueError("invalid upgrade action targets")
            if entry["test_only"] and any(not actions[id]["test_only"] for id in entry["action_ids"]):
                raise ValueError("debug upgrade targets formal action")
        expected = "form" if entry["effect_type"] == "form" else ("core" if entry["effect_type"] in ("status", "explosion") else ("synergy" if entry["effect_type"] == "area_status" else "support"))
        if entry["layer"] != expected:
            raise ValueError("effect type and layer disagree")
        if entry["effect_type"] in ("projectile", "chain") and not entry["test_only"]:
            raise ValueError("legacy projectile/chain restricted to fixture")
        if entry["effect_type"] == "form":
            for rank in entry["ranks"]:
                if rank["form_id"] not in forms or any(rank["form_id"] not in actions[target]["form_ids"] for target in entry["action_ids"]):
                    raise ValueError("invalid form grant target")
    for id in data["offer"]["pool_ids"] + data["offer"]["fallback_ids"]:
        if by_id[id]["test_only"]:
            raise ValueError("debug upgrade in formal pool")


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
    for definition in data["actions"] + data["forms"]:
        if _translated_fields(locales, definition["name_key"]):
            raise ValueError("action/form name cannot contain placeholders")
    for preset in data["test_presets"]:
        if _translated_fields(locales, preset["name_key"]):
            raise ValueError("test_preset.name_key must not contain placeholders")
    for entry in data["upgrades"]:
        if _translated_fields(locales, entry["name_key"]):
            raise ValueError(f"build: {entry['name_key']} must not contain placeholders")
        required = _translated_fields(locales, entry["description_key"])
        for rank_index, rank in enumerate(entry["ranks"], start=1):
            supplied = set(rank) | {"rank", "max_rank"}
            if entry["effect_type"] in ("status", "area_status"):
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
