# V Forge Integration

## Purpose

This document defines the bounded integration between Project V and V Forge.

It exists to answer:

```text
How does Project V hand work toward V Forge without absorbing execution ownership, draft ownership, or publishing workflow truth?
```

---

## Core Rule

Project V may direct and prepare work for execution.
Project V does not own V Forge execution truth.

V Forge remains the canonical owner of:

- drafts
- editorial workflow
- revision state
- publishing workflow
- produced assets
- production-facing execution state

Project V may coordinate handoff into V Forge.
It must not become a shadow production system.

---

## What Project V May Do

Project V may:

- identify work that should move toward execution
- record explicit handoffs to V Forge
- track orchestration-level readiness for handoff
- record why a handoff is occurring
- track orchestration-level status such as blocked, ready, handed off, or closed from the planning perspective
- reference V Forge identifiers where explicit linkage is needed

---

## What Project V Must Not Do

Project V must not:

- become the system of record for draft state
- own revision workflow
- own publish-state transitions
- own produced assets
- store canonical execution truth as Project V state
- mutate V Forge canonical tables through hidden convenience paths

---

## Handoff Rule

The preferred pattern is:

- Project V decides that work is ready for execution
- Project V records a bounded handoff
- V Forge receives and owns the execution state that follows

A handoff is not shared ownership.
It is a transition of responsibility across bounded systems.

---

## Handoff Requirements

A valid Project V to V Forge handoff should preserve at least:

- source project identity
- source record identity
- target system classification
- handoff type
- readiness basis
- rationale or context summary
- handoff status

The handoff must remain explainable.

---

## Orchestration Status vs Execution Status

Project V may track orchestration-level status related to a handoff.

Examples:

- ready for handoff
- handed off
- awaiting response
- blocked before handoff
- closed from planning perspective

These are not substitutes for V Forge execution state.

Project V should not treat orchestration status as though it were draft, editorial, or publishing truth.

---

## Return-Path Semantics

Handoff status tracks what Project V knows about the disposition of the handoff from its
orchestration perspective. Project V does not own V Forge internal execution state.

The first-pass return-path posture is:

### `accepted` — V Forge has acknowledged the handoff

`accepted` means Project V has recorded that the receiving boundary acknowledged the handoff.
It does not mean execution is complete. It does not transfer any ownership of execution state
to Project V.

How acceptance is communicated is out of scope for Project V's first-pass doc.
Project V records the acknowledgement. It does not infer it from execution signals.

### `closed` — the handoff is resolved from Project V's orchestration perspective

`closed` means Project V has explicitly closed the handoff record.
This may happen because:

- V Forge completed the work and Project V was informed or decided to close
- the handoff was withdrawn or superseded before acceptance
- the work was cancelled from the planning side

`closed` is a Project V orchestration decision. It does not reflect V Forge execution state
directly unless a caller explicitly records that relationship in the `readinessBasisSummary`
or a linked `DecisionRecord`.

When a handoff transitions to `closed`, `completedAt` is set server-side in the same transaction.

### Rejection / bounce-back posture

Project V does not model V Forge rejection as a first-class handoff status.

If V Forge cannot accept a handoff, the first-pass mechanism is:

- the handoff status remains at `handed_off` or is moved back to `ready` or `proposed`
  through an explicit operator-initiated status transition
- the reason for the return is recorded via the `reason` field on the status transition
  or via a linked `DecisionRecord`

Project V must not invent execution-side rejection codes or error states from V Forge.
If richer bounce-back semantics are needed later, they must be modeled explicitly through
schema governance.

### Re-entry posture

If a handoff is returned to an earlier status (for example, from `handed_off` back to `ready`
or `proposed`), that transition must be operator-initiated and must follow the governed
status-transition rules defined in `docs/architecture/data/status-transitions.md`.

A re-entered handoff is still the same record. Project V does not create a new handoff record
automatically when work bounces back. If the original handoff needs to be retired and a new
one created with different scope, that is an explicit operator action.

### What Project V records; what it does not record

Project V records:

