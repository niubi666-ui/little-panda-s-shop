"""Strict offline validation for the authored short route (no Run persistence)."""
from __future__ import annotations

import argparse
import copy
import json
import re
from pathlib import Path

from build_shop_preview_content import (
    ROOT, DATA, read_json, validate, object_without_duplicates, finite_float,
    reject_constant,
)


def validate_route(data: dict, preset_ids: set[str], max_depth: int,
                   template_ids: set[str]) -> None:
    validate(data, read_json(DATA / "schemas/run_route.schema.json"), "run_route")
    if data["starter_build_preset"] not in preset_ids:
        raise ValueError("route.starter_build_preset: unknown preset")
    nodes = {n["id"]: n for n in data["nodes"]}
    if len(nodes) != len(data["nodes"]):
        raise ValueError("route.nodes: duplicate ID")
    if len({(n["layer"], n["column"]) for n in nodes.values()}) != len(nodes):
        raise ValueError("route.nodes: duplicate layer/column cell")
    terminals = [n["id"] for n in nodes.values() if n["kind"] == "terminal"]
    if len(terminals) != 1:
        raise ValueError("route: exactly one terminal required")
    for node in nodes.values():
        if node["template_id"] not in template_ids:
            raise ValueError(f"route.nodes.{node['id']}: unknown template")
        if node["depth"] > max_depth:
            raise ValueError(f"route.nodes.{node['id']}: configured encounter depth cap exceeded")
    incoming = {id: [] for id in nodes}
    outgoing = {id: [] for id in nodes}
    edges = set()
    for edge in data["edges"]:
        a, b = edge["from"], edge["to"]
        if a not in nodes or b not in nodes or (a, b) in edges:
            raise ValueError("route.edges: unknown node or duplicate connection")
        edges.add((a, b))
        if nodes[b]["layer"] != nodes[a]["layer"] + 1:
            raise ValueError("route.edges: connections must advance exactly one layer")
        if nodes[b]["depth"] <= nodes[a]["depth"]:
            raise ValueError("route.edges: encounter depth must increase")
        outgoing[a].append(b)
        incoming[b].append(a)
    starts = data["start_node_ids"]
    for id in starts:
        if id not in nodes or nodes[id]["layer"] != 0 or incoming[id]:
            raise ValueError("route.start_node_ids: starts must be layer-zero roots")
    for id in nodes:
        if not incoming[id] and id not in starts:
            raise ValueError("route: undeclared disconnected root")
        if id == terminals[0]:
            if outgoing[id]: raise ValueError("route: terminal has outgoing edges")
        elif not outgoing[id]:
            raise ValueError("route: nonterminal dead end")

    def walk(roots: list[str], adjacency: dict) -> set[str]:
        reached, queue = set(), list(roots)
        while queue:
            node = queue.pop()
            if node in reached: continue
            reached.add(node)
            queue.extend(adjacency[node])
        return reached

    if walk(starts, outgoing) != set(nodes) or walk(terminals, incoming) != set(nodes):
        raise ValueError("route: each node must be reachable from starts and lead to terminal")


