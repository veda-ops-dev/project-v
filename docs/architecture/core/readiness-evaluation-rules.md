# Readiness Evaluation Rules

## Purpose

This document defines the first-pass evaluation rules that drive Project V readiness results.

It exists to answer:

```text
How does Project V determine ready, not_ready, ready_with_warnings, and deferred in a way that is explicit enough to implement and hard to fake?
```

Read this with:

- `docs/architecture/core/readiness-methodology.md`
- `docs/architecture/core/project-v-operational-workflow.md`
- `docs/architecture/core/audit-evaluation-rules.md`
- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/api/readiness-api.md`
- `docs/architecture/testing/hammer-plan.md`

---

## Core Rule

Readiness results are server-owned and must be produced by governed evaluation logic.

The server must not accept a caller-supplied result as canonical truth.

If implementation cannot explain why a result was produced, the evaluation logic is too weak.

---

## Audit-Required Gate Mapping

The first-pass workflow should treat these audit requirements as explicit defaults:

- planning progression may require `research` or `planning` audit where the workflow or operator posture says BYDA is in scope
- implementation preparation or implementation tracking requires `implementation_readiness` audit for governed implementation-facing work
- implementation-tracking confidence requires `code_alignment` audit where GitHub or code-linked evidence is in scope
- handoff progression requires `handoff` audit for governed handoff paths
- `hygiene` audit is normally advisory unless governance posture explicitly elevates it for a specific surface

These defaults may be tightened later, but implementation should not invent the mapping ad hoc.

---

## Audit-Readiness Coupling

Readiness and BYDA audit are separate records, but they are not independent in practice.

### Core coupling rule

Where a lifecycle stage or workflow gate requires audit, readiness should not ignore audit state.

### First-pass coupling posture

The first pass should treat audit coupling like this:

- `research` and `planning` audits may materially strengthen or weaken readiness for planning progression
- `implementation_readiness` audit should be treated as a strong gate before implementation preparation or implementation tracking
- `code_alignment` audit should materially affect implementation-tracking confidence where GitHub or code-linked evidence is in scope
- `handoff` audit should materially affect readiness for handoff progression
- `hygiene` audit normally influences governance confidence and ambiguity handling rather than acting as a standalone progression gate by default

### Failure coupling

If a required audit returns `fail`, readiness should normally return `not_ready` or require re-evaluation before forward progression.

### Warning coupling

If a required audit returns `warning`, readiness may still become `ready_with_warnings` only when the unresolved audit findings are non-blocking and remain explicit.

### Staleness coupling

If a required audit becomes `stale`, prior readiness confidence should not be treated as current.
A stale required audit should normally force re-audit and readiness re-evaluation before forward progression.

---

## Evaluation Inputs

A first-pass readiness evaluation should consider, where applicable:

- evaluated entity type and identity
- project scope
- structural completeness of the evaluated record
- required linked records
- evidence sufficiency
- dependency visibility
- blocker state
- target-system or handoff clarity
- explicit workflow rules for the evaluation type
- current required audit state where applicable

---

## Result Set

Allowed readiness results are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

First-pass values:

- `ready`
- `not_ready`
- `ready_with_warnings`
- `deferred`

---

## First-Pass Rule Order

Evaluate in this order:

### 1. Scope validity
If the evaluated entity is missing, invalid, or out of project scope, fail the request rather than returning a readiness result.

### 2. Deferred condition
If the evaluated record is intentionally deferred by governed workflow state, the result is `deferred`.

### 3. Hard-block condition
If any critical blocking rule fails, the result is `not_ready`.

### 4. Warning condition
If no hard-block rule fails, but one or more advisory-only rules fail, the result is `ready_with_warnings`.

### 5. Ready condition
If no hard-block rule fails and no warning rule fails, the result is `ready`.

---

## Hard-Block Rules

A first-pass evaluation should return `not_ready` when any applicable hard-block rule is true.

### Goal clarity block
Return `not_ready` if the evaluated record lacks an explicit actionable purpose.

Examples:

- missing or empty required title-like field
- planning scope too ambiguous to act on

### Structural completeness block
Return `not_ready` if required structural fields or required same-project links are missing.

Examples:

- required parent context missing for intended workflow stage
- required target-system classification missing for handoff-oriented work

### Evidence sufficiency block
Return `not_ready` if required evidence or rationale is missing for the claimed planning move.

Examples:

- no supporting evidence where evidence is required
- no recoverable rationale for a materially important decision

### Dependency visibility block
Return `not_ready` if critical dependencies are unresolved or still unknown in a way that prevents safe progression.

Examples:

- known blocking dependency still active
- dependency state unknown for a required upstream item

### Audit gate block
Return `not_ready` if a required BYDA audit is missing, failing, or stale for the current lifecycle gate.

Examples:

- implementation-readiness audit is required but not current
- required handoff audit is failing
- code-alignment audit became stale after material linkage change

### Boundary correctness block
Return `not_ready` if the record is misclassified across Project V / VEDA / V Forge boundaries.

Examples:

- execution-owned truth being treated as Project V planning truth
- observatory-owned truth being treated as Project V canonical truth

### Handoff readiness block
Return `not_ready` for a handoff-oriented evaluation if the target system, work package basis, or blocking conditions remain materially unresolved.

---

## Warning Rules

A first-pass evaluation should return `ready_with_warnings` only when:

- no hard-block rule is true
- one or more warning conditions are true
- operator review is still required before proceeding where the workflow says so

Examples of warning conditions:

- minor documentation incompleteness that does not prevent action
- advisory evidence weakness that does not undermine the core decision basis
- non-blocking improvement suggestion still unresolved
- advisory readiness gaps with severity `advisory`
- required audit is current but contains non-blocking warning-level findings

## Operator Approval Recording for `ready_with_warnings`

When the workflow requires explicit operator approval to proceed from a `ready_with_warnings` result, that approval must be recorded.

### First-pass mechanism

Operator approval is recorded by creating a `DecisionRecord` in the same project with:

- `entityType` = the type of the evaluated entity (e.g. `work_item`, `initiative`)
- `entityId` = the id of the evaluated entity
- `title` = a brief description of the approval action
- `decisionSummary` = confirmation that the operator reviewed the warnings and accepted them
- `rationale` = explanation of why the unresolved warnings are acceptable for forward progression
- `status` = `recorded`
- `actor` = the operator or system identity approving the progression

This makes the approval explicit, recoverable, and linked to the evaluated entity.

### What approval is not

Operator approval must not be:

- a silent no-op where the workflow simply continues after `ready_with_warnings` is returned
- an implicit assumption that the operator will review later
- a field on `ReadinessEvaluation` itself (readiness evaluation records are immutable after creation)

### Hammer expectation

The hammer suite should verify that a `ready_with_warnings` result that is expected to require explicit approval does in fact have a linked `DecisionRecord` before forward progression is allowed.

---

## Deferred Rules

Return `deferred` only when one of these exact conditions is true.

### Condition 1: The governing project is deferred

If `Project.status == 'deferred'` for the project that owns the evaluated entity, the readiness result is `deferred`.

Rationale: a deferred project is intentionally not progressing. Evaluating readiness against a deferred project's records would produce misleading results.

### Condition 2: The evaluation request includes an explicit defer intent

If the caller supplies an explicit `deferWithReason` parameter (non-empty string) when requesting a readiness evaluation, the server should return `deferred` and preserve the supplied reason in the evaluation summary.

This keeps deferral an operator-initiated action rather than a server-inferred guess.

### What `deferred` is not

`deferred` must not be returned because:

- the evaluated entity's status happens to be `blocked` or `proposed`
- evaluation logic could not determine a result
- the evaluation basis was missing (those are `not_ready` conditions, not `deferred`)

`deferred` is not a euphemism for unknown or poorly evaluated.

### First-pass implementation note

No first-pass planning entity (Objective, Initiative, WorkItem, Handoff) has a `deferred` status value. The `deferred` readiness result is therefore reachable only through Condition 1 or Condition 2 above. Implementation must not invent additional deferred-state detection logic beyond these two conditions.

---

## Gap Creation Rules

When a readiness evaluation identifies one or more failed conditions, the system should create `ReadinessGap` rows where the methodology requires them.

First-pass posture:

- hard-block failures should normally create at least one gap
- advisory failures may create advisory gaps
- gap severity should align with the governing severity vocabulary

---

## Warning Severity Rule

`ready_with_warnings` may proceed only when all unresolved gaps are advisory or otherwise explicitly classified as non-blocking by the governed evaluation rules.

If any gap is `critical` or materially `major` in a blocking sense, the result should not be `ready_with_warnings`.

---

## Re-Evaluation Trigger Rule

Readiness must be re-evaluated when its basis changes materially.

First-pass triggers include:

- a required audit becomes `stale`
- a required audit changes from `warning` to `fail`
- a superseding decision changes scope or sequencing materially
- a material implementation-linkage or GitHub-linkage change invalidates the prior basis

---

## Work Item Sync Rule

When a readiness evaluation is created for a `WorkItem`, the system should update the work item''s server-managed `readinessState` in the same transaction.

If the current basis becomes invalid later because of a required stale audit or another material invalidation trigger, the work item''s `readinessState` should be reset to `unevaluated` until a new readiness evaluation is recorded.

## Explainability Rule

Every readiness result should remain explainable through recoverable fields such as:

- evaluation type
- rule package
- summary
- created gaps
- related evidence or rationale context where applicable
- relevant audit state where applicable

The first-pass system does not need a giant reasoning trace, but it must preserve enough basis to justify the result.

---

## Implementation Rule

The first-pass implementation may use straightforward rule checks rather than an advanced policy engine.

That is acceptable only if:

- the checks are explicit
- the order is stable
- the outputs are deterministic
- the gaps are created consistently
- the result is server-owned

Do not hide temporary readiness logic in ad hoc route code without aligning it to this document.

---

## Hammer Expectations

The hammer suite should verify at least:

- caller-supplied result cannot override server-owned evaluation result
- hard-block conditions produce `not_ready`
- advisory-only failures can produce `ready_with_warnings`
- deferred conditions produce `deferred`
- identical inputs produce identical results
- required audit failures constrain readiness correctly
- stale required audits force re-evaluation correctly
- required gaps are created consistently

---

## Final Rule

Readiness evaluation in Project V must be explicit enough to implement and strict enough to resist improvisation.

If the route builder still has to invent the actual result logic, the docs are not done.


