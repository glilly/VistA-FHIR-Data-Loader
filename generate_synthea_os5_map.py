#!/usr/bin/env python3
"""
Generate OS5 map artifacts for SYN from Synthea-derived SNOMED ValueSets.

By default this script reads `*_sct.json` ValueSets from a sibling
`VistA-FHIR-Server-Codex/codes` directory, preserves the existing assignments in
`maps/SYNOS5.GO`, regenerates any missing OS5 codes using the same base
algorithm as `$$genos5^SYNFUTL`, and resolves collisions deterministically with
salted retries.

Outputs:
- `maps/SYNOS5.GO`
- `docs/SYNOS5.generated.json`
- `src/SYNOS5LD.m`
- `src/SYNOS5DT.m`
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

SNOMED_SYSTEM = "http://snomed.info/sct"
ALPHA_SUFFIXES = "HIJKLMNOPQ"
DEFAULT_SECOND_LINE = ";;0.7;VISTA SYN DATA LOADER;;Mar 18, 2025"
DATA_ROUTINE_PREFIX = "SYNOS5D"
DIRECT_RE = re.compile(
    r'^\^SYN\("2002\.030","sct2os5","direct",(\d+),"([^"]+)",(\d+)\)$'
)


@dataclass
class SnomedConcept:
    code: str
    display: str
    source_sets: set[str]


@dataclass
class MapEntry:
    sct: str
    os5: str
    display: str
    index: int
    source_sets: set[str]
    status: str
    base_os5: str
    attempts: int
    seed: str
    conflict_with_sct: str | None = None


def repo_root() -> Path:
    return Path(__file__).resolve().parent


def default_codes_dir(base: Path) -> Path | None:
    candidates = [
        base.parent / "VistA-FHIR-Server-Codex" / "codes",
        Path.home() / "VistA-FHIR-Server-Codex" / "codes",
        Path.home() / "work" / "vista-stack" / "VistA-FHIR-Server-Codex" / "codes",
    ]
    for candidate in candidates:
        if candidate.is_dir():
            return candidate
    return None


def second_line(base: Path) -> str:
    candidate = base / "src" / "SYNFUTL.m"
    if not candidate.is_file():
        return DEFAULT_SECOND_LINE
    lines = candidate.read_text(encoding="utf-8", errors="replace").splitlines()
    if len(lines) < 2:
        return DEFAULT_SECOND_LINE
    value = lines[1].strip()
    return value or DEFAULT_SECOND_LINE


def parse_args() -> argparse.Namespace:
    base = repo_root()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--codes-dir",
        type=Path,
        default=default_codes_dir(base),
        help="Directory containing *_sct.json ValueSet files.",
    )
    parser.add_argument(
        "--codes-glob",
        default="*_sct.json",
        help="Glob used to select SNOMED ValueSet files.",
    )
    parser.add_argument(
        "--existing-map",
        type=Path,
        default=base / "maps" / "SYNOS5.GO",
        help="Existing SYNOS5.GO file to preserve mappings from.",
    )
    parser.add_argument(
        "--go-output",
        type=Path,
        default=base / "maps" / "SYNOS5.GO",
        help="Output path for the merged GO-style global export.",
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        default=base / "docs" / "SYNOS5.generated.json",
        help="Output path for the JSON audit manifest.",
    )
    parser.add_argument(
        "--loader-output",
        type=Path,
        default=base / "src" / "SYNOS5LD.m",
        help="Output path for the generated OS5 loader routine.",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=base / "src",
        help="Directory that will receive generated OS5 data routines.",
    )
    parser.add_argument(
        "--data-prefix",
        default=DATA_ROUTINE_PREFIX,
        help="Routine name prefix for generated OS5 data chunks.",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=200,
        help="Maximum number of map entries to place in each generated data routine.",
    )
    parser.add_argument(
        "--max-attempts",
        type=int,
        default=500,
        help="Maximum salted retries when resolving OS5 collisions.",
    )
    return parser.parse_args()


def genos5(seed: str) -> str:
    """Match $$genos5^SYNFUTL for a given seed string."""
    shan = hashlib.sha1(seed.encode("utf-8")).hexdigest()
    hex_tail = shan[-6:]
    dec_tail = str(int(hex_tail, 16))
    digits = dec_tail[-5:].rjust(5, "0")
    return digits[:4] + ALPHA_SUFFIXES[int(digits[4])]


def rehash_attempt_for_existing(sct: str, os5: str, max_attempts: int) -> tuple[int, str]:
    if os5 == genos5(sct):
        return 0, sct
    for attempt in range(1, max_attempts):
        seed = f"{sct}:{attempt}"
        if genos5(seed) == os5:
            return attempt, seed
    return 0, sct


def parse_existing_map(path: Path, max_attempts: int) -> dict[str, MapEntry]:
    if not path.is_file():
        raise FileNotFoundError(f"Existing SYNOS5.GO file not found: {path}")

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    entries: dict[str, MapEntry] = {}
    for idx, line in enumerate(lines[:-1]):
        match = DIRECT_RE.match(line.strip())
        if not match:
            continue
        sct, os5, ordinal = match.groups()
        display = lines[idx + 1].rstrip()
        attempts, seed = rehash_attempt_for_existing(sct, os5, max_attempts)
        entries[sct] = MapEntry(
            sct=sct,
            os5=os5,
            display=display,
            index=int(ordinal),
            source_sets=set(),
            status="existing_only_rehash" if attempts else "existing_only",
            base_os5=genos5(sct),
            attempts=attempts,
            seed=seed,
        )
    return entries


def parse_value_set(path: Path) -> dict[str, SnomedConcept]:
    data = json.loads(path.read_text(encoding="utf-8"))
    source_name = path.stem
    out: dict[str, SnomedConcept] = {}

    for include in data.get("compose", {}).get("include", []):
        if include.get("system") != SNOMED_SYSTEM:
            continue
        for concept in include.get("concept", []):
            code = str(concept.get("code", "")).strip()
            if not code:
                continue
            display = str(concept.get("display", "")).strip() or code
            entry = out.get(code)
            if entry is None:
                out[code] = SnomedConcept(code=code, display=display, source_sets={source_name})
            else:
                entry.source_sets.add(source_name)
                if not entry.display and display:
                    entry.display = display
    return out


def load_snomed_concepts(codes_dir: Path, codes_glob: str) -> tuple[dict[str, SnomedConcept], list[str]]:
    concepts: dict[str, SnomedConcept] = {}
    selected_files: list[str] = []

    for path in sorted(codes_dir.glob(codes_glob)):
        selected_files.append(path.name)
        for code, concept in parse_value_set(path).items():
            current = concepts.get(code)
            if current is None:
                concepts[code] = concept
                continue
            current.source_sets.update(concept.source_sets)
            if not current.display and concept.display:
                current.display = concept.display
    return concepts, selected_files


def numeric_key(value: str) -> tuple[int, str]:
    try:
        return int(value), value
    except ValueError:
        return 0, value


def build_entries(
    existing_entries: dict[str, MapEntry],
    concepts: dict[str, SnomedConcept],
    max_attempts: int,
) -> tuple[list[MapEntry], list[MapEntry]]:
    used_codes = {entry.os5: sct for sct, entry in existing_entries.items()}
    merged: dict[str, MapEntry] = {sct: entry for sct, entry in existing_entries.items()}
    next_index = max((entry.index for entry in existing_entries.values()), default=0) + 1
    collision_entries: list[MapEntry] = []

    for sct, concept in concepts.items():
        if sct in merged:
            entry = merged[sct]
            entry.source_sets.update(concept.source_sets)
            if entry.status == "existing_only":
                entry.status = "existing"
            elif entry.status == "existing_only_rehash":
                entry.status = "existing_rehash"
            if not entry.display and concept.display:
                entry.display = concept.display
            continue

        base_os5 = genos5(sct)
        chosen_os5 = None
        chosen_attempt = None
        chosen_seed = None
        conflict_with = None
        for attempt in range(max_attempts):
            seed = sct if attempt == 0 else f"{sct}:{attempt}"
            candidate = genos5(seed)
            owner = used_codes.get(candidate)
            if owner is None:
                chosen_os5 = candidate
                chosen_attempt = attempt
                chosen_seed = seed
                conflict_with = used_codes.get(base_os5) if attempt > 0 else None
                break
        if chosen_os5 is None:
            raise RuntimeError(f"Unable to assign a unique OS5 for SNOMED {sct}")

        entry = MapEntry(
            sct=sct,
            os5=chosen_os5,
            display=concept.display or sct,
            index=next_index,
            source_sets=set(concept.source_sets),
            status="generated_rehash" if chosen_attempt else "generated",
            base_os5=base_os5,
            attempts=chosen_attempt or 0,
            seed=chosen_seed or sct,
            conflict_with_sct=conflict_with,
        )
        next_index += 1
        merged[sct] = entry
        used_codes[chosen_os5] = sct
        if entry.attempts:
            collision_entries.append(entry)

    ordered = [merged[sct] for sct in sorted(merged, key=numeric_key)]
    for entry in ordered:
        if entry.attempts and entry not in collision_entries:
            collision_entries.append(entry)
    return ordered, collision_entries


def safe_desc(text: str) -> str:
    return text.replace("^", " ").strip()


def routine_second_line(value: str) -> str:
    return value if value.startswith(" ") else " " + value


def write_go(path: Path, entries: list[MapEntry]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        "sct2os5 mapping generated from Synthea ValueSets",
        f"Generated {now}",
    ]
    for entry in entries:
        lines.append(
            f'^SYN("2002.030","sct2os5","direct",{entry.sct},"{entry.os5}",{entry.index})'
        )
        lines.append(safe_desc(entry.display))
    for entry in sorted(entries, key=lambda item: (item.os5, numeric_key(item.sct))):
        lines.append(
            f'^SYN("2002.030","sct2os5","inverse","{entry.os5}",{entry.sct},{entry.index})'
        )
        lines.append(safe_desc(entry.display))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_manifest(
    path: Path,
    entries: list[MapEntry],
    collision_entries: list[MapEntry],
    concepts: dict[str, SnomedConcept],
    selected_files: list[str],
    existing_map: Path,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    concept_codes = set(concepts)
    existing_codes = [
        entry
        for entry in entries
        if entry.status in {"existing", "existing_only", "existing_rehash", "existing_only_rehash"}
    ]
    generated_codes = [entry for entry in entries if entry.status in {"generated", "generated_rehash"}]
    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "existingMapPath": str(existing_map),
        "sourceFiles": selected_files,
        "stats": {
            "totalMappings": len(entries),
            "totalSyntheaSctCodes": len(concepts),
            "existingMappingsPreserved": len(existing_codes),
            "existingMappingsInCurrentValueSets": sum(1 for entry in existing_codes if entry.sct in concept_codes),
            "existingMappingsOutsideCurrentValueSets": sum(1 for entry in existing_codes if entry.sct not in concept_codes),
            "newMappingsGenerated": len(generated_codes),
            "collisionResolutions": len(collision_entries),
        },
        "collisionResolutions": [
            {
                "sct": entry.sct,
                "display": entry.display,
                "baseOs5": entry.base_os5,
                "assignedOs5": entry.os5,
                "attempts": entry.attempts,
                "seed": entry.seed,
                "conflictWithSct": entry.conflict_with_sct,
            }
            for entry in collision_entries
        ],
        "entries": [
            {
                "sct": entry.sct,
                "os5": entry.os5,
                "display": entry.display,
                "index": entry.index,
                "status": entry.status,
                "baseOs5": entry.base_os5,
                "attempts": entry.attempts,
                "seed": entry.seed,
                "sourceSets": sorted(entry.source_sets),
            }
            for entry in entries
        ],
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def write_loader_routine(path: Path, routine_line: str, routine_names: list[str]) -> None:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [
        f"SYNOS5LD ; ven/gpl - load generated sct2os5 map into ^SYN ;{today}",
        routine_second_line(routine_line),
        " ;",
        " ; Generated by generate_synthea_os5_map.py",
        " ;",
        " q",
        " ;",
        "LOADOS5 ; load ^SYN mapping table for SCT to OS5",
        " n ROU",
        ' k ^SYN("2002.030","sct2os5")',
    ]
    for routine_name in routine_names:
        lines.append(f' d LOADRTN("{routine_name}")')
    lines.extend(
        [
        " q",
        " ;",
        "LOADRTN(ROU) ; load one generated OS5 data routine",
        ' n IDX,REF,LINE,SCT,OS5,DESC,U s U="^"',
        ' f IDX=1:1 s REF="DATA+"_IDX_"^"_ROU,LINE=$P($T(@REF),";;",2,999) q:LINE="zzzzz"  d',
        ' . s SCT=$P(LINE,U,1),OS5=$P(LINE,U,2),DESC=$P(LINE,U,3,999)',
        ' . q:SCT=""',
        ' . q:OS5=""',
        ' . s ^SYN("2002.030","sct2os5","direct",SCT,OS5)=DESC',
        ' . s ^SYN("2002.030","sct2os5","inverse",OS5,SCT)=DESC',
        " q",
        " ;",
        "COUNT() ; extrinsic returns the number of direct mappings",
        ' n SCT,OS5,CNT s CNT=0,SCT=""',
        ' f  s SCT=$O(^SYN("2002.030","sct2os5","direct",SCT)) q:SCT=""  d',
        ' . s OS5=""',
        ' . f  s OS5=$O(^SYN("2002.030","sct2os5","direct",SCT,OS5)) q:OS5=""  s CNT=CNT+1',
        " q CNT",
        " ;",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def chunk_entries(entries: list[MapEntry], chunk_size: int) -> list[list[MapEntry]]:
    return [entries[idx:idx + chunk_size] for idx in range(0, len(entries), chunk_size)]


def write_data_routine(path: Path, routine_name: str, entries: list[MapEntry], routine_line: str) -> None:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [
        f"{routine_name} ; ven/gpl - generated sct2os5 data ;{today}",
        routine_second_line(routine_line),
        " ;",
        " ; Generated by generate_synthea_os5_map.py",
        " ;",
        " q",
        " ;",
        "DATA ; sct^os5^description",
    ]
    for entry in entries:
        lines.append(f" ;;{entry.sct}^{entry.os5}^{safe_desc(entry.display)}")
    lines.extend(
        [
            " ;;zzzzz",
            " ;",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_data_routines(
    output_dir: Path,
    prefix: str,
    entries: list[MapEntry],
    routine_line: str,
    chunk_size: int,
) -> list[str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    existing = list(output_dir.glob(f"{prefix}[0-9].m"))
    if (output_dir / "SYNOS5DT.m").exists():
        (output_dir / "SYNOS5DT.m").unlink()
    for stale in existing:
        stale.unlink()

    routine_names: list[str] = []
    for idx, chunk in enumerate(chunk_entries(entries, chunk_size), start=1):
        routine_name = f"{prefix}{idx}"
        routine_names.append(routine_name)
        write_data_routine(output_dir / f"{routine_name}.m", routine_name, chunk, routine_line)
    return routine_names


def main() -> int:
    args = parse_args()
    base = repo_root()
    if args.codes_dir is None or not args.codes_dir.is_dir():
        raise SystemExit(
            "Unable to locate Synthea SNOMED ValueSets automatically. Pass --codes-dir explicitly."
        )
    if not args.existing_map.is_file():
        raise SystemExit(f"Existing SYNOS5.GO file not found: {args.existing_map}")

    concepts, selected_files = load_snomed_concepts(args.codes_dir, args.codes_glob)
    if not selected_files:
        raise SystemExit(f"No files matched {args.codes_glob!r} in {args.codes_dir}")

    existing_entries = parse_existing_map(args.existing_map, args.max_attempts)
    entries, collision_entries = build_entries(existing_entries, concepts, args.max_attempts)
    routine_line = second_line(base)

    write_go(args.go_output, entries)
    write_manifest(
        args.json_output,
        entries,
        collision_entries,
        concepts,
        selected_files,
        args.existing_map,
    )
    routine_names = write_data_routines(
        args.data_dir,
        args.data_prefix,
        entries,
        routine_line,
        args.chunk_size,
    )
    write_loader_routine(args.loader_output, routine_line, routine_names)

    print(
        f"Wrote {args.go_output} ({len(entries)} mappings; "
        f"{len(collision_entries)} collision resolutions)"
    )
    print(f"Wrote {args.json_output}")
    print(f"Wrote {args.loader_output}")
    print(f"Wrote {len(routine_names)} generated data routines in {args.data_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
