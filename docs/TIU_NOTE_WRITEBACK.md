# TIU note writeback from FHIR update bundles

## Summary

FHIR note writeback must create real TIU documents, not only graph-store note
text. The FHIR export path used by C0FHIR finds encounter notes by scanning
TIU file `8925` for documents linked to the visit IEN, then emits the body as
`Encounter.note`.

The writeback path therefore needs this chain:

1. `POST /updatepatient?dfn=...&load=1&returngraph=1` appends a transaction
   bundle to the patient `fhir-intake` graph.
2. `importEncounters^SYNFENC` loads the FHIR `Encounter` through
   `ENCTUPD^SYNDHP61`.
3. `ENCTUPD^SYNDHP61` returns a PCE visit IEN.
4. `INGESTFHIR^SYNFTIU` files each `Encounter.note[n].text` as a visit-linked
   TIU document through `MAKE^TIUSRVP`.
5. C0FHIR export finds the resulting `^TIU(8925,"V",visitIEN,tiuIEN)` entry
   and returns it as `Encounter.note`.

`Encounter.note` is the preferred inbound representation because it is plain
FHIR text and matches the export shape. For compatibility with existing bundles,
the loader also recognizes note-like `DocumentReference` resources that carry a
base64 `text/plain` attachment and a `context.encounter` reference. Those
attachments are decoded and filed through the same TIU path, so they also
re-export as `Encounter.note` rather than as encoded `DocumentReference` note
content.

## Why imported notes were missing

The read side does not extract notes from `fhir-intake` graph-only storage. It
extracts TIU-backed documents associated with the visit. A note can be present
in an update bundle and still be absent from `/fhir` when one of these is true:

- The encounter did not load, so there is no visit IEN.
- TIU filing was skipped or failed.
- The TIU document was not linked to the visit.
- The document was filed with no body text.
- The document status/title is not viewable by VPR/TIU.
- The consumer requested a FHIR bundle without the `encounter` domain.

## FHIR title handling

FHIR R4 `Encounter.note` is an `Annotation`. It has text, time, and author
fields, but no native note title. The loader supports two title sources:

1. Optional extension on `Encounter.note`:

   - URL: `http://vistaplex.org/fhir/StructureDefinition/va-tiu-note-title`
   - Supported values: `valueString`, `valueCode`, or `valueCodeableConcept`

2. A text header on the first note line:

   ```text
   Document: PHYSICIAN PROGRESS
   ```

If neither is present or no matching TIU document definition is found, the
loader falls back to `PROGRESS NOTES`, then `PRIMARY CARE NOTE`.

The text header remains useful because it is human-visible in the submitted
FHIR note. During TIU filing, the loader uses it as the title and strips it
from the TIU body so C0FHIR export does not duplicate the `Document:` header.
The extension is a machine-readable override for UI-generated bundles.

## Implementation points

- `SYNFHIRU.m`
  - `wsUpdatePatient` merges the posted transaction bundle into the existing
    patient graph.
  - `load=1` runs the domain loaders, including `importEncounters^SYNFENC`.
  - After encounters load, it runs `importDocRefs^SYNFTIU` so encounter-linked
    `DocumentReference` note attachments can be filed to the known visit.
  - `returngraph=1` returns load nodes for appended transaction entries.

- `SYNFENC.m`
  - `wsIntakeEncounters` calls `ENCTUPD^SYNDHP61`.
  - On success, it stores `visitIen` and calls `INGESTFHIR^SYNFTIU`.

- `SYNFTIU.m`
  - `FHIRNOTE2TIU` calls `MAKE^TIUSRVP` with the known visit IEN.
  - `INGESTFHIR` records per-note TIU status under the encounter load node:
    - `tiu/<noteIndex>/title`
    - `tiu/<noteIndex>/visitIen`
    - `tiu/<noteIndex>/status`
    - `tiu/<noteIndex>/ien`
    - `tiu/<noteIndex>/result`
  - `importDocRefs` scans appended `DocumentReference` entries in the current
    update bundle, decodes `content[].attachment.data` when
    `contentType` contains `text/plain`, resolves `context.encounter` to a
    visit IEN, and records status under `load/documentReferences/<entry>`.

## Verification

Use a patient that already exists in the target VistA image.

1. POST a small bundle with `Patient` and `Encounter` resources. The Encounter
   should include `id`, `period.start`, `class.code`, `type[0].coding[0].code`,
   and `note[0].text`.
2. Include `load=1&returngraph=1` on `/updatepatient`.
3. Confirm the response includes:
   - `transactionLoad/<entry>/encounters/visitIen`
   - `transactionLoad/<entry>/encounters/tiu/1/status=filed`
   - `transactionLoad/<entry>/encounters/tiu/1/ien=<TIU IEN>`
4. Confirm TIU linkage on the server:
   - `^TIU(8925,"V",visitIEN,tiuIEN)` exists.
   - `^TIU(8925,tiuIEN,"TEXT",...)` contains the note body.
5. Confirm FHIR re-export:
   - `/fhir?dfn=<dfn>&domains=encounter&max=<n>` includes the note under
     the matching `Encounter.note`.

## Options considered

- `MAKE^TIUSRVP`: recommended create path when the visit IEN is known. This is
  what the loader uses.
- `FILE^TIUSRVP`: useful when a TIU shell already exists and only needs the
  visit pointer set, such as CPRS note-first workflows.
- Direct FileMan/global writes to `^TIU(8925)`: not recommended because they
  bypass TIU filing rules, cross-references, alerts, and VPR event behavior.

## Related documents

- `docs/NOTES_AND_TIU_LOAD_PLANNING.md`
- `/home/glilly/VistA-FHIR-Server-Codex/docs/VISTA_VISIT_NOTE_ORDERING.md`
