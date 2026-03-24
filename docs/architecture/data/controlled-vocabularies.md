# Controlled Vocabularies

## Purpose

This document defines the canonical first-pass controlled vocabularies for Project V.

It exists to answer:

```text
What enum-like values are officially allowed across Project V schema, APIs, workflow, and hammer expectations?
```

This document is the canonical registry for first-pass controlled vocabularies.

If another doc lists values that conflict with this registry, this registry wins until the conflict is resolved explicitly.

---

## Read This With

- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/status-transitions.md`
- `docs/architecture/data/polymorphic-reference-enforcement.md`
- `docs/architecture/core/readiness-methodology.md`
- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/api/api-conventions.md`

---

## Core Rule

Controlled vocabulary values must not drift across docs, routes, schema, and implementation.

A developer or LLM should not need to reconstruct canonical values by reading six different files.

This file is the source of truth for first-pass vocabulary values.

---

## Project Status

Allowed values:

- `active`
- `deferred`
- `archived`

### Meaning
- `active` = project is operationally active in Project V
- `deferred` = project remains known but is intentionally not progressing right now
- `archived` = project is closed to normal active workflow and retained for historical/reference reasons

---

## Objective Status

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

---

## Initiative Status

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

---

## Work Item Status

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

---

## Work Item Type

Allowed values:

- `analysis`
- `planning`
- `specification`
- `handoff-preparation`
- `governance`

---

## Work Item Readiness State

Allowed values:

- `unevaluated`
- `not_ready`
- `ready_with_warnings`
- `ready`
- `deferred`

### Notes
This field reflects the current planning readiness state of the work item.
It should remain aligned with readiness evaluation outcomes according to governed workflow rules.

---

## Initiative Target System

Allowed values:

- `project_v`
- `veda`
- `v_forge`

---

## Work Item Target System

Allowed values:

- `project_v`
- `veda`
- `v_forge`

---

## Priority

The `priority` field on `Objective` and `Initiative` uses a governed numeric range.

Allowed range: `1..1000`

Default value: `100`

Semantic: lower values represent higher priority. A priority of `1` is the highest priority; a priority of `1000` is the lowest. List surfaces ordering by `priority asc` will show highest-priority records first.

An out-of-range value supplied at creation or PATCH must fail with `422 Unprocessable Entity`.

---

## Dependency Type

Allowed values:

- `blocks`
- `requires`
- `relates_to`

### Notes
Keep the first-pass dependency language intentionally small.
Do not grow a taxonomy blob before there is real pressure to do so.

---

## Dependency Status

Allowed values:

- `active`
- `resolved`

### Notes
The expected first-pass initial status for a newly created dependency is `active`.

---

## Dependency Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

---

## Decision Record Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

---

## Decision Record Status

Allowed values:

- `recorded`
- `superseded`

---

## Research Doc Source Type

Allowed values:

- `manual`
- `imported`
- `veda_reference`
- `external_reference`

---

## Research Doc Status

Allowed values:

- `active`
- `archived`

---

## Evidence Link Source Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`
- `handoff`
- `decision_record`
- `research_doc`

---

## Evidence Link Type

Allowed values:

- `document`
- `observation`
- `decision_basis`
- `external_reference`

---

## Readiness Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

---

## Readiness Evaluation Type

Allowed values:

- `research`
- `planning`
- `implementation_readiness`
- `code_alignment`
- `handoff`
- `hygiene`

### Intentional shared vocabulary note
Readiness Evaluation Type and Audit Type use the same controlled vocabulary values intentionally.

This does not make them the same thing. `ReadinessEvaluation` and `AuditRun` are separate record families that answer different questions. Readiness asks whether something may move forward. Audit asks what was checked, what failed, what gaps exist, and whether confidence has gone stale.

The shared vocabulary exists because the lifecycle dimensions that drive readiness evaluation and BYDA audit are the same: research, planning, implementation readiness, code alignment, handoff, hygiene. The names align so that readiness-audit coupling is unambiguous.

---

## Readiness Evaluation Result

Allowed values:

- `ready`
- `not_ready`
- `ready_with_warnings`
- `deferred`

---

## Readiness Gap Severity

Allowed values:

- `critical`
- `major`
- `minor`
- `advisory`

### Meaning
- `critical` = blocks forward motion
- `major` = materially weakens readiness and usually blocks progress until resolved
- `minor` = does not block alone but should be addressed
- `advisory` = visible caution; may proceed if workflow rules allow

### Severity rank for ordering
When list surfaces order by severity, they must use numeric rank, not raw text sort. Canonical rank:
- `critical` = 4 (highest)
- `major` = 3
- `minor` = 2
- `advisory` = 1 (lowest)

