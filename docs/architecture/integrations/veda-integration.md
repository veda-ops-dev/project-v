# VEDA Integration

## Purpose

This document defines the bounded integration between Project V and VEDA.

It exists to answer:

```text
How does Project V consume VEDA without absorbing observatory ownership, duplicating observatory truth, or weakening the boundary between the systems?
```

---

## Core Rule

Project V may consume VEDA signals.
Project V does not own VEDA observatory truth.

VEDA remains the canonical owner of:

- observed external reality
- project-scoped observatory state
- search and discovery observations
- observatory event history

Project V may reference that truth for planning and orchestration.
It must not become a second observatory.

---

## What Project V May Do

Project V may:

- request VEDA context for planning decisions
- reference VEDA identifiers in decision records, evidence links, and handoffs
- use VEDA observations to support prioritization
- import bounded, non-canonical convenience views where justified
- record that a planning decision was informed by VEDA evidence

---

## What Project V Must Not Do

Project V must not:

- store canonical SERP observations as Project V truth
- store canonical GA4, Search Console, crawl, YouTube, or LLM-citation observations as Project V truth
- mutate VEDA canonical data through hidden convenience paths
- treat imported observatory material as though Project V owns it
- blur planning support evidence with observatory ownership

---

## Allowed Reference Pattern

The preferred pattern is:

- VEDA owns canonical observatory records
- Project V stores explicit references to those records where needed
- Project V may derive planning interpretations from those references
- the interpretation belongs to Project V
- the observation remains owned by VEDA

A reference is not ownership.

---

## Imported Convenience Rule

If Project V imports selected VEDA data for planning convenience, that imported material must be clearly treated as:

- imported
- derived
- non-canonical outside Project V's own planning interpretation

Imported observatory context must not masquerade as active VEDA truth inside Project V.

---

## Project Scope Rule

Where Project V references VEDA records, project scope must remain explicit.

Project V must not:

- read VEDA data across projects casually
- infer project ownership ambiguously
- create planning links to the wrong project's observatory records

Cross-system references should preserve scope honesty.

---

## Identity Mapping Posture

Project V does not maintain a Project V ↔ VEDA identity federation layer.

First-pass posture:

- Project V stores VEDA-sourced identifiers as explicit reference values inside `targetLocator`
  (on `EvidenceLink`) or inside `storageLocator` / `summary` (on `ResearchDoc`)
- the caller is responsible for supplying a VEDA identifier or locator that is correct and
  in-scope for the right project
- Project V does not validate that a supplied VEDA reference exists or belongs to the expected
  project; it stores the reference as given
- cross-project VEDA references (a planning record in project A referencing a VEDA record
  that belongs to project B) must be avoided by the caller; Project V cannot enforce this
  automatically in the first pass because VEDA scoping is not resolved at write time
- if a VEDA reference is found to be wrong or cross-project during an audit, the audit must
  flag it as a provenance gap

This posture is minimal and explicit. It does not require a global identity mapping service.

---

## API / Contract Posture

Project V should consume VEDA through explicit interfaces.

Preferred patterns include:

- explicit API calls
- explicit read surfaces
- explicit import/retrieval flows
- explicit evidence linking

Project V should not depend on hidden database-level shortcuts into VEDA canonical tables.

---

## Planning Interpretation Rule

Project V may create its own planning interpretation of VEDA signals.

Examples:

- prioritization implications
- orchestration implications
- readiness implications
- work-selection implications

Those interpretations belong to Project V.
The underlying observations do not.

---

## Handoff and Decision Use

VEDA context may be used in:

- decision records
- readiness evaluations
- evidence links
- work-item rationale
- initiative prioritization

Whenever VEDA evidence is used, the provenance should remain recoverable.

---

## Anti-Drift Rules

### 1. No observatory copies as canonical planning state

Do not create local Project V tables that replicate VEDA observatory truth as if Project V owned it.

### 2. No hidden write paths into VEDA

If Project V needs VEDA to change, the boundary must remain explicit.

### 3. No scope ambiguity

If a referenced VEDA record belongs to another project, Project V must not silently accept it.

### 4. No interpretation-over-ownership confusion

