# Development Status and Gap Analysis — VistA-FHIR-Data-Loader (SYN)

Status date: 2026-06-09
Branch at time of writing: `vaready-wd-compat`

Part of the VistA-on-FHIR workspace. Ecosystem-level context lives in
`VistA-FHIR-Server-Codex/docs/PROJECT_OVERVIEW.md`; the cross-repo roadmap is
`VistA-FHIR-Server-Codex/docs/PATH_FORWARD.md`.

## Role of this repository

SYN loads FHIR R4 bundles (primarily Synthea output) into VistA test systems.
It stores raw JSON in a named graph (`fhir-intake`), indexes resources, files
demographics and clinical domains into FileMan, and records per-resource
success/failure for replay. It sits on top of the ISI filing layer
(`VistA-DataLoader`) and below the Codex FHIR server, which registers SYN's
HTTP routes (`/addpatient`, `/updatepatient`, `/replayIntake`, `/vpr`,
`/loadstatus`) via `SYNWEBRG.m`.

Explicitly not for production — test/demo systems only.

## What is working today

- **Intake and orchestration**: `wsPostFHIR^SYNFHIR`, `wsUpdatePatient^SYNFHIRU`,
  `replayIntakeDomains` with selective category replay
  (`docs/../../VistA-FHIR-Server-Codex/docs/SYN_GAP_REPAIR_WORKFLOW.md`).
- **Domain importers**: patients, encounters, conditions, vitals, labs
  (+ panels), immunizations, allergies, appointments, medications
  (`SYNFMED2`), procedures, care plans, TIU notes.
- **Dual graph backend**: `SYNWD.m` routes between `%wd` and `^SYNGRAPH`
  (`docs/GRAPH_STORE_COMPATIBILITY.md`) — the focus of the current
  `vaready-wd-compat` branch.
- **TIU writeback**: `Encounter.note`/`DocumentReference` → `^TIU(8925)` via
  `SYNFTIU`/`SYNDHP61`, with `replayIntake?retryEncounterTiuNotes=1` recovery
  (`docs/TIU_NOTE_WRITEBACK.md`).
- **Terminology maps**: SNOMED→OS5/ICD/CPT in `^SYN("2002.030",...)`;
  `generate_synthea_os5_map.py` regenerates from Codex `codes/`.
- **Audit**: `SYNAUDIT` install/health checks (`docs/SYNAUDIT.md`).

## Gap analysis

### Resource coverage gaps

Indexed but **not filed** into VistA (graph-view only): Claim,
ExplanationOfBenefit, ImagingStudy, Practitioner, Organization, standalone
Medication. DiagnosticReport has no separate importer (labs come from
Observation); Goal is consumed only inside CarePlan.

### Fragile domains

1. **Terminology gaps** drive most load errors: missing LOINC/ICD/SNOMED→OS5
   mappings land in the `mapping-errors` graph (`SYNQLDM`).
2. **Lab infrastructure** sensitivity: accession areas and file `#60` setup
   per container (`docs/LAB_ACCESSION_REMEDIATION_WORKFLOW.md`,
   `docs/vehu-lab-package-config.md`).
3. **TIU inpatient multi-visit semantics** still planned
   (`docs/NOTES_AND_TIU_LOAD_PLANNING.md`).
4. **Graph-update stubs** (TODOs) in `SYNFLAB.m`, `SYNFENC.m`, `SYNFCP.m`,
   `SYNFPAN.m`, `SYNFPROC.m`; `SYNFMED.m` superseded by `SYNFMED2.m` but
   still present.

### Engineering gaps

1. **No automated unit tests.** `test/vaready-test*.txt` are manual
   integration transcripts; `SYNAUDIT` is the only mechanical check.
2. **KIDS packaging** requires regenerating OS5 routines before release
   (`docs/FUTURE_KIDS_PACKAGING.md`); branch state (`master` ahead 3,
   feature branch active) needs reconciliation before the next KIDS cut.
3. **Coupling to Codex**: route registration lives in Codex `SYNWEBRG.m`, and
   the C0FW framework there can supersede SYN handlers for `/addpatient` and
   `/updatepatient`. The division of labor (C0FW native vs SYN engine vs ISI
   engine, per `C0FWPOL`) is documented in Codex
   `docs/C0FW_SELECTIVE_SYN_ISI_COMPLETION_PLAN.md` but the SYN-side wrappers
   for some domains are still missing.

## Integration points

| Repo | Relationship |
|---|---|
| VistA-DataLoader (ISI) | Required KIDS prerequisite; `SYNDHP*` wrap `ISIIMP*` |
| VistA-FHIR-Server-Codex | Registers SYN routes; C0FW falls back to SYN engines; OS5 maps generated from its `codes/` |
| synthea | Upstream bundle generator |
| vehu10 / fhirdev containers | Deploy targets (`src/*.m` → `~/p`, `D EN^SYNWEBRG`) |
