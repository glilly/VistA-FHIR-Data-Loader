# Notes / TIU load planning (Synthea → VistA)

## Goal

Extend the **VISTA SYN DATA LOADER** so clinical **notes** can be filed into the live patient chart (not only into the synthetic graph), with correct behavior for **inpatient vs outpatient** visit linkage and downstream consumers (e.g. **Clinical Reminders**).

This note captures **problem framing**, what **already exists in this repo**, how **VPR** ties documents to **visits**, where to find **national** RPCs and routines (**not** shipped in this repository), and a **deep dive** on **which code to evaluate** for FHIR → **#8925** import (FHIR resource targets, SYN hooks, national read APIs as a filing spec, and write-path options).

---

## Clinical / visit model (problem statement)

### Inpatient

- A **primary visit** (or principal encounter) is often created at **admission** and reused for many inpatient clinical actions until **discharge**.
- If **all** subsequent documentation (notes, orders-linked artifacts, etc.) is forced to that **same** visit record, many items inherit the **admission date/time** as their encounter time.
- That **collapses the timeline** and breaks or weakens logic that depends on **when** something occurred (notably **Clinical Reminders**, which evaluate events in time windows).

**Common mitigation (to validate on your target VistA build):** create **additional (secondary) visit** records for inpatient stays—e.g. per day, per movement, or per documentation event—so each **TIU document** can point at a visit whose **date/time** matches the **clinical moment**. Outpatient flows often do **not** need the same pattern because a **single visit** per encounter is usually sufficient.

### Outpatient

- Often a **single visit** per encounter is adequate; **PCE**-backed visit creation plus **TIU** `.03` Visit pointer is the usual pattern.

**SYN implication:** any note loader must choose or create a **visit IEN** (`^AUPNVSIT`) appropriate to **inpatient vs outpatient** semantics before filing **#8925**.

---

## What this repo does today (not yet full TIU filing)

### Graph-only “notes” (not FileMan #8925)

- **`SYNFTIU`** (`src/SYNFTIU.m`): **`TONOTE^SYNFTIU`** appends lines to a **graph-store** array under the patient’s `fhir-intake` load tree (`load/encounters/.../note`). It does **not** call **TIU** APIs and does **not** create **`^TIU(8925,...)`** records.
- **`SYNFCP`** (`src/SYNFCP.m`): builds care-plan narrative text via **`TONOTE^SYNFTIU`** (still graph-local).
- **`SYNDHP91`** (`src/SYNDHP91.m`): header comments say “Generate TIU note for careplan”; **`CPLUPDT`** in practice only builds **`ENCDATA`** health factors and calls **`$$DATA2PCE^PXAI("ENCDATA",...)`**. It does **not** invoke **TIU** or create **#8925**. Narrative for care plans in the graph is still **`TONOTE^SYNFTIU`** from **`SYNFCP`**, not a chart note.

### Visit creation used by encounter load (PCE, not TIU)

- **`SYNFENC`** (`src/SYNFENC.m`): when `args("load")=1`, calls **`ENCTUPD^SYNDHP61`** and stores returned **`visitIen`** on the encounter in the graph (`visitIen`, indexes via **`setIndex^SYNFHIR`**).
- **`SYNDHP61`** (`src/SYNDHP61.m`): **`ENCTUPD`** uses **`$$DATA2PCE^PXAI("ENCDATA",...)`** with package **PCE** (`$$FIND1^DIC(9.4,...,"PCE")`) to create/update the **visit** and related **PCE** structures.

So: **visits** for loaded outpatient-style encounters today are **PCE-driven**; **notes** in **`SYNFTIU`** are **not** wired to **TIU** filing.

---

## How VistA ties “notes” to patients and visits (reference behavior)

### File **#8925** (TIU DOCUMENT)

- Documents are stored in **`^TIU(8925,...)`**.
- Field **`.03`** is the **Visit** pointer (ties the document to a row in **`^AUPNVSIT`** for standard linkage).
- VPR extraction uses the **“V”** cross-reference on visit, e.g. listing documents for a visit (see **`FIND^DIC(8925,...,"V",...)`** usage in **`TIU^VPRDJ04A`** in the reference corpus).

### VPR routines in `FHIR-source-files` (read path, not upload)

These illustrate **read** and **event** wiring, useful when validating what your filed notes must satisfy:

| Routine (corpus) | Role |
|------------------|------|
| **`VPRENC.m`** | **`TIU^VPRENC`**: encounter extract includes **TIU** docs; uses **`^TIU(8925,"V",VST,...)`** style traversal. |
| **`VPRDJ04A.m`** | **`TIU(VISIT,ARR)`**: loads document list for a **visit** via **`FIND^DIC` on #8925** with **"V"** index and status screen. |
| **`VPRDTIU.m`** | **`TGET^TIUSRVR1`**: retrieve document **text** via national **TIU Broker/server** layer (read side). |
| **`VPREVNT.m`** | **`TIU` / `TIUR` / `TIUS`**: **HL7/document action** listeners posting VPR updates; shows how **DFN**, **document IEN**, and **visit** flow into the extract. |