Ordering by `severity desc` means critical first, advisory last. Raw alphabetical sort on these values produces incorrect ordering and must not be used.

---

## Handoff Source Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`

---

## Handoff Target System

Allowed values:

- `project_v`
- `veda`
- `v_forge`

---

## Handoff Type

Allowed values:

- `execution`
- `analysis`
- `governance`
- `review`

---

## Handoff Status

Allowed values:

- `proposed`
- `ready`
- `handed_off`
- `accepted`
- `closed`

---

## Audit Type

Allowed values:

- `research`
- `planning`
- `implementation_readiness`
- `code_alignment`
- `handoff`
- `hygiene`

---

## Audit Result

Allowed values:

- `pass`
- `fail`
- `warning`
- `stale`

---

## Audit Gap Severity

Allowed values:

- `critical`
- `major`
- `minor`
- `advisory`

### Severity rank for ordering
Same rank mapping as Readiness Gap Severity: `critical` = 4, `major` = 3, `minor` = 2, `advisory` = 1.

---

## Audit Gap Status

Allowed values:

- `open`
- `resolved`
- `invalidated`

---

## GitHub Link Source Entity Type

Allowed values:

- `objective`
- `initiative`
- `work_item`
- `handoff`
- `decision_record`
- `research_doc`
- `audit_run`

---

## GitHub Link Type

Allowed values:

- `repository`
- `branch`
- `pull_request`
- `commit`
- `issue`

---

## Status History Entity Type

Allowed values:

- `project`
- `objective`
- `initiative`
- `work_item`
- `handoff`
- `decision_record`
- `audit_run`

### Notes
`decision_record` is included because the governed `recorded -> superseded` transition must write a `StatusHistory` row in the same transaction.

`audit_run` is included because the governed staleness transition (`pass/fail/warning -> stale`) may write a `StatusHistory` row when the staleness path is explicitly triggered through the governed invalidation mechanism. This keeps the invalidation event recoverable alongside the audit result change.

---

## Actor / Origin Guidance

Actor-like fields remain free text in the first pass, but they should follow a stable convention where practical.

Recommended shapes:

- human operator identifier
- system identifier
- workflow identifier

This is guidance, not yet a controlled vocabulary.

---

## Vocabulary Change Rule

A controlled vocabulary change is a governed architectural change.

When a value is added, removed, or renamed:

- update this registry first
- update schema specification if affected
- update API contracts if affected
- update workflow/readiness docs if affected
- update hammer expectations if affected

Do not silently extend controlled values in implementation first.

---

## Rule Package Vocabulary

The `rulePackage` field on `ReadinessEvaluation` identifies the set of evaluation rules applied.

In the first pass, the canonical rule packages map one-to-one with evaluation types:

- `evaluationType = research` → default `rulePackage = standard_research_v1`
- `evaluationType = planning` → default `rulePackage = standard_planning_v1`
- `evaluationType = implementation_readiness` → default `rulePackage = standard_impl_readiness_v1`
- `evaluationType = code_alignment` → default `rulePackage = standard_code_alignment_v1`
- `evaluationType = handoff` → default `rulePackage = standard_handoff_v1`
- `evaluationType = hygiene` → default `rulePackage = standard_hygiene_v1`

A caller may supply an explicit `rulePackage` value to override the default for a given `evaluationType`. If an unknown or incompatible `rulePackage` value is supplied, the request must fail with `422 Unprocessable Entity`.

The full rules for each package are defined in `docs/architecture/core/readiness-evaluation-rules.md`.

---

## Status History Read Surface

`StatusHistory` records are written atomically with governed status transitions across Project V entities. In the first pass, `StatusHistory` is **write-only from the API surface**. There is no first-pass list or detail read endpoint for status history.

This is an explicit documented gap. If transition audit trail inspection becomes a workflow requirement, a read surface must be added through governance. The schema supports it; the API surface does not expose it yet.

---

## Audit Run and Audit Gap API Surface

`AuditRun` and `AuditGap` tables are fully defined in the schema specification. In the first pass, there is **no dedicated API endpoint family** for these tables.

This is an explicit documented gap. Audit execution and gap inspection are expected to be added as a governed endpoint family in a later pass. Until then:
- `AuditRun` and `AuditGap` records may only be created through internal server-side audit execution logic
- No direct caller mutation or read surface is exposed

---

## Final Rule

The first-pass Project V vocabulary should remain small, explicit, and boring.

If a new value is not clearly needed, do not add it.


