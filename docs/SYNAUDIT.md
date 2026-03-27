# SYNAUDIT — SYN install / OS5 verification

## Purpose

Routine **`SYNAUDIT`** (`src/SYNAUDIT.m`) is a **read-only** audit of whether **VISTA SYN DATA LOADER** artifacts look present on a VistA instance: PACKAGE (#9.4), INSTALL (#9.7) names, a spot list of repo routines, **`^SYN("2002.030",...)`** mapping subtrees, graph roots via **`SYNWD`**, and FileMan seeds from **`SYNINIT`**.

It treats a **failed or partial OS5 load** as an **error**:

- **`LOADOS5^SYNOS5LD`** (invoked from **`EN^SYNGBLLD`**, which **`POST^SYNKIDS`** runs) must populate **`^SYN("2002.030","sct2os5","direct",...)`**.
- If the direct-map count **`$$COUNT^SYNOS5LD`** is below **`MINOS5`** (default **800** in tag **`OS5CHK`**, tunable), the report prints **`*** ERROR ***`** and a summary line counting errors.

See also **`docs/FUTURE_KIDS_PACKAGING.md`** for what **`POST^SYNKIDS`** / **`EN^SYNGBLLD`** are supposed to do.

## How to run

On the target system (as the VistA user, with environment sourced):

```text
D EN^SYNAUDIT
```

Non-interactive (e.g. inside Docker):

```bash
docker exec fhirdev22 bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -run %XCMD "D EN^SYNAUDIT"'
```

## Rebuilding OS5 maps when the audit fails

If the audit reports an incomplete OS5 map, run the full SYN global rebuild (includes **`LOADOS5^SYNOS5LD`** and **`EN^SYNOS5PT`**):

```text
D EN^SYNGBLLD
```

On **`fhirdev22`** via `%XCMD`, set **`U`** first (direct mode does not always initialize it):

```bash
docker exec fhirdev22 bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -run %XCMD "S U=\"^\" D EN^SYNGBLLD"'
```

Expect database growth messages and runtime proportional to globals touched; on **`fhirdev22`** a full run completed in a few seconds after the prior partial map.

---

## Example: `fhirdev.vistaplex.org` / container `fhirdev22`

### Report before OS5 rebuild (error)

The system had a **partial** `sct2os5` direct map (**90** rows). **`SYNAUDIT`** flagged it against the **800** minimum:

```text
=== SYNAUDIT: VISTA SYN DATA LOADER install / inventory ===
Run time: Mar 27, 2026@17:25:06
--------------------------------------------------------------

PACKAGE        : IEN=595  VISTA SYN DATA LOADER^SYN^FHIR Data Loader from Synthea
INSTALL        : (no matching ^XPD(9.7) rows — empty file or different install names)
ROUTINES       : present=13  missing=0  (spot list, not exhaustive)
^SYN           : root defined
2002.030       : defined
sct2os5        : present — SNOMED to OS5 (LOADOS5^SYNOS5LD / EN^SYNGBLLD)
sct2cpt        : present — SNOMED to CPT table
sct2hf         : present — SNOMED to health factors
mh2loinc       : present — MH to LOINC
mh2sct         : present — MH to SNOMED
sct2os5 COUNT  : $$COUNT^SYNOS5LD=90
*** ERROR ***  OS5 map incomplete: 90 direct mappings (minimum 800 expected) — re-run EN^SYNGBLLD or refresh SYNOS5D* / regenerate OS5 map
graph:loinc-lab-map: subscripts at ^SYNGRAPH(2002.801,1) — POSTMAP^SYNKIDS loinc-lab-map
graph:fhir-intake: subscripts at ^SYNGRAPH(2002.801,2) — SYNFHIR / addPatient intake
NEW PERSON     : PROVIDER,UNKNOWN SYNTHEA IEN=520824660
NEW PERSON     : PHARMACIST,UNKNOWN SYNTHEA IEN=520824661
HOSP LOC       : GENERAL MEDICINE clinic IEN=23
OPTION         : SYNMENU (file 19) IEN=15166
--------------------------------------------------------------
*** 1 ERROR(S) — fix OS5 / install before relying on Synthea encounter mapping. ***

Notes:
  - Missing PACKAGE (#9.4) usually means KIDS never installed this namespace.
  - OS5 minimum direct count is 800 unless you change MINOS5 in tag OS5CHK.
  - See SYNKIDS (POST,POSTSYN,POSTMAP), SYNINIT, SYNGBLLD, docs/FUTURE_KIDS_PACKAGING.md
```

### Report after `D EN^SYNGBLLD` (success)

Command used:

```bash
docker exec fhirdev22 bash -lc 'source /home/vehu/etc/env >/dev/null 2>&1; mumps -run %XCMD "S U=\"^\" D EN^SYNGBLLD"'
```

**`$$COUNT^SYNOS5LD`** rose from **90** to **1041**; **`SYNAUDIT`** reported no OS5 errors:

```text
=== SYNAUDIT: VISTA SYN DATA LOADER install / inventory ===
Run time: Mar 27, 2026@17:28:01
--------------------------------------------------------------

PACKAGE        : IEN=595  VISTA SYN DATA LOADER^SYN^FHIR Data Loader from Synthea
INSTALL        : (no matching ^XPD(9.7) rows — empty file or different install names)
ROUTINES       : present=13  missing=0  (spot list, not exhaustive)
^SYN           : root defined
2002.030       : defined
sct2os5        : present — SNOMED to OS5 (LOADOS5^SYNOS5LD / EN^SYNGBLLD)
sct2cpt        : present — SNOMED to CPT table
sct2hf         : present — SNOMED to health factors
mh2loinc       : present — MH to LOINC
mh2sct         : present — MH to SNOMED
sct2os5 COUNT  : $$COUNT^SYNOS5LD=1041
graph:loinc-lab-map: subscripts at ^SYNGRAPH(2002.801,1) — POSTMAP^SYNKIDS loinc-lab-map
graph:fhir-intake: subscripts at ^SYNGRAPH(2002.801,2) — SYNFHIR / addPatient intake
NEW PERSON     : PROVIDER,UNKNOWN SYNTHEA IEN=520824660
NEW PERSON     : PHARMACIST,UNKNOWN SYNTHEA IEN=520824661
HOSP LOC       : GENERAL MEDICINE clinic IEN=23
OPTION         : SYNMENU (file 19) IEN=15166
--------------------------------------------------------------
Status: no OS5 errors (direct map count meets minimum).

Notes:
  - Missing PACKAGE (#9.4) usually means KIDS never installed this namespace.
  - OS5 minimum direct count is 800 unless you change MINOS5 in tag OS5CHK.
  - See SYNKIDS (POST,POSTSYN,POSTMAP), SYNINIT, SYNGBLLD, docs/FUTURE_KIDS_PACKAGING.md
```