None of the above **creates** inpatient/outpatient notes for loads; they document **expected** relationships once **#8925** exists.

---

## RPCs and national M routines that **upload** / manage notes

This repository **does not** contain the **TIU** package or full **CPRS GUI** RPC sources. Use the indexes below on a full VistA tree or the public doc sites.

### 1. [Vivian VistA Code Documentation](https://vivian.worldvista.org/dox/) (WorldVistA)

Use the landing page sections:

- **Package List** → **TEXT INTEGRATION UTILITIES (TIU)** (exact name may vary slightly by build): routines, assigned namespaces, FileMan files (**#8925**, **#8925.1**, etc.).
- **Package List** → **RPC BROKER**: RPC-to-routine mapping.
- **Routine Alphabetical List**: search prefixes such as **`TIUSRVR`**, **`TIUSRV`**, **`ORQQTIU`**, **`ORWTIU`** (CPRS/GUI layer often prefixes **`ORW`** / **`ORQQ`** for Broker entry points).

From there, open a routine page to see **called/caller** graphs and **source** (as indexed).

### 2. [VA Software Document Library](https://www.va.gov/vdl/)

Browse **Clinical** (and related) sections for **CPRS** / **TIU** application monographs and interface guides. Example class of artifact: *Text Integration Utility* / CPRS documentation (titles change by release). Use VDL for **release-specific** filing rules, user workflows, and sometimes **API** summaries.

### 3. VistApedia (supplement)

- [TIU Package API](https://www.vistapedia.com/index.php/TIU_Package_API) — overview entry points.
- [TIU CREATE RECORD](https://www.vistapedia.com/index.php/TIU_CREATE_RECORD) — describes an RPC used to **create** **#8925** rows (parameters include patient, title, text array); **verify** name, option number, and parameters on **your** system’s **REMOTE PROCEDURE** file (**#8994**) and Vivian.

**Practical discovery on a running system:** In FileMan or a programmer shell, search **`^DIC(8994,"B",...)`** for routines containing **`TIU`** or **`ORWTIU`** and map each RPC to its **`ROUTINE`** field, then open that routine in Vivian or your local `Packages/TIU` source.

### Names to grep for on a full VistA source tree

| Pattern | Typical role |
|---------|----------------|
| **`TIUSRVR*`** | Broker “server” routines for TIU I/O (e.g. text retrieval **`TGET^TIUSRVR1`** per `VPRDTIU`). |
| **`TIUSRV*`** | Additional TIU service APIs. |
| **`ORWTIU*`** / **`ORQQTIU*`** | CPRS client RPC entry points (lists, saves, signatures—**confirm** per build). |
| **`TIU CREATE RECORD`** (RPC name) | Document **creation** into **#8925** (per VistApedia; confirm on **#8994**). |
| **`NEW^TIUDA`**, **`FILING^TIUDA`** (if present) | Classic TIU **API** tags (exact names **version-dependent**—locate via TIU package routine list in Vivian). |

**DBIA:** Any SYN loader that calls national APIs must respect **DBIA** / supported entry points for your distribution (OSEHRA, VA, WorldVistA, etc.).

---

## Deep dive: code to evaluate for FHIR note import

This section narrows **which code** to read next—on a **full VistA source tree**, in **this repo**, and in the **`FHIR-source-files`** VPR corpus—to pick a **supported** filing path and wire it into **SYN**.

### 1. FHIR side: which resources carry “notes”

Synthea / FHIR R4 style bundles may expose narrative in several shapes. Expect to **normalize** into a common internal structure (patient, authored datetime, author, encounter link, plain text or HTML, type/code) before calling VistA.

| FHIR resource | Typical use for SYN | Notes |
|----------------|--------------------|--------|
| **`DocumentReference`** | **Primary target** for clinical documents (PDF/text), `content.attachment`, `type`, `category`, `context.encounter` | Best match to **TIU #8925** “document” semantics; map `context.encounter` to Synthea **`Encounter.id`** then to **`visitIen`**. |
| **`Composition`** | Structured clinical document header + sections | Less common in minimal Synthea exports; may appear in richer bundles. Section narrative may reference **`Binary`** or embedded **`text.div`**. |
| **`DiagnosticReport`** | Reports with **`presentedForm`** or linked **`Media`** | SYN already has **`SYNFPAN`** / **`DiagnosticReport`** paths for **panels**; distinct from progress-note **TIU** class but may share filing patterns for **LR**-class TIU (national behavior is specialized). |
| **`Observation`** | **`valueString`** / note fields for free text | Often secondary; filter by category to avoid treating every lab string as a progress note. |

The importer menu in **`README.md`** (view ingested FHIR JSON) lists resource categories for a typical run; **DocumentReference** may need to be **added to the menu** and to **`getIntakeFhir^SYNFHIR`**-driven loaders once bundles include it.

### 2. SYN side: where new logic should plug in

| Component | Location | Relevance |
|-----------|----------|-----------|
| **Bundle parse / per-type extract** | **`SYNFHIR`** (`src/SYNFHIR.m`): **`getIntakeFhir`**, **`get1FhirType`**, **`getEntry`** | Same pattern as **`Encounter`**, **`CarePlan`**, etc.: merge matching **`resourceType`** entries into a work array under the patient **`fhir-intake`** graph **`ien`**. |
| **Encounter → visit IEN** | **`SYNFENC`** + **`visitIen^SYNFENC`**, **`ENCTUPD^SYNDHP61`** | **Outpatient:** after load, resolve **`visitIen`** for the Synthea encounter UUID used in **`DocumentReference.context.encounter`**. **Inpatient:** likely **insufficient** if only one visit exists—you may need a **new** helper (PCE or scheduling API) to create **time-stamped** visits before filing notes. |
| **Graph staging (optional)** | **`TONOTE^SYNFTIU`** | Can remain a **staging** buffer (audit trail) **before** TIU filing, or be bypassed once **#8925** exists. |
| **DHP / PCE bridge** | **`SYNDHP61`**, **`SYNDHP91`**, **`DATA2PCE^PXAI`** | Establishes how SYN passes **VISIT** into national APIs; **note filing** will be a **parallel** API, not a substitute for **`DATA2PCE`**. |

**Suggested new routine name (illustrative):** `SYNFDOC` or `SYNFTIUF`—**`SYNF*`** parallel to **`SYNFENC`**, **`SYNFCP`**, with an entry like **`wsIntakeDocumentReference`** or a batch tag called from the existing intake driver after encounters exist.

### 3. National “read” APIs as a spec for what filed data must satisfy

**`VPRDTIU`** (`FHIR-source-files/VPRDTIU.m`) is **read-only** but lists **supported** national calls (with **DBIA** numbers in the routine header). Anything you file into **#8925** should be **compatible** with how these APIs interpret documents (status, class, visit, text).

**External references declared on `VPRDTIU` (examples):**

| Routine / call | DBIA (as listed) | Role for *your* design |
|----------------|------------------|-------------------------|
| **`TGET^TIUSRVR1`** | 2944 | Returns **body text** for document IFN; use after load to **verify** content round-tripped. |
| **`EXTRACT^TIULQ`** | 2693 | Pulls **#8925** / title fields; **`EN1^VPRDTIU`** uses **`.01:.04;1501:1508`**—your filed doc should populate these consistently. |
| **`$$RESOLVE^TIUSRVLO`** | 2834, 2865 | Builds the **“TIU resolve string”** used across VPR; filing APIs often expect consistent **title / class** resolution. |
| **`CONTEXT^TIUSRVLO`** | (via **TIUSRVLO**) | **`EN^VPRDTIU`** loops document lists by **class** and **context**—documents that fail **`$$INFO^VPRDTIU`** (status draft/retracted, addendum, etc.) are **dropped** from extract. |
| **`ISCNSLT^TIUCNSLT`**, **`ISA^TIULX`**, **`ISCP^TIUCP`**, **`ISSURG^TIUSROI`** | 5546, 3058, 3568, 5676 | **`CATG^VPRDTIU`** uses these to **classify** `#8925.1` titles (progress note, DS, LR, CP, …). Your **title / document definition** choice determines **VPR category** and downstream FHIR mapping. |

**Additional list API (corpus):** **`VPRP20.m`** calls **`LIST^TIUVPR(.VPRD,DFN,38,VPRBDT,VPREDT)`**—**`38`** is the **TIU clinical document** class filter. After SYN loads notes, this is a strong **sanity check** that documents appear in the same lists CPRS/VPR use.

**None of the above creates documents**—they define **validation** and **classification** targets.

### 4. Candidate **write** paths (evaluate on your build)

| Approach | Where to confirm | Pros | Cons / risks |
|----------|------------------|------|----------------|
| **A. Broker RPC** (e.g. **TIU CREATE RECORD** per [VistApedia](https://www.vistapedia.com/index.php/TIU_CREATE_RECORD)) | **`^DIC(8994)`**, [Vivian RPC Broker package](https://vivian.worldvista.org/dox/) | Clear client/server boundary; matches how GUI tools file notes | Must register RPCs if missing; parameter contract (`TIUX` array, suppress flags) must match; **DUZ** / user context. |
| **B. TIU package M API** | TIU routines in Vivian (`TIUDA`, `TIUSRV*` create/save tags—names vary by version) | Efficient inside `mumps -direct` ingest | DBIA and version drift; need an explicit supported entry point from your custodian. |
| **C. `FILE^DIE` on #8925** | — | Fast to prototype | **Unsafe**: bypasses TIU business rules, signatures, xrefs, and events (**`AEVT`**, VPR listeners). **Not recommended** for production SYN. |
| **D. Extend DATA2PCE only** | PXAI / PCE package docs | Already integrated | Filed as PCE-style data, not a substitute for progress-note TIU documents in CPRS. |

**Recommendation:** shortlist **A** or **B** after grepping your VistA **`Packages/TIU`** for tags named **`CREATE`**, **`SAVE`**, **`NEW`**, **`STORE`**, and cross-checking **#8994** RPC names **`ORWTIU*`**, **`TIU`**.

### 5. Visit pointer (`.03`) — tie-breaker for inpatient vs outpatient

For **each** FHIR note:

1. Resolve **`Encounter`** reference → Synthea encounter id → **`visitIen^SYNFENC(ien,encId)`** when that encounter was loaded as **outpatient-style** PCE visit.
2. If **`visitIen`** is missing or encounter was **inpatient** with a single **admission** visit, **do not** silently file to that visit if the note’s **`dateTime`** is far from admission—instead **branch** to a **new** visit-creation routine (to be selected from **PCE** / **scheduling** national APIs—**next research task**).

### 6. Concrete next steps (archaeology checklist)

On a **development** VistA with TIU loaded:

1. [Vivian](https://vivian.worldvista.org/dox/): open **TIU** package → export routine list → sort **`TIUSRVR*`**, **`TIUSRV*`**, **`TIUDA*`**, **`TIUVPR`**.  
2. Read **`TIUVPR`** (caller of **`LIST^TIUVPR`** in **`VPRP20`**) to see filter semantics for class **`38`**.  
3. Search **`^DIC(8994,"B","TIU")`** and **`"ORWTIU"`**; open each routine’s **first few lines** for parameter lists.  
4. [VDL](https://www.va.gov/vdl/) / site PDFs: **TIU** interface guide for **create / sign / cosign** workflow constraints.  
5. Prototype: create **one** unsigned progress note via chosen RPC/API, set **`.03`** to a known **`visitIen`**, then **`D EN1^VPRDTIU(VPRX,.DOC)`** + **`$$TEXT^VPRDTIU(ifn)`** to confirm read-back.

---

## Design checklist for SYN work

1. **Visit strategy**
   - **Outpatient:** reuse or create one **visit** per Synthea encounter consistent with **`ENCTUPD^SYNDHP61`** / **PCE** rules.
   - **Inpatient:** decide when to **reuse admission visit** vs **create child/secondary visits** so **note time** ≠ **admission time**; align with site **Reminder** definitions.

2. **Filing API choice**
   - Prefer a **single supported** path: Broker **RPC** (for RPC-based loaders) or a **documented** **`^TIU`** API tag (for server-side M only), not ad-hoc **`FILE^DIE`** on **#8925** unless explicitly approved.

3. **Link note → visit**
   - Ensure **#8925** **`.03`** (Visit) is set to the **visit IEN** chosen above; verify **`^TIU(8925,"V",visit,doc)`** behavior matches VPR expectations.

4. **Title / document definition**
   - Map Synthea/FHIR note types to **TIU document definitions** (**#8925.1** / national titles) per site build.

5. **Signatures / status**
   - Determine required **status** (unsigned vs signed) for synthetic data and for Reminder evaluation.

6. **Testing**
   - After load: VPR / FHIR extract should list **DocumentReference**-equivalent content; **Clinical Reminders** evaluation (if available) on a **staged** patient.

---

## Summary

| Layer | In this repo | National (Vivian / VDL / VistApedia) |
|-------|----------------|--------------------------------------|
| **Visit creation** | **`ENCTUPD^SYNDHP61`** → **`DATA2PCE^PXAI`** | **PCE** package, **PXAI** |
| **Note text staging** | **`TONOTE^SYNFTIU`** (graph only) | — |
| **Note filing to chart** | *Not implemented* | **TIU** package, **Broker RPCs** (**`TIUSRVR*`**, **`ORWTIU*`**, **`TIU CREATE RECORD`**, etc.) |
| **Read / validate** | — | **VPR** `TIU*` tags, **`TGET^TIUSRVR1`**, **`FIND^DIC` on #8925 "V"`, **`LIST^TIUVPR`** |

This document is a **planning** artifact; implementation should add routines under **`SYN*`** (or approved wrappers) and reference **DBIA-supported** national entry points discovered via [Vivian](https://vivian.worldvista.org/dox/) and [VDL](https://www.va.gov/vdl/) for your exact build.
