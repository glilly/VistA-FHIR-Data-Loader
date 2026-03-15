# Future KIDS Packaging

## Purpose

Recent encounter/procedure CPT mapping work changed both runtime loader routines
and generated OS5 map artifacts in this repo. This note explains what future
`VISTA SYN DATA LOADER` KIDS releases need to carry forward so installs keep the
same behavior on fresh target systems.

## What Changed

- `SYNDHP61` now treats `$$MAP^SYNDHPMP` results as `status^code`, guards blank
  `^ICPT("B",...)` lookups, and keeps the `6456Q` fallback when no specific
  mapping exists.
- `SYNQLDM` now creates and resolves the `mapping-errors` graph safely under
  GT.M, avoiding null-subscript failures during fresh loads.
- The SNOMED-to-OS5 map is now rebuilt from generated routines during install.
  `POST^SYNKIDS` calls `EN^SYNGBLLD`, which calls `LOADOS5^SYNOS5LD` and
  `EN^SYNOS5PT`.
- That means the shipped routines, not just a developer's local `^SYN` global,
  now define the install-time truth for `^SYN("2002.030","sct2os5")` and the
  synthetic OS5 entries created in file 81 / Lexicon.

## Packaging Impact

### 1. Regenerate OS5 artifacts before cutting KIDS when mappings change

If a release changes Synthea SNOMED coverage or OS5 assignments, run:

```bash
python3 generate_synthea_os5_map.py
```

That refreshes:

- `maps/SYNOS5.GO`
- `docs/SYNOS5.generated.json`
- `src/SYNOS5LD.m`
- `src/SYNOS5D*.m`

Do not cut a KIDS build with hand-edited or stale OS5 generated routines. The
post-install rebuild uses the shipped routines, so any mapping change that is
not present there will be lost on the target system.

### 2. Include the runtime routines that implement the fixed behavior

Future KIDS releases that want the current happy path should include the updated
loader/install routines:

- `SYNDHP61`
- `SYNQLDM`
- `SYNGBLLD`
- `SYNOS5LD`
- `SYNOS5PT`
- `SYNOS5D*.m`

If additional loader fixes land in other routines, include those too. Routine
changes are part of the transport and are required even if the source system's
globals already look correct.

### 3. Understand what `SYNKIDS` actually installs

`TRAN^SYNKIDS` transports:

- `^SYN`
- synthetic OS5 entries from file 81
- synthetic OS5 entries from the relevant Lexicon files
- `loinc-lab-map`

`POST^SYNKIDS` then:

1. Restores the transported data.
2. Rebuilds the mapping tables via `EN^SYNGBLLD`.
3. Recreates any missing OS5 file 81 / Lexicon entries via `EN^SYNOS5PT`.

Because of step 2, the generated OS5 routines in the KIDS build are the durable
source of truth for `sct2os5`. A source-system global change by itself is not
enough.

### 4. Keep the fallback path

The `6456Q` fallback in `SYNDHP61` should remain in future KIDS builds. New
mappings should reduce fallback usage, but packaging should not remove the
safety behavior for still-unmapped encounter SNOMED codes.

## Example From This Work

The added mapping for SNOMED `410620009` (`Well child visit (procedure)`) now
needs to exist in the shipped generated OS5 data routines so that a fresh KIDS
install recreates the same mapping and the same OS5 CPT/Lexicon seed data.

In the current generated layout that row lives in `SYNOS5D4`, but future chunk
boundaries may move. Release engineers should treat `SYNOS5D*.m` as a set and
ship the whole regenerated family together.

## Release Checklist

- Regenerate OS5 artifacts if Synthea code-set coverage or OS5 assignments
  changed.
- Review diffs for `SYNOS5LD` and every generated `SYNOS5D*.m` routine.
- Build the KIDS distribution from a source VistA where the updated routines are
  already loaded.
- Install the build on a test system and verify:
  - `POST^SYNKIDS` completes.
  - `$$COUNT^SYNOS5LD` returns the expected direct-map count.
  - Fresh patient loads do not hit the old `SYNDHP61` or `SYNQLDM` null-subscript
    failures.
  - Encounter-like SNOMEDs use specific OS5 mappings when available, with
    `6456Q` only as fallback.

## Cross-Repo Note

The richer encounter export and encounter-as-procedure filtering live in
`VistA-FHIR-Server-Codex`; those changes are not delivered by this KIDS build.
If a release needs the fully validated end-to-end behavior, publish the SYN
KIDS update together with the corresponding FHIR server release notes or commit
reference.