A planning conclusion derived from VEDA data is Project V truth.
The data itself remains VEDA truth.

---

## Imported Convenience Posture

This section defines the first-pass rule set for any VEDA material that Project V stores locally
for planning convenience.

### Persistence is allowed only through governed shapes

Project V may persist VEDA-sourced material only through the two governed first-pass mechanisms:

- `ResearchDoc` with `sourceType = veda_reference` — for VEDA-sourced planning-support documents
  or context summaries stored as research artifacts
- `EvidenceLink` with `evidenceType = observation` — for directional links that point to a VEDA
  observation and associate it with a planning record

These are the only supported first-pass persistence shapes for VEDA-sourced material.
No additional tables, columns, or JSON fields may be used to persist observatory content
without explicit schema governance.

### Raw observatory payloads must not be stored as canonical Project V state

Project V must not store SERP data, GA4 signals, Search Console observations, crawl data,
YouTube signals, or LLM-citation observations as canonical rows inside any Project V table.

If an imported `ResearchDoc` contains a summary or interpretation of VEDA observations, that
content belongs to Project V as a planning interpretation. The underlying observation remains
owned by VEDA.

### Required boundary markers

Any persisted VEDA-sourced record must carry markers that preserve provenance:

- `ResearchDoc`: `sourceType` must be `veda_reference`. The `storageLocator` or `summary`
  must not claim Project V canonical ownership of the underlying observation.
- `EvidenceLink`: `evidenceType` must be `observation`. The `targetLocator` should reference
  the VEDA identifier or locator explicitly. The `note` field must not reclassify the observation
  as Project V-owned planning truth.

### Imported material may not be passed directly to readiness or audit as fresh VEDA truth

A persisted `ResearchDoc` or `EvidenceLink` with a VEDA origin may be used as planning support
evidence in a readiness evaluation or BYDA audit run.

However, the evaluation or audit must treat that material as:

- a planning interpretation or planning-side reference
- potentially stale if the underlying VEDA observation has changed

The evaluation or audit must not treat a local `ResearchDoc` as though it were a live VEDA
observation. Freshness of the underlying VEDA observation is the caller's responsibility.

If staleness of an imported record materially undermines the readiness or audit basis, the
evaluation must reflect that as a gap or warning rather than treating the stale import as
current evidence.

### Transient VEDA context is not subject to these rules

If an operator or LLM-assisted workflow requests VEDA context for a planning session without
persisting anything, no boundary markers are required. These rules apply only to records that
are written to the Project V database.

---

## Auth and Credential Boundary Posture

This section defines the first-pass policy posture for how Project V should interact with
VEDA from a credential and access perspective.

### Least privilege

Any credential or access token used by Project V to consume VEDA context should be scoped
to the minimum required for planning support reads.

Project V should not hold credentials that allow it to write to VEDA canonical tables.

### Read vs write

Project V's first-pass VEDA integration is read-only from a credential perspective.

Project V reads or requests VEDA context for planning support. It does not write to VEDA.

If a future workflow requires Project V to trigger VEDA operations, that interaction must
be designed explicitly as a bounded interface with governed write scope. It must not be
achieved by reusing planning-read credentials.

### Credential ownership

Credentials used to access VEDA from Project V belong to Project V as a consumer.

Those credentials must not be shared with V Forge or other systems. Each system should
maintain its own credential set for cross-system access.

### No hidden service-account overreach

Project V must not use a VEDA service account that has broader permissions than required
for the specific integration boundary. If a service account exists that has write access
to VEDA canonical tables, Project V must not use that account for its read-only planning
context integration.

This posture is policy-level. It does not prescribe secret management tooling or deployment
topology.

---

## Hammer Expectations

The hammer suite should eventually verify at least:

- Project V cannot store observatory-shaped truth as canonical Project V state where ownership is wrong
- cross-project VEDA references are rejected or fail safely
- imported VEDA convenience data persisted outside the governed shapes (`veda_reference` ResearchDoc,
  `observation` EvidenceLink) is rejected
- Project V decision and evidence surfaces preserve observatory provenance honestly

---

## Final Rule

Project V should become better at planning because it can see VEDA.

It must not become VEDA because it can see VEDA.