def template_ids_from_resource(text: str, label: str) -> tuple[str, ...]:
    """Read only the library's explicit String -> ExtResource mapping.

    This is deliberately not a general TRES evaluator: unrecognised room values,
    duplicate keys/assignments and unresolved Resource references are errors.
    """
    sections = re.split(r"(?m)^\[resource\][ \t]*$", text)
    if len(sections) != 2:
        raise ValueError(f"{label}: exactly one [resource] section required")
    main = sections[1]
    if len(re.findall(r"(?m)^[ \t]*rooms[ \t]*=", main)) != 1:
        raise ValueError(f"{label}: exactly one rooms assignment required")
    mapping = re.search(
        r"(?ms)^[ \t]*rooms[ \t]*=[ \t]*Dictionary\[\s*String\s*,\s*Resource\s*\]"
        r"\s*\(\s*\{(.*?)\}\s*\)[ \t]*(?:\n|$)", main,
    )
    if mapping is None:
        raise ValueError(f"{label}: rooms must use Dictionary[String, Resource]({{...}})")
    resources = {}
    for declaration in re.finditer(r"(?m)^\[ext_resource\s+(.*?)\][ \t]*$", sections[0]):
        attributes = dict(re.findall(r'(\w+)="([^"\r\n]*)"', declaration.group(1)))
        id = attributes.get("id")
        if not id or id in resources:
            raise ValueError(f"{label}: missing/duplicate ExtResource ID")
        resources[id] = attributes
    body = mapping.group(1).strip()
    entry = re.compile(
        r'\s*"([a-z][a-z0-9_.-]{0,127})"\s*:\s*ExtResource\(\s*"([^"\\\r\n]+)"\s*\)\s*(,|$)'
    )
    keys, offset = [], 0
    while offset < len(body):
        match = entry.match(body, offset)
        if match is None:
            raise ValueError(f"{label}: unsupported rooms entry near offset {offset}")
        key, ref = match.group(1, 2)
        if key in keys:
            raise ValueError(f"{label}: duplicate room template ID {key}")
        resource = resources.get(ref, {})
        path = resource.get("path", "")
        if resource.get("type") != "Resource" or not path.startswith("res://") or ".." in path or not (ROOT / "game" / path.removeprefix("res://")).is_file():
            raise ValueError(f"{label}: unresolved Resource for template {key}: {ref}")
        keys.append(key)
        offset = match.end()
        if not body[offset:].strip(): break
    if not keys:
        raise ValueError(f"{label}: rooms mapping is empty")
    return tuple(keys)


def read_template_ids(path: Path = ROOT / "game/app/run_templates.tres") -> tuple[str, ...]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise ValueError(f"{path}: cannot read template library: {error}") from error
    return template_ids_from_resource(text, str(path))


def validate_run(manifest: dict, template_ids: tuple[str, ...] | None = None) -> dict:
    if template_ids is None:
        template_ids = read_template_ids()
    source = manifest.get("run_route_file")
    if not isinstance(source, str) or not source.startswith("res://data/run/") or not source.endswith(".json") or ".." in source:
        raise ValueError("manifest: invalid or missing run_route_file")
    data = read_json(ROOT / "game" / source.removeprefix("res://"))
    builds = read_json(ROOT / "game" / manifest["build_prototype_file"].removeprefix("res://"))
    enemies = read_json(ROOT / "game" / manifest["encounters_file"].removeprefix("res://"))
    validate_route(data, {p["id"] for p in builds["test_presets"]}, enemies["training_max_depth"], set(template_ids))
    return data


