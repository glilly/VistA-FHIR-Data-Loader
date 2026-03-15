# Graph Store Compatibility

## Purpose

This branch needs to run on systems that keep named graphs in either:

- `^%wd(17.040801,...)`
- `^SYNGRAPH(2002.801,...)`

The goal is compatibility, not migration. Other applications may already depend
on the active graph store on a given system, so SYN must detect the live graph
backend and use it.

## Background

Historically:

- `master` is the `%wd` lineage
- `vaready` is the `^SYNGRAPH` lineage

This branch is based on `vaready` because it contains the newer lab-ingestion
work, but it must still run on `%wd` systems such as `OSEHRA`.

That means new code should not hardcode either graph backend in domain logic.

## Environment Evidence

Two real environments show the split clearly.

### OSEHRA

`OSEHRA` stores graphs in `%wd`:

```text
OSEHRA>W $O(^DIC("B","graph",""))
17.040801
OSEHRA>W $G(^DIC(17.040801,0,"GL"))
^%wd(17.040801,
```

The named-graph index confirms that SYN working graphs already live there:

```text
^%wd(17.040801,"B","fhir-intake",3)=""
^%wd(17.040801,"B","mapping-errors",40)=""
```

### VEHU

`VEHU` stores graphs in `^SYNGRAPH`:

```text
VEHU>W $O(^DIC("B","GRAPH",""))
2002.801
VEHU>W ^DIC(2002.801,0,"GL")
^SYNGRAPH(2002.801,
```

Its named-graph index shows the same SYN working graphs under `^SYNGRAPH`:

```text
^SYNGRAPH(2002.801,"B","fhir-intake",2)=""
^SYNGRAPH(2002.801,"B","loinc-lab-map",1)=""
^SYNGRAPH(2002.801,"B","mapping-errors",3)=""
```

## Important Design Rule

Do not use `setroot` to test whether a graph exists.

`setroot` is an open-or-create operation. If a graph name is missing from the
`"B"` index, `setroot` can create it. That means using `setroot` during
detection would mutate the graph store and could bias the backend choice.

Detection must therefore be read-only and should look at the `"B"` indexes
directly:

- `%wd`: `^%wd(17.040801,"B",graph,ien)`
- `SYNGRAPH`: `^SYNGRAPH(2002.801,"B",graph,ien)`

## Current Design

`SYNWD` is now the graph backend adapter for this branch.

### Backend selection

`$$GRTN^SYNWD(graph)` now picks a backend in this order:

1. If the requested graph name already exists in `^SYNGRAPH(2002.801,"B",...)`,
   use `SYNGRAF`.
2. If the requested graph name already exists in `^%wd(17.040801,"B",...)`,
   use `%wd`.
3. If the requested graph does not exist yet, follow the backend that already
   owns standard SYN working graphs such as:
   - `fhir-intake`
   - `loinc-lab-map`
   - `html-cache`
   - `seeGraph`
4. If neither the requested graph nor the anchor graphs exist, prefer
   `^SYNGRAPH` when both backends are available, because this branch is
   `vaready`-derived.
5. If only one backend is installed, use that backend.

This gives the desired behavior:

- `OSEHRA` resolves to `%wd`
- `VEHU` resolves to `^SYNGRAPH`
- a brand-new mixed environment defaults to `^SYNGRAPH`

### Adapter entry points

The following `SYNWD` entry points now route through the selected backend:

- `setroot`
- `rootOf`
- `addgraph`
- `purgegraph`
- `insert2graph`

Future code should go through `SYNWD` rather than calling `%wd` or `SYNGRAF`
directly from domain routines.

## Code Changes In This Branch

### 1. `SYNWD`

`src/SYNWD.m` was updated to:

- detect backend by direct `"B"` index lookup
- keep detection side-effect free
- prefer `^SYNGRAPH` as the fallback default for new graphs
- act as the only adapter layer that knows how to call `%wd` or `SYNGRAF`

### 2. `MAPERR`

`src/SYNQLDM.m` `MAPERR` no longer hardcodes `^SYNGRAPH`.

It now does:

```text
S GROOT=$$setroot^SYNWD("mapping-errors")
```

and writes via `@GROOT@(...)`.

That means `mapping-errors` will be created or reused in the correct graph store
for the current system.

### 3. Remaining `%wd` holdouts removed

The last direct graph-root calls to `%wd` in domain logic were switched to
`SYNWD`:

- `src/SYNFLAB.m`
- `src/SYNLABFX.m`

After that cleanup, there are no remaining direct `%wd` graph-root callers in
`src/` outside `SYNWD` itself.

## Validation Notes

In the `OSEHRA` test container, the updated adapter resolves:

- `$$GRTN^SYNWD("fhir-intake")` to `%wd`
- `$$setroot^SYNWD("mapping-errors")` to `^%wd(17.040801,40)`

Detection was also checked with a nonexistent graph name and verified not to
create a new `"B"` index entry during backend selection.

## Guidance For Future Changes

- Treat `SYNWD` as the abstraction boundary for graph storage.
- Do not hardcode `^SYNGRAPH` in new loader logic.
- Do not hardcode `%wd` in new loader logic.
- Do not use `setroot` as an existence test.
- If a new routine needs graph access, route it through `SYNWD`.

## Merge Outlook

This branch is accumulating work beyond the original `vaready` branch. The
graph-store compatibility changes here are designed so that this line of work
can later merge back into `vaready` cleanly, while `master` can be brought
forward separately without forcing a graph-store migration.