- the fact that a handoff was proposed, readied, handed off, accepted, or closed
- the reason for a status change where a reason is required or supplied
- the readiness basis summary for context

Project V does not record:

- V Forge's internal execution progress
- draft or editorial workflow state
- production or publishing outcomes
- execution-side error details from V Forge internals

---

## Project Scope Rule

Where Project V references V Forge work, project scope must remain explicit.

Project V must not:

- create ambiguous cross-project handoffs
- attach a project's planning work to another project's execution flow by accident
- infer project ownership loosely in multi-project conditions

---

## Identity Mapping Posture

Project V does not maintain a Project V ↔ V Forge identity federation layer.

First-pass posture:

- Project V stores V Forge-side identifiers as explicit reference values inside
  `readinessBasisSummary` on the `Handoff` record or inside a linked `DecisionRecord`
- the caller is responsible for supplying a V Forge work package identifier or reference
  that is correct and scoped to the right project
- Project V does not validate that a supplied V Forge identifier exists or belongs to the
  expected project; it stores the reference as given
- cross-project contamination (a handoff in project A referencing a V Forge work package
  that belongs to project B) must be avoided by the caller; Project V cannot enforce this
  automatically in the first pass
- if a V Forge reference is found to be wrong or cross-project during an audit, the audit
  must flag it as a boundary or provenance gap

This posture is minimal and explicit. It does not require a global identity mapping service.

---

## API / Contract Posture

Project V should integrate with V Forge through explicit boundaries.

Preferred patterns include:

- explicit handoff contracts
- explicit route families
- explicit IDs and references
- explicit success and failure behavior

Project V should not depend on hidden database-level shortcuts into V Forge canonical tables.

---

## Planning Interpretation Rule

Project V may interpret execution readiness and orchestration implications.

Examples:

- whether the work package is complete enough to hand off
- whether blockers still exist
- whether a dependency prevents handoff

Those interpretations belong to Project V.
The execution state that follows belongs to V Forge.

---

## Anti-Drift Rules

### 1. No execution truth copies as canonical Project V state

Do not create Project V tables that become disguised draft, editorial, or publishing systems.

### 2. No hidden write paths into V Forge

If Project V needs V Forge to change, the interaction must remain explicit.

### 3. No scope ambiguity

A handoff must clearly identify which project the work belongs to.

### 4. No orchestration-over-execution confusion

Project V may know a handoff happened.
That does not make it the owner of what V Forge does next.

---

## Auth and Credential Boundary Posture

This section defines the first-pass policy posture for how Project V should interact with
V Forge from a credential and access perspective.

### Least privilege

Any credential or token used by Project V to interact with V Forge should be scoped to
the minimum required for handoff coordination.

Project V should not hold credentials that allow it to write to V Forge canonical execution
or draft tables.

### Read vs write

Project V's first-pass V Forge integration is handoff-coordination-only from a credential
perspective.

Project V records handoffs and may request acknowledgement signals. It does not own or write
V Forge execution state.

If a future workflow requires Project V to trigger V Forge operations beyond handoff
coordination, that must be designed explicitly as a bounded interface. It must not be
achieved by reusing existing coordination credentials.

### Credential ownership

Credentials used to interact with V Forge from Project V belong to Project V as a consumer.

Those credentials must not be shared with VEDA or other systems. Each system should maintain
its own credential set for cross-system access.

### No hidden service-account overreach

Project V must not use a V Forge service account that has broader permissions than required
for the specific handoff coordination boundary. If a service account exists that can write
to V Forge execution or editorial tables, Project V must not use that account.

This posture is policy-level. It does not prescribe secret management tooling or deployment
topology.

---

## Hammer Expectations

The hammer suite should eventually verify at least:

- Project V cannot store execution-shaped truth as canonical Project V state where ownership is wrong
- invalid or ambiguous handoffs fail correctly
- cross-project handoff contamination is rejected
- orchestration-level status does not silently impersonate V Forge execution state

---

## Final Rule

Project V should become better at deciding and sequencing because it can hand work to V Forge.

It must not become V Forge because it can hand work to V Forge.
