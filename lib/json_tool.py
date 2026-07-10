#!/usr/bin/env python3
"""JSON utilities for claude-mode. Standard library only."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
from copy import deepcopy
from pathlib import Path
from typing import Any

MISSING = object()


def read_json(path: str | Path, default: Any = MISSING) -> Any:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        if default is MISSING:
            raise
        return deepcopy(default)


def atomic_write(path: str | Path, value: Any) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    except BaseException:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def candidate_objects(root: Any) -> list[dict[str, Any]]:
    if isinstance(root, list):
        return [x for x in root if isinstance(x, dict)]
    if isinstance(root, dict):
        for key in ("plugins", "installedPlugins", "items", "results"):
            value = root.get(key)
            if isinstance(value, list):
                return [x for x in value if isinstance(x, dict)]
        objects: list[dict[str, Any]] = []
        for value in root.values():
            if isinstance(value, dict):
                objects.append(value)
            elif isinstance(value, list):
                objects.extend(x for x in value if isinstance(x, dict))
        return objects
    return []


def first_text(obj: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = obj.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def normalize_plugin(obj: dict[str, Any]) -> dict[str, Any] | None:
    plugin_id = first_text(obj, "id", "pluginId", "plugin", "fullName")
    name = first_text(obj, "name", "pluginName")
    marketplace_value = obj.get("marketplace", obj.get("source", ""))
    if isinstance(marketplace_value, dict):
        marketplace = first_text(marketplace_value, "name", "id", "marketplace")
    else:
        marketplace = marketplace_value if isinstance(marketplace_value, str) else ""

    combined = " ".join((plugin_id, name, marketplace)).lower()
    if "superpowers" not in combined:
        return None

    if not plugin_id:
        plugin_id = name
        if marketplace and "@" not in plugin_id:
            plugin_id = f"{plugin_id}@{marketplace}"
    if not name:
        name = plugin_id.split("@", 1)[0]

    scopes: list[str] = []
    raw_scopes = obj.get("scopes")
    if isinstance(raw_scopes, list):
        scopes.extend(str(x) for x in raw_scopes)
    elif isinstance(raw_scopes, dict):
        scopes.extend(str(k) for k, v in raw_scopes.items() if v)
    raw_scope = obj.get("scope")
    if isinstance(raw_scope, str) and raw_scope:
        scopes.append(raw_scope)
    scopes = list(dict.fromkeys(scopes))

    enabled_value = obj.get("enabled")
    if isinstance(enabled_value, bool):
        enabled = enabled_value
    else:
        status = first_text(obj, "status", "state").lower()
        enabled = status in {"enabled", "active", "true"}

    return {
        "id": plugin_id,
        "name": name,
        "marketplace": marketplace,
        "scopes": scopes,
        "scope": scopes[0] if scopes else "",
        "enabled": enabled,
        "version": first_text(obj, "version", "installedVersion"),
    }


def command_plugin_matches(_: argparse.Namespace) -> int:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"invalid Claude plugin JSON: {exc}", file=sys.stderr)
        return 2
    found: list[dict[str, Any]] = []
    seen: set[tuple[str, tuple[str, ...]]] = set()
    for obj in candidate_objects(data):
        normalized = normalize_plugin(obj)
        if normalized is None:
            continue
        key = (normalized["id"], tuple(normalized["scopes"]))
        if key not in seen:
            seen.add(key)
            found.append(normalized)
    json.dump(found, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def parse_path(path: str) -> list[str]:
    return [part for part in path.split(".") if part]


def get_path(data: Any, path: str, default: Any = MISSING) -> Any:
    current = data
    for part in parse_path(path):
        try:
            current = current[int(part)] if isinstance(current, list) else current[part]
        except (KeyError, IndexError, ValueError, TypeError):
            if default is MISSING:
                raise
            return default
    return current


def set_path(data: dict[str, Any], path: str, value: Any) -> None:
    parts = parse_path(path)
    if not parts:
        raise ValueError("empty state path")
    current: dict[str, Any] = data
    for part in parts[:-1]:
        child = current.get(part)
        if not isinstance(child, dict):
            child = {}
            current[part] = child
        current = child
    current[parts[-1]] = value


def command_state_get(args: argparse.Namespace) -> int:
    data = read_json(args.file, {})
    default = json.loads(args.default) if args.default is not None else MISSING
    try:
        value = get_path(data, args.path, default)
    except (KeyError, IndexError, ValueError, TypeError):
        return 1
    if isinstance(value, (dict, list, bool)) or value is None:
        print(json.dumps(value, sort_keys=True))
    else:
        print(value)
    return 0


def command_state_set(args: argparse.Namespace) -> int:
    data = read_json(args.file, {})
    if not isinstance(data, dict):
        raise ValueError("state root must be a JSON object")
    for assignment in args.assignment:
        if "=" not in assignment:
            raise ValueError(f"invalid assignment: {assignment}")
        path, raw = assignment.split("=", 1)
        set_path(data, path, json.loads(raw))
    atomic_write(args.file, data)
    return 0


def command_state_create(args: argparse.Namespace) -> int:
    if Path(args.file).exists() and not args.force:
        return 0
    data = {
        "schema": 1,
        "tool_version": args.tool_version,
        "project": args.project,
        "installed": False,
        "expected_mode": "none",
        "plugin": {},
        "nori": {},
        "settings": {},
    }
    atomic_write(args.file, data)
    return 0


def list_merge(base: list[Any], post: list[Any], current: list[Any]) -> list[Any]:
    base_keys = [canonical(x) for x in base]
    post_keys = [canonical(x) for x in post]
    added_by_tool = {key for key in post_keys if key not in base_keys}
    result = [x for x in current if canonical(x) not in added_by_tool]
    result_keys = {canonical(x) for x in result}
    for item in base:
        key = canonical(item)
        if key not in post_keys and key not in result_keys:
            result.append(item)
            result_keys.add(key)
    return result


def three_way(base: Any, post: Any, current: Any, path: str, conflicts: list[str]) -> Any:
    if current == post:
        return deepcopy(base)
    if post == base:
        return deepcopy(current)
    if isinstance(base, dict) and isinstance(post, dict) and isinstance(current, dict):
        result: dict[str, Any] = {}
        keys = set(base) | set(post) | set(current)
        for key in keys:
            a = base.get(key, MISSING)
            b = post.get(key, MISSING)
            c = current.get(key, MISSING)
            child_path = f"{path}.{key}" if path else key
            if c is MISSING and b is MISSING:
                if a is not MISSING:
                    result[key] = deepcopy(a)
                continue
            if c is MISSING:
                if b == a:
                    continue
                conflicts.append(child_path)
                continue
            if b is MISSING:
                result[key] = deepcopy(c)
                continue
            if a is MISSING:
                if c == b:
                    continue
                if isinstance(b, dict) and isinstance(c, dict):
                    merged = three_way({}, b, c, child_path, conflicts)
                    if merged not in ({}, None):
                        result[key] = merged
                elif isinstance(b, list) and isinstance(c, list):
                    merged_list = list_merge([], b, c)
                    if merged_list:
                        result[key] = merged_list
                else:
                    conflicts.append(child_path)
                    result[key] = deepcopy(c)
                continue
            result[key] = three_way(a, b, c, child_path, conflicts)
        return result
    if isinstance(base, list) and isinstance(post, list) and isinstance(current, list):
        return list_merge(base, post, current)
    conflicts.append(path or "$")
    return deepcopy(current)


def command_settings_merge(args: argparse.Namespace) -> int:
    base = read_json(args.base, {})
    post = read_json(args.post, {})
    current = read_json(args.current, {})
    conflicts: list[str] = []
    merged = three_way(base, post, current, "", conflicts)
    atomic_write(args.output, merged)
    if args.conflicts:
        atomic_write(args.conflicts, {"conflicts": sorted(set(conflicts))})
    return 0


def command_hash(args: argparse.Namespace) -> int:
    digest = hashlib.sha256()
    with open(args.file, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    print(digest.hexdigest())
    return 0


def command_validate_neutral(args: argparse.Namespace) -> int:
    root = Path(args.directory)
    manifest = root / "nori.json"
    try:
        data = read_json(manifest)
    except (FileNotFoundError, json.JSONDecodeError):
        return 1
    expected = {"name": args.name, "version": "1.0.0", "type": "skillset", "description": "Empty compatibility skillset managed by claude-mode"}
    if data != expected:
        return 1
    allowed = {"nori.json"}
    actual = {p.name for p in root.iterdir()}
    return 0 if actual == allowed else 1


def command_emit_status(args: argparse.Namespace) -> int:
    plugin = json.loads(args.plugin)
    issues = json.loads(args.issues)
    data = {
        "schema": 1,
        "project": args.project,
        "installed": args.installed == "true",
        "mode": args.mode,
        "expected_mode": None if args.expected == "null" else args.expected,
        "nori": {
            "available": args.nori_available == "true",
            "active_skillset": None if args.marker == "null" else args.marker,
        },
        "plugin": plugin,
        "issues": issues,
        "restart_required": args.mode in {"senior", "superpowers"},
    }
    json.dump(data, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(dest="command", required=True)

    p = subs.add_parser("plugin-matches")
    p.set_defaults(func=command_plugin_matches)

    p = subs.add_parser("state-create")
    p.add_argument("file")
    p.add_argument("--project", required=True)
    p.add_argument("--tool-version", required=True)
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=command_state_create)

    p = subs.add_parser("state-get")
    p.add_argument("file")
    p.add_argument("path")
    p.add_argument("--default")
    p.set_defaults(func=command_state_get)

    p = subs.add_parser("state-set")
    p.add_argument("file")
    p.add_argument("assignment", nargs="+")
    p.set_defaults(func=command_state_set)

    p = subs.add_parser("settings-merge")
    p.add_argument("base")
    p.add_argument("post")
    p.add_argument("current")
    p.add_argument("output")
    p.add_argument("--conflicts")
    p.set_defaults(func=command_settings_merge)

    p = subs.add_parser("hash")
    p.add_argument("file")
    p.set_defaults(func=command_hash)

    p = subs.add_parser("validate-neutral")
    p.add_argument("directory")
    p.add_argument("--name", required=True)
    p.set_defaults(func=command_validate_neutral)

    p = subs.add_parser("emit-status")
    p.add_argument("--project", required=True)
    p.add_argument("--installed", required=True)
    p.add_argument("--mode", required=True)
    p.add_argument("--expected", required=True)
    p.add_argument("--nori-available", required=True)
    p.add_argument("--marker", required=True)
    p.add_argument("--plugin", required=True)
    p.add_argument("--issues", required=True)
    p.set_defaults(func=command_emit_status)

    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        return int(args.func(args))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"json_tool {args.command}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
