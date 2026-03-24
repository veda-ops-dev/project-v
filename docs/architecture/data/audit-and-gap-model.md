# Audit and Gap Model

## Purpose

This document defines the first-pass model shape for BYDA-style audit runs, audit gaps, and closely related audit behavior in Project V.

It exists to answer:

```text
What audit records should Project V own so BYDA-style governance becomes explicit, inspectable, and traceable?
```

---

## Core Rule

If BYDA matters in Project V, audit and gap truth should be modeled explicitly.

Audit logic should not disappear into prose, one-off files, or hidden route behavior.

---

## First-Pass Concepts

### Audit Run

A bounded audit execution against a project-scoped target.

Likely concerns:

- audit type
- target entity
- project scope
- started / completed timestamps
- overall result
- summary
- invalidation or staleness handling

### Audit Gap

A bounded gap or issue found during an audit.

Likely concerns:

- parent audit run
- severity
- description
- remediation
- status
- created / updated timestamps

### Deferred Concept: Audit Layer Result

A dedicated `AuditLayerResult` record remains deferred in the first pass.

Until it is promoted explicitly, layer-like detail should be expressed through:

- audit summaries
- audit gaps
- governed audit rules

---

## First-Pass Audit Types

The first-pass BYDA core should assume at least these audit types are real and implementable:

### `research`
Allowed targets:

- `project`
- `objective`
- `initiative`
- `work_item`

Checks focus on:

- scope clarity
- evidence sufficiency
- dependency visibility
- bounded ownership clarity

Typical gap severities:

- `major`
- `minor`
- `advisory`

### `planning`
Allowed targets:

- `project`
- `objective`
- `initiative`
- `work_item`

Checks focus on:

- planning structure integrity
- governed doc consistency
- required decision visibility
- target-system and scope clarity

Typical gap severities:

- `major`
- `minor`
- `advisory`

### `implementation_readiness`
Allowed targets:

- `initiative`
- `work_item`
- `handoff`

Checks focus on:

- planning completeness
- handoff or implementation gate readiness
- required implementation linkage posture
- unresolved blocking issues

Typical gap severities:

- `critical`
- `major`
- `minor`

### `code_alignment`
Allowed targets:

- `work_item`
- `handoff`

Checks focus on:

- linked GitHub or code evidence exists
- linked evidence matches governed intent
- obvious spec-to-code drift is visible

Typical gap severities:

- `major`
- `minor`
- `advisory`

### `handoff`
Allowed targets:

- `handoff`
- `work_item`

Checks focus on:

- receiving boundary is explicit
- readiness and audit basis align
- unresolved issues remain visible

Typical gap severities:

- `critical`
- `major`
- `minor`

### `hygiene`
Allowed targets:

- `project`
- `objective`
- `initiative`
- `work_item`
- `handoff`

Checks focus on:

- ambiguity detection
- contradiction detection
- stale governance debt

Typical gap severities:

- `major`
- `minor`
- `advisory`

---

## Gap-Generation Logic

Audit gaps should be created when the audit finds a recoverable deficiency that should remain visible after the audit completes.

First-pass posture:

- hard-failure findings should normally produce at least one audit gap
- advisory or warning findings may produce minor or advisory gaps
- purely informational observations should not automatically become gaps

A good audit gap should preserve:

- what failed or weakened confidence
- why it matters
- what remediation direction exists
- whether it remains open, resolved, or invalidated

---

## Relationship to Readiness

Audit results should strengthen readiness.
They do not replace readiness entirely.

A readiness result may rely on audit outcomes.
An audit run may expose richer detail than a simple readiness state.

### Separation rule

Audit gaps and readiness gaps remain separate record families.

This separation exists because:

- audit gaps preserve audit failures, contradictions, ambiguity findings, and stale-confidence issues
- readiness gaps preserve readiness deficiencies that block or weaken progression

They may point at related weaknesses, but they should not be silently collapsed into one record type.

---

## Invalidation Principle

Project V should be able to mark downstream audit confidence stale when a material rollback or planning reversal occurs.

This is important because stale audit confidence is dangerous.

First-pass invalidation triggers should include at least:

- superseding decision recorded
- material schema or contract change after the audit
- backward status rollback that invalidates prior basis
- implementation-linked evidence changed after the audit
- GitHub linkage changed in a way that invalidates the audited basis

---

## First-Pass Value Rule

The first-pass BYDA core should make audit worthwhile by doing at least these things well:

- asking explicit questions by audit type
- generating clear pass/fail/warning/stale outcomes
- generating recoverable gaps
- detecting cross-artifact contradictions
- detecting dangerous ambiguity
- invalidating stale confidence honestly

More advanced audit ideas remain intentionally deferred until real hands-on use proves they are necessary.

---

## Final Rule

Audit runs and audit gaps should become explicit Project V records because BYDA is supposed to matter.

If audit cannot ask explicit questions, generate explicit gaps, and invalidate stale confidence honestly, it is too weak to trust.
