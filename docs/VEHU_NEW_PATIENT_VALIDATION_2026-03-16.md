# VEHU New Patient Validation

## Purpose

This note captures the live VEHU validation that followed the `vaready-wd-compat`
deployment and the runtime loader fix discovered during the first real
`addPatient` attempts.

Environment:

- host: `fhirdev.vistaplex.org`
- container: `fhirdev`
- graph backend: `^SYNGRAPH(2002.801,...)`
- active SYN code level: `vaready-wd-compat` at `4fc4858`, plus the local
  `SYNDHP63` fix described below

## Runtime Issue Found

The first non-duplicate patient import surfaced a GT.M/YottaDB-only bug in
`LABADD^SYNDHP63`.

Error returned from `POST /addPatient`:

```text
%YDB-E-LVUNDEF, Undefined local variable: DHPCSAMP
place: LABADD+24^SYNDHP63
```

Cause:

- `SYNFLAB` calls `LABADD^SYNDHP63` without always passing the optional
  collection sample argument.
- `SYNDHP63` then wrote `DHPCSAMP` directly into `RETSTA("LABINPUT",...)` and
  `LABARRAY("COLLECTION_SAMPLE")`, which is safe on systems that tolerate an
  undefined local read, but fails on GT.M/YottaDB.

Fix:

```mumps
LABADD(RETSTA,DHPPAT,DHPLOC,DHPTEST,DHPRSLT,DHPRSDT,DHPLOINC,DHPCSAMP) ;Create lab test
 ;
 N PATDFN,PATSSN,LABARRAY,RC,DHPRC,LOINCIEN,TESTIEN,LABTEST,SAVEIO
 S DHPCSAMP=$G(DHPCSAMP)
 ;
 S RETSTA("LABINPUT","DHPPAT")=DHPPAT
```

This preserves the optional-argument behavior while making the routine safe on
GT.M/YottaDB.

## Deployment And Validation

The patched `SYNDHP63.m` was copied into `/home/vehu/p` in the running VEHU
container and checked with `XINDEX`.

Observed result:

- `XINDEX` reported `No errors or warnings to report` for `SYNDHP63`

## Live Import Results

Three real Synthea bundles were used to validate the live path:

1. `Sergio619 Manzanares924`
   - rejected as `Duplicate SSN`
   - later confirmed to already exist on VEHU as `DFN 101088`
2. `Abbie917 Leighann368 Harris789`
   - exposed the `DHPCSAMP` undefined-local bug on the first attempt
   - after the fix, VEHU reported `Duplicate SSN`, and the patient was confirmed
     to exist as `DFN 101089`
3. `Francesco636 Daugherty69`
   - imported successfully after the `SYNDHP63` fix

Successful import details for `Francesco636 Daugherty69`:

- source bundle:
  `FHIR-source-files/tonight-20260315-1773628785/fhir/Francesco636_Daugherty69_26f32ae0-b3d2-fff6-88ee-26c5ac1f697b.json`
- `DFN`: `101090`
- `ICN`: `4263043815V188953`
- graph `IEN`: `15`

Successful `addPatient` summary:

- encounters loaded: `32`, errors: `2`
- procedures loaded: `94`, errors: `24`
- labs loaded: `102`, errors: `13`
- vitals loaded: `54`, errors: `10`
- conditions loaded: `19`, errors: `9`
- meds loaded: `2`, errors: `6`
- immunizations loaded: `5`, errors: `9`
- care plans loaded: `2`

## Cross-Repo Outcome

`GET /fhir?dfn=101090` from the VEHU FHIR server then returned:

- `Patient`: `1`
- `Encounter`: `34`
- `Condition`: `19`
- `Observation`: `156`
- `DiagnosticReport`: `14`
- `MedicationRequest`: `2`
- `Immunization`: `5`
- `Procedure`: `103`

The placeholder-procedure regression remained fixed on this fresh patient:

- exported placeholder procedures (`6456Q` / `OUTPATIENT ENCOUNTER`): `0`

## Takeaway

The graph-store compatibility work was sufficient for VEHU, and the remaining
runtime blocker for fresh-patient validation was a separate GT.M/YottaDB local
variable safety bug in `SYNDHP63`. After normalizing `DHPCSAMP` with `$G`, the
live VEHU `addPatient` path succeeded for a newly generated patient.
