#!/usr/bin/env python3
"""Repeatable, non-destructive asset pipeline for Galax Hero.

The source library is always treated as read-only. Generated previews, manifests,
and approved runtime copies are written under the Godot project.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    from PIL import Image
except ImportError:  # pragma: no cover - surfaced by the doctor command
    Image = None


TOOL_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TOOL_DIR.parents[1]
WORKSPACE_ROOT = PROJECT_ROOT.parent
DEFAULT_SOURCE = WORKSPACE_ROOT / "assets"
DEFAULT_OUTPUT = PROJECT_ROOT / "tools" / "asset_catalog" / "generated"
DEFAULT_RUNTIME = PROJECT_ROOT / "assets_runtime"
CONFIG_PATH = TOOL_DIR / "catalog_config.json"
OWNER_APPROVAL_PATH = TOOL_DIR / "owner_approval.json"
SCHEMA_VERSION = 1
SOURCE_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".eps", ".psd",
    ".ase", ".aseprite", ".scml", ".ai", ".wav", ".ogg", ".mp3", ".flac", ".mid",
}
SOURCE_ONLY_EXTENSIONS = {".psd", ".eps", ".scml", ".ai", ".ase", ".aseprite", ".flp"}
RASTER_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac", ".mid"}
TRIAGE_STATUSES = {"approved", "candidate", "duplicate", "source_only", "rejected_style", "rejected_quality", "license_hold"}


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def slug(value: str) -> str:
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_") or "asset"


def relative_posix(path: Path, parent: Path) -> str:
    return path.relative_to(parent).as_posix()


def infer_category(path: Path) -> str:
    text = path.as_posix().lower()
    suffix = path.suffix.lower()
    if suffix in AUDIO_EXTENSIONS:
        return "audio"
    rules = [
        ("background", ("background", "bkgd", "nebula", "planet")),
        ("projectile", ("projectile", "bullet", "missile", "laser")),
        ("effect", ("effect", "explosion", "fragment", "thruster")),
        ("ui", ("/ui/", "panel", "button", "healthbar", "icon")),
        ("pickup", ("powerup", "power up", "pickup", "credit", "container")),
        ("portrait", ("portrait",)),
        ("ship", ("ship", "fighter", "ufo", "boss")),
    ]
    for category, words in rules:
        if any(word in text for word in words):
            return category
    return "uncategorized"


def infer_role(path: Path, category: str) -> str:
    text = path.as_posix().lower()
    if "boss" in text:
        return "boss"
    if "player" in text or "p1_" in text or "p1 " in text:
        return "player"
    if "enemy" in text or "pirate" in text:
        return "enemy"
    return category


def infer_faction(path: Path) -> str:
    text = path.as_posix().lower()
    for faction in ("pirate", "alien", "human", "machine"):
        if faction in text:
            return faction
    return "neutral"


def infer_scale_class(path: Path, dimensions: list[int]) -> str:
    text = path.as_posix().lower()
    if "boss" in text:
        return "boss"
    if "projectile" in text or "bullet" in text or "laser" in text:
        return "projectile"
    if "powerup" in text or "pickup" in text or "credit" in text:
        return "pickup"
    longest = max(dimensions) if dimensions else 0
    if longest >= 512:
        return "background"
    if longest >= 192:
        return "miniboss"
    if longest >= 96:
        return "elite"
    return "standard_fighter"


def image_info(path: Path) -> tuple[list[int], int]:
    if Image is None or path.suffix.lower() not in RASTER_EXTENSIONS:
        return [], 0
    try:
        with Image.open(path) as image:
            return [int(image.width), int(image.height)], int(getattr(image, "n_frames", 1))
    except Exception:
        return [], 0


def nearest_license(path: Path, source_root: Path) -> Path | None:
    current = path.parent
    candidates = ("license.txt", "LICENSE", "LICENSE.txt", "public-license.txt")
    while current == source_root or source_root in current.parents:
        for name in candidates:
            candidate = current / name
            if candidate.is_file():
                return candidate
        if current == source_root:
            break
        current = current.parent
    return None


def classify_license(license_path: Path | None) -> tuple[str, bool, bool]:
    if license_path is None:
        return "missing", False, False
    text = license_path.read_text(encoding="utf-8", errors="ignore").lower()
    if "cc0" in text or "public domain" in text:
        return "approved_cc0", True, "attribution" in text and "not required" not in text
    if "commercial" in text and ("free" in text or "may use" in text):
        return "reviewed_commercial", True, "attribution" in text and "not required" not in text
    return "needs_review", False, False


def load_overrides(config: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {entry["source_path"]: entry for entry in config.get("asset_overrides", [])}


def resolve_source_path(item: dict[str, Any], source_root: Path) -> Path:
    if item.get("source_scope") == "project":
        return PROJECT_ROOT / item["source_path"]
    return source_root / item["source_path"]


def build_manifest(source_root: Path, config: dict[str, Any]) -> dict[str, Any]:
    records: list[dict[str, Any]] = []
    by_hash: dict[str, str] = {}
    used_ids: set[str] = set()
    overrides = load_overrides(config)
    owner_approval = load_json(OWNER_APPROVAL_PATH) if OWNER_APPROVAL_PATH.is_file() else {}
    # The attestation is scoped to this project's actual workspace library. It
    # must never silently legalize an arbitrary source root passed by a caller.
    owner_attests_library = (
        source_root.resolve() == DEFAULT_SOURCE.resolve()
        and owner_approval.get("scope", "").lower().startswith("all assets")
        and "distribution" in owner_approval.get("permission", "").lower()
    )
    files = sorted(
        (path for path in source_root.rglob("*") if path.is_file() and path.suffix.lower() in SOURCE_EXTENSIONS),
        key=lambda path: relative_posix(path, source_root).lower(),
    )
    for path in files:
        relative = relative_posix(path, source_root)
        digest = sha256(path)
        dimensions, embedded_frames = image_info(path)
        category = infer_category(path)
        base_id = "asset.%s.%s" % (category, slug(str(Path(relative).with_suffix(""))))
        stable_id = base_id
        if stable_id in used_ids:
            stable_id = "%s_%s" % (base_id, digest[:8])
        collision_index = 2
        while stable_id in used_ids:
            stable_id = "%s_%s_%d" % (base_id, digest[:8], collision_index)
            collision_index += 1
        used_ids.add(stable_id)
        license_path = nearest_license(path, source_root)
        license_status, commercial_use, attribution = classify_license(license_path)
        if owner_attests_library and license_status in {"missing", "needs_review"}:
            license_status = "owner_attested"
            commercial_use = True
        duplicate_of = by_hash.get(digest, "")
        if not duplicate_of:
            by_hash[digest] = stable_id
        profile = config.get("category_import_profiles", {}).get(category, "pixel_art")
        record: dict[str, Any] = {
            "stable_id": stable_id,
            "original_filename": path.name,
            "normalized_filename": slug(path.stem) + path.suffix.lower(),
            "source_path": relative,
            "source_scope": "library",
            "runtime_path": "",
            "file_type": path.suffix.lower().lstrip("."),
            "dimensions": dimensions,
            "frame_count": embedded_frames,
            "animation_names": [],
            "animation": None,
            "faction": infer_faction(path),
            "category": category,
            "subcategory": "",
            "intended_role": infer_role(path, category),
            "collision_recommendation": "none" if category in {"background", "ui", "audio", "effect", "portrait"} else "tight_ellipse",
            "scale_class": infer_scale_class(path, dimensions),
            "visual_scale": 1.0,
            "collision_scale": 1.0,
            "anchor": [0.5, 0.5],
            "orientation": "up" if category in {"ship", "projectile"} else "not_applicable",
            "screen_layer": "world",
            "pseudo_altitude": "mid",
            "palette_family": "unknown",
            "license_source": relative_posix(license_path, source_root) if license_path else ("tools/asset_catalog/owner_approval.json" if owner_attests_library else ""),
            "license_status": license_status,
            "commercial_use": commercial_use,
            "attribution_required": attribution,
            "import_status": "source_only",
            "validation_status": "valid" if license_status != "missing" else "blocked_missing_license",
            "import_profile": profile,
            "content_definition_links": [],
            "duplicate_of": duplicate_of,
            "sha256": digest,
            "notes": "",
        }
        override = overrides.get(relative)
        if override:
            record.update({key: value for key, value in override.items() if key != "source_path"})
        if record["import_status"] == "approved":
            record["triage_status"] = "approved"
        elif record["license_status"] in {"missing", "needs_review"} or not record["commercial_use"]:
            record["triage_status"] = "license_hold"
        elif record["duplicate_of"]:
            record["triage_status"] = "duplicate"
        elif path.suffix.lower() in SOURCE_ONLY_EXTENSIONS:
            record["triage_status"] = "source_only"
        else:
            record["triage_status"] = "candidate"
        records.append(record)
    for project_entry in config.get("project_assets", []):
        relative = Path(project_entry["source_path"]).as_posix()
        path = PROJECT_ROOT / relative
        if not path.is_file():
            raise FileNotFoundError(f"configured project asset does not exist: {path}")
        digest = sha256(path)
        dimensions, embedded_frames = image_info(path)
        category = project_entry.get("category", infer_category(path))
        stable_id = project_entry["stable_id"]
        import_status = project_entry.get("import_status", "approved")
        if stable_id in used_ids:
            raise ValueError(f"duplicate configured project asset ID: {stable_id}")
        used_ids.add(stable_id)
        record = {
            "stable_id": stable_id,
            "original_filename": path.name,
            "normalized_filename": project_entry.get("normalized_filename", slug(path.stem) + path.suffix.lower()),
            "source_path": relative,
            "source_scope": "project",
            "runtime_path": project_entry.get("runtime_path", ""),
            "file_type": path.suffix.lower().lstrip("."),
            "dimensions": dimensions,
            "frame_count": embedded_frames,
            "animation_names": [],
            "animation": None,
            "faction": project_entry.get("faction", "neutral"),
            "category": category,
            "subcategory": project_entry.get("subcategory", ""),
            "intended_role": project_entry.get("intended_role", category),
            "collision_recommendation": "none",
            "scale_class": project_entry.get("scale_class", "ui"),
            "visual_scale": 1.0,
            "collision_scale": 1.0,
            "anchor": [0.5, 0.5],
            "orientation": "not_applicable",
            "screen_layer": project_entry.get("screen_layer", "ui"),
            "pseudo_altitude": "not_applicable",
            "palette_family": project_entry.get("palette_family", "cool_blue_gold"),
            "license_source": project_entry["license_source"],
            "license_status": project_entry.get("license_status", "owner_created"),
            "commercial_use": True,
            "attribution_required": False,
            "import_status": import_status,
            "validation_status": "valid",
            "import_profile": project_entry.get("import_profile", "ui"),
            "content_definition_links": project_entry.get("content_definition_links", []),
            "duplicate_of": "",
            "sha256": digest,
            "notes": project_entry.get("notes", ""),
            "triage_status": "approved" if import_status == "approved" else project_entry.get("triage_status", "candidate"),
        }
        records.append(record)
    return {
        "schema_version": SCHEMA_VERSION,
        "source_root": str(source_root.resolve()),
        "asset_count": len(records),
        "assets": records,
    }


def write_thumbnails(manifest: dict[str, Any], source_root: Path, output: Path) -> int:
    if Image is None:
        return 0
    thumb_dir = output / "thumbnails"
    thumb_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for record in manifest["assets"]:
        source = resolve_source_path(record, source_root)
        if source.suffix.lower() not in RASTER_EXTENSIONS:
            continue
        destination = thumb_dir / (slug(record["stable_id"]) + ".png")
        try:
            with Image.open(source) as image:
                image.seek(0)
                converted = image.convert("RGBA")
                converted.thumbnail((160, 160))
                converted.save(destination, "PNG", optimize=True)
                record["thumbnail_path"] = relative_posix(destination, output)
                count += 1
        except Exception:
            record["thumbnail_path"] = ""
    return count


def atlas_candidates(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, int, int, str], list[str]] = {}
    for item in manifest["assets"]:
        if item["file_type"] != "png" or item["duplicate_of"] or not item["dimensions"]:
            continue
        width, height = item["dimensions"]
        if width > 512 or height > 512:
            continue
        key = (item["category"], width, height, item["import_profile"])
        groups.setdefault(key, []).append(item["stable_id"])
    result = []
    for (category, width, height, profile), ids in groups.items():
        if len(ids) >= 4:
            result.append({"category": category, "cell_size": [width, height], "import_profile": profile, "asset_ids": ids})
    return result


def write_catalog_html(manifest: dict[str, Any], output: Path) -> None:
    rows = []
    for item in manifest["assets"]:
        thumb = item.get("thumbnail_path", "")
        image = f'<img loading="lazy" src="{html.escape(thumb)}" alt="">' if thumb else ""
        search = " ".join(str(item.get(key, "")) for key in ("stable_id", "source_path", "faction", "category", "intended_role", "scale_class", "license_status", "import_status"))
        rows.append(
            '<tr data-search="%s"><td>%s</td><td><code>%s</code><br>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'
            % (
                html.escape(search), image, html.escape(item["stable_id"]), html.escape(item["source_path"]),
                html.escape(item["faction"]), html.escape(item["intended_role"]),
                html.escape(item["scale_class"]), html.escape(item["license_status"]),
            )
        )
    page = f"""<!doctype html><meta charset=utf-8><title>Galax Hero Asset Catalog</title>