def self_test(manifest: dict) -> int:
    base = validate_run(manifest)
    builds = read_json(ROOT / "game" / manifest["build_prototype_file"].removeprefix("res://"))
    enemies = read_json(ROOT / "game" / manifest["encounters_file"].removeprefix("res://"))
    presets = {p["id"] for p in builds["test_presets"]}
    count = 0

    def reject(label, edit):
        nonlocal count
        data = copy.deepcopy(base)
        edit(data)
        try:
            validate_route(data, presets, enemies["training_max_depth"], {"graybox"})
        except ValueError:
            count += 1
            return
        raise AssertionError("accepted illegal fixture: " + label)

    reject("wrong version", lambda d: d.update(schema_version=2))
    reject("unknown field", lambda d: d.update(extra=True))
    reject("duplicate node", lambda d: d["nodes"].append(copy.deepcopy(d["nodes"][0])))
    reject("duplicate cell", lambda d: d["nodes"][2].update(column=d["nodes"][1]["column"]))
    reject("unknown template", lambda d: d["nodes"][0].update(template_id="missing"))
    reject("missing preset", lambda d: d.update(starter_build_preset="missing"))
    reject("depth cap", lambda d: d["nodes"][-1].update(depth=enemies["training_max_depth"] + 1))
    reject("fractional depth", lambda d: d["nodes"][0].update(depth=1.5))
    reject("unsupported boss", lambda d: d["nodes"][0].update(kind="boss"))
    reject("unsupported reward", lambda d: d["rewards"][0].update(kind="major_build"))
    reject("node reward", lambda d: d["nodes"][0].update(reward_id="major_build"))
    reject("unknown edge", lambda d: d["edges"][0].update(to="missing"))
    reject("duplicate edge", lambda d: d["edges"].append(copy.deepcopy(d["edges"][0])))
    reject("backward edge", lambda d: d["edges"].append({"from": "terminal", "to": "entry"}))
    reject("skipped layer", lambda d: d["edges"][0].update(to="junction"))
    reject("no terminal", lambda d: d["nodes"][-1].update(kind="battle"))
    reject("two terminals", lambda d: d["nodes"][1].update(kind="terminal"))
    reject("dead branch", lambda d: d["edges"].pop(2))
    reject("unreachable branch", lambda d: d["edges"].pop(0))
    reject("bad start", lambda d: d.update(start_node_ids=["branch_left"]))
    reject("nonascending depth", lambda d: d["nodes"][1].update(depth=d["nodes"][0]["depth"]))
    for text in ["", '{"id":1,"id":2}', '{"id":1,"\\u0069d":2}', '{"x":1,}', '[1,]', '{"x":01}', '{"x":NaN}', '{"x":1e999}']:
        try:
            json.loads(text, object_pairs_hook=object_without_duplicates, parse_float=finite_float, parse_constant=reject_constant)
        except ValueError:
            count += 1
            continue
        raise AssertionError("accepted invalid JSON fixture: " + text)
    library = (ROOT / "game/app/run_templates.tres").read_text(encoding="utf-8")
    ids = template_ids_from_resource(library, "library fixture")
    # Rename only the authored map key, retaining the exact referenced resource.
    renamed = library.replace(f'"{ids[0]}":', '"other_room":', 1)
    if "other_room" not in template_ids_from_resource(renamed, "renamed fixture"):
        raise AssertionError("new map keys must not require Python code changes")
    # Explicit fixture syntax, with a real resource path discovered from the
    # current library: changing its keys/ExtResource IDs does not break tests.
    resource_path = next(
        attrs["path"] for match in re.finditer(r"(?m)^\[ext_resource\s+(.*?)\][ \t]*$", library)
        if (attrs := dict(re.findall(r'(\w+)="([^"\r\n]*)"', match.group(1)))).get("type") == "Resource"
    )
    fixture = (f'[ext_resource type="Resource" path="{resource_path}" id="room"]\n'
               '[resource]\nrooms = Dictionary[String, Resource]({"fixture_room": ExtResource("room")})\n')
    bad_libraries = [
        fixture.replace("rooms =", "ignored =", 1),
        fixture.replace("Dictionary[String, Resource]", "Dictionary[String, PackedScene]", 1),
        fixture + '\nrooms = Dictionary[String, Resource]({})\n',
        fixture.replace('ExtResource("room")', 'ExtResource("missing")'),
        fixture.replace('"fixture_room": ExtResource("room")', '"fixture_room": null'),
        fixture.replace('"fixture_room": ExtResource("room")', '"fixture_room": ExtResource("room"), "fixture_room": ExtResource("room")'),
    ]
    for fixture in bad_libraries:
        try:
            template_ids_from_resource(fixture, "bad library fixture")
        except ValueError:
            count += 1
            continue
        raise AssertionError("accepted unsupported template library fixture")
    return count


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    manifest = read_json(DATA / "manifest.json")
    result = validate_run(manifest)
    rejected = self_test(manifest) if args.self_test else 0
    print(f"RUN_CONTENT_OFFLINE: {len(result['nodes'])} nodes, {len(result['edges'])} edges; rejected fixtures={rejected}")