<style>body{{font:14px system-ui;margin:24px;background:#0d1525;color:#e7eefc}}input{{width:100%;padding:12px;margin:0 0 16px;background:#18243a;color:white;border:1px solid #52698f}}table{{border-collapse:collapse;width:100%}}th,td{{padding:8px;border-bottom:1px solid #263955;text-align:left}}img{{width:80px;height:80px;object-fit:contain;image-rendering:pixelated}}code{{color:#8dd5ff}}</style>
<h1>Galax Hero Asset Catalog</h1><p>{manifest['asset_count']} source assets. Search by ID, path, faction, role, scale, license, or import status.</p>
<input id=q autofocus placeholder="Search assets…"><table><thead><tr><th>Preview</th><th>Asset</th><th>Faction</th><th>Role</th><th>Scale</th><th>License</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
<script>q.oninput=()=>{{let x=q.value.toLowerCase();document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.dataset.search.toLowerCase().includes(x))}}</script>"""
    (output / "catalog.html").write_text(page, encoding="utf-8")


def write_runtime_reports(manifest: dict[str, Any], output: Path) -> None:
    approved = [item for item in manifest["assets"] if item.get("import_status") == "approved"]
    triage_counts: dict[str, int] = {}
    license_groups: dict[str, dict[str, Any]] = {}
    for item in manifest["assets"]:
        status = item.get("triage_status", "")
        triage_counts[status] = triage_counts.get(status, 0) + 1
    for item in approved:
        key = "%s | %s" % (item.get("license_status", ""), item.get("license_source", ""))
        group = license_groups.setdefault(key, {"license_status": item.get("license_status", ""), "license_source": item.get("license_source", ""), "asset_ids": []})
        group["asset_ids"].append(item["stable_id"])
    report = {
        "schema_version": 1,
        "asset_count": len(manifest["assets"]),
        "triage_counts": dict(sorted(triage_counts.items())),
        "approved_count": len(approved),
        "approved_runtime_bytes": sum((PROJECT_ROOT / item["runtime_path"].removeprefix("res://")).stat().st_size for item in approved if (PROJECT_ROOT / item["runtime_path"].removeprefix("res://")).is_file()),
        "license_groups": list(license_groups.values()),
        "approved_assets": [{key: item.get(key) for key in ("stable_id", "source_path", "runtime_path", "sha256", "license_status", "license_source", "attribution_required", "content_definition_links")} for item in approved],
    }
    write_json(output / "runtime_asset_report.json", report)
    lines = ["# Runtime Asset Credits Report", "", "Generated from the approved asset manifest. Exact hashes and paths remain authoritative in `manifest.json`.", ""]
    for group in report["license_groups"]:
        lines.extend(["## %s" % group["license_status"], "", "License evidence: `%s`" % group["license_source"], "", *["- `%s`" % stable_id for stable_id in group["asset_ids"]], ""])
    (output / "runtime_asset_credits.md").write_text("\n".join(lines), encoding="utf-8")


def inventory(args: argparse.Namespace) -> int:
    config = load_json(CONFIG_PATH)
    source = Path(args.source).resolve()
    output = Path(args.output).resolve()
    if not source.is_dir():
        print(f"ERROR: source directory does not exist: {source}", file=sys.stderr)
        return 2
    output.mkdir(parents=True, exist_ok=True)
    manifest = build_manifest(source, config)
    thumbnail_count = 0 if args.no_thumbnails else write_thumbnails(manifest, source, output)
    write_json(output / "manifest.json", manifest)
    write_json(output / "atlas_candidates.json", {"schema_version": 1, "groups": atlas_candidates(manifest)})
    write_catalog_html(manifest, output)
    write_runtime_reports(manifest, output)
    print(f"Inventoried {manifest['asset_count']} assets; generated {thumbnail_count} thumbnails in {output}")
    return 0


def safe_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if sha256(source) == sha256(destination):
            return
        raise FileExistsError(f"refusing to overwrite different file: {destination}")
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    shutil.copy2(source, temporary)
    temporary.replace(destination)


def approve(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest).resolve()
    manifest = load_json(manifest_path)
    source_root = Path(manifest["source_root"])
    runtime_root = Path(args.runtime).resolve()
    approved = 0
    errors: list[str] = []
    for item in manifest["assets"]:
        if item.get("import_status") != "approved":
            continue
        if not item.get("commercial_use") or item.get("license_status") in {"missing", "needs_review"}:
            errors.append(f"{item['stable_id']}: approval blocked by license status {item['license_status']}")
            continue
        destination_value = item.get("runtime_path", "")
        if not destination_value.startswith("res://assets_runtime/"):
            errors.append(f"{item['stable_id']}: runtime_path must be under res://assets_runtime")
            continue
        relative_destination = destination_value.removeprefix("res://assets_runtime/")
        try:
            safe_copy(resolve_source_path(item, source_root), runtime_root / relative_destination)
            approved += 1
        except (OSError, FileExistsError) as error:
            errors.append(f"{item['stable_id']}: {error}")
    if errors:
        print("\n".join("ERROR: " + error for error in errors), file=sys.stderr)
        return 1
    print(f"Approved runtime set is current: {approved} assets in {runtime_root}")
    return 0


def find_converter(extension: str) -> list[str] | None:
    if extension == ".eps":
        for executable, command in (("magick", ["magick"]), ("inkscape", ["inkscape"])):
            if shutil.which(executable):
                return command
    return None


def convert_asset(args: argparse.Namespace) -> int:
    source = Path(args.input).resolve()
    output_dir = Path(args.output).resolve()
    if not source.is_file():
        print(f"ERROR: input does not exist: {source}", file=sys.stderr)
        return 2
    output_dir.mkdir(parents=True, exist_ok=True)
    suffix = source.suffix.lower()
    destination = output_dir / (slug(source.stem) + ".png")
    if destination.exists() and not args.force:
        print(f"ERROR: refusing to overwrite {destination}; pass --force for generated outputs", file=sys.stderr)
        return 1
    try:
        if suffix == ".psd":
            if args.layers:
                try:
                    from psd_tools import PSDImage
                except ImportError:
                    print("ERROR: selected PSD layers require optional package psd-tools", file=sys.stderr)
                    return 3
                psd = PSDImage.open(source)
                selected = [layer for layer in psd if layer.name in args.layers]
                if not selected:
                    print("ERROR: none of the requested PSD layers were found", file=sys.stderr)
                    return 1
                selected[0].composite().save(destination)
            elif Image is not None:
                with Image.open(source) as image:
                    image.convert("RGBA").save(destination)
            else:
                print("ERROR: Pillow is required for PSD composites", file=sys.stderr)
                return 3
        elif suffix == ".eps":
            converter = find_converter(suffix)
            if converter is None:
                print("ERROR: EPS conversion requires ImageMagick or Inkscape", file=sys.stderr)
                return 3
            if converter[0] == "inkscape":
                command = converter + [str(source), "--export-filename", str(destination)]
            else:
                command = converter + [str(source) + "[0]", str(destination)]
            subprocess.run(command, check=True)
        elif suffix == ".scml":
            root = ET.parse(source).getroot()
            referenced = []
            for file_node in root.findall("./folder/file"):
                filename = file_node.attrib.get("name", "")
                referenced_source = source.parent / filename
                if referenced_source.is_file():
                    target = output_dir / slug(source.stem) / Path(filename).name
                    safe_copy(referenced_source, target)
                    referenced.append(relative_posix(target, output_dir))
            metadata = {
                "source": str(source),
                "animations": [node.attrib.get("name", "") for node in root.findall("./entity/animation")],
                "referenced_frames": referenced,
            }
            write_json(output_dir / (slug(source.stem) + "_animation.json"), metadata)
            print(f"Imported {len(referenced)} SCML-referenced frames and animation metadata")
            return 0
        else:
            print("ERROR: conversion supports .eps, .psd, and .scml", file=sys.stderr)
            return 2
    except (OSError, subprocess.CalledProcessError, ET.ParseError) as error:
        print(f"ERROR: conversion failed: {error}", file=sys.stderr)
        return 1
    print(f"Converted {source.name} -> {destination}")
    return 0


def convert_batch(args: argparse.Namespace) -> int:
    source_root = Path(args.source).resolve()
    output_root = Path(args.output).resolve()
    formats = {"." + value.lower().lstrip(".") for value in args.formats}
    if not source_root.is_dir():
        print(f"ERROR: source directory does not exist: {source_root}", file=sys.stderr)
        return 2
    candidates = sorted(path for path in source_root.rglob("*") if path.is_file() and path.suffix.lower() in formats)
    failures = 0
    for source in candidates:
        relative_parent = source.parent.relative_to(source_root)
        destination_dir = output_root.joinpath(*(slug(part) for part in relative_parent.parts))
        result = convert_asset(argparse.Namespace(input=str(source), output=str(destination_dir), layers=None, force=args.force))
        if result != 0:
            failures += 1
            if args.fail_fast:
                break
    print(f"Batch conversion processed {len(candidates)} source file(s); {failures} failed")
    return 1 if failures else 0


def validate(args: argparse.Namespace) -> int:
    manifest = load_json(Path(args.manifest).resolve())
    errors: list[str] = []
    warnings: list[str] = []
    ids: set[str] = set()
    runtime_names: set[str] = set()
    source_root = Path(manifest["source_root"])
    content_ids: set[str] = set()
    for path in (PROJECT_ROOT / "production" / "content").rglob("*.tres"):
        content_ids.update(re.findall(r'stable_id\s*=\s*&"([^"]+)"', path.read_text(encoding="utf-8", errors="ignore")))
    for item in manifest["assets"]:
        stable_id = item.get("stable_id", "")
        if not stable_id or stable_id in ids:
            errors.append(f"invalid or duplicate stable ID: {stable_id}")
        ids.add(stable_id)
        if item.get("triage_status") not in TRIAGE_STATUSES:
            errors.append(f"asset has invalid or missing triage status: {stable_id}")
        source_file = resolve_source_path(item, source_root)
        source_required = bool(getattr(args, "require_source", False)) or item.get("source_scope") == "project"
        if source_required and not source_file.is_file():
            errors.append(f"missing source file: {item['source_path']}")
        if item.get("license_status") == "missing":
            warnings.append(f"missing license: {item['source_path']}")
        if item.get("import_status") == "approved":
            if not item.get("commercial_use") or item.get("license_status") in {"missing", "needs_review"}:
                errors.append(f"approved asset has unverified license: {stable_id}")
            runtime_path = item.get("runtime_path", "")
            if not runtime_path.startswith("res://assets_runtime/"):
                errors.append(f"approved asset has invalid runtime path: {stable_id}")
            elif not (PROJECT_ROOT / runtime_path.removeprefix("res://")).is_file():
                errors.append(f"approved runtime file is missing: {runtime_path}")
            else:
                runtime_file = PROJECT_ROOT / runtime_path.removeprefix("res://")
                if runtime_file.name.lower() in runtime_names: errors.append(f"duplicate approved runtime filename: {runtime_file.name}")
                runtime_names.add(runtime_file.name.lower())
                if sha256(runtime_file) != item.get("sha256"):
                    errors.append(f"approved runtime hash mismatch: {stable_id}")
                if source_file.is_file() and sha256(source_file) != item.get("sha256"):
                    errors.append(f"approved source hash mismatch: {stable_id}")
                if item.get("file_type") in {"png", "jpg", "jpeg", "gif", "webp"} and item.get("dimensions") and max(item["dimensions"]) > 4096:
                    errors.append(f"approved texture exceeds 4096px limit: {stable_id}")
                if item.get("file_type") in {"wav", "ogg", "mp3", "flac"} and runtime_file.stat().st_size > 25 * 1024 * 1024:
                    errors.append(f"approved audio exceeds 25 MiB limit: {stable_id}")
                import_sidecar = Path(str(runtime_file) + ".import")
                if item.get("file_type") in {"png", "jpg", "jpeg", "gif", "webp", "wav", "ogg", "mp3"} and not import_sidecar.is_file():
                    errors.append(f"approved runtime import sidecar is missing: {runtime_path}.import")
            for content_id in item.get("content_definition_links", []):
                if content_id not in content_ids: errors.append(f"approved asset links missing content definition {content_id}: {stable_id}")
    for path in PROJECT_ROOT.rglob("*"):
        if path.is_file() and path.suffix.lower() in SOURCE_ONLY_EXTENSIONS:
            errors.append(f"source-only format inside export project: {relative_posix(path, PROJECT_ROOT)}")
    if warnings and not args.release:
        print(f"WARN: {len(warnings)} source assets have no discoverable license (visible in catalog)")
    if args.release and any(item.get("import_status") == "approved" and item.get("license_status") == "missing" for item in manifest["assets"]):
        errors.append("release validation blocks approved assets with missing license status")
    if errors:
        print("\n".join("ERROR: " + error for error in errors), file=sys.stderr)
        return 1
    print(f"Validated {len(manifest['assets'])} catalog records ({sum(1 for x in manifest['assets'] if x.get('import_status') == 'approved')} approved)")
    return 0


def search(args: argparse.Namespace) -> int:
    manifest = load_json(Path(args.manifest).resolve())
    terms = [term.lower() for term in args.terms]
    matches = []
    for item in manifest["assets"]:
        haystack = json.dumps(item, ensure_ascii=False).lower()
        if all(term in haystack for term in terms):
            matches.append(item)
    for item in matches[: args.limit]:
        print(f"{item['stable_id']}\t{item['faction']}\t{item['intended_role']}\t{item['scale_class']}\t{item['source_path']}")
    print(f"{len(matches)} match(es)")
    return 0


def doctor(_: argparse.Namespace) -> int:
    checks = {
        "Python": sys.version.split()[0],
        "Pillow (inventory, thumbnails, PSD composite)": "available" if Image else "missing",
        "psd-tools (optional selected PSD layers)": "available" if __import__("importlib").util.find_spec("psd_tools") else "missing",
        "ImageMagick/Inkscape (EPS previews)": "available" if find_converter(".eps") else "missing",
        "Aseprite (optional authoring/export)": "available" if shutil.which("aseprite") else "missing",
    }
    for name, status in checks.items():
        print(f"{name}: {status}")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    inventory_parser = commands.add_parser("inventory", help="scan sources and generate catalog outputs")
    inventory_parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    inventory_parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    inventory_parser.add_argument("--no-thumbnails", action="store_true")
    inventory_parser.set_defaults(handler=inventory)
    approve_parser = commands.add_parser("approve", help="copy configured approved assets to runtime folders")
    approve_parser.add_argument("--manifest", default=str(DEFAULT_OUTPUT / "manifest.json"))
    approve_parser.add_argument("--runtime", default=str(DEFAULT_RUNTIME))
    approve_parser.set_defaults(handler=approve)
    convert_parser = commands.add_parser("convert", help="convert one EPS/PSD or import one SCML source")
    convert_parser.add_argument("input")
    convert_parser.add_argument("--output", required=True)
    convert_parser.add_argument("--layers", nargs="*")
    convert_parser.add_argument("--force", action="store_true")
    convert_parser.set_defaults(handler=convert_asset)
    batch_parser = commands.add_parser("convert-batch", help="recursively convert EPS/PSD or import SCML sources")
    batch_parser.add_argument("source")
    batch_parser.add_argument("--output", required=True)
    batch_parser.add_argument("--formats", nargs="+", choices=["eps", "psd", "scml"], default=["eps", "psd", "scml"])
    batch_parser.add_argument("--force", action="store_true")
    batch_parser.add_argument("--fail-fast", action="store_true")
    batch_parser.set_defaults(handler=convert_batch)
    validate_parser = commands.add_parser("validate", help="validate catalog and runtime approvals")
    validate_parser.add_argument("--manifest", default=str(DEFAULT_OUTPUT / "manifest.json"))
    validate_parser.add_argument("--release", action="store_true")
    validate_parser.add_argument("--require-source", action="store_true", help="require the external editable source library to be mounted")
    validate_parser.set_defaults(handler=validate)
    search_parser = commands.add_parser("search", help="search generated catalog fields")
    search_parser.add_argument("terms", nargs="+")
    search_parser.add_argument("--manifest", default=str(DEFAULT_OUTPUT / "manifest.json"))
    search_parser.add_argument("--limit", type=int, default=50)
    search_parser.set_defaults(handler=search)
    doctor_parser = commands.add_parser("doctor", help="report optional converter availability")
    doctor_parser.set_defaults(handler=doctor)
    return root


if __name__ == "__main__":
    arguments = parser().parse_args()
    raise SystemExit(arguments.handler(arguments))
