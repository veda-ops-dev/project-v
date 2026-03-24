# Status Transitions

## Purpose

This document defines the first-pass legal status transitions for Project V records that use explicit status routes.

It exists to answer:

```text
Which status transitions are allowed, which are forbidden, and what rules govern transition behavior?
```

Read this with:

- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/api/objectives-api.md`
- `docs/api/initiatives-api.md`
- `docs/api/work-items-api.md`
- `docs/api/handoffs-api.md`

---

## Core Rule

If an API contract says illegal status transitions must fail, those legal transitions must be defined here.

Implementation must not invent transition rules ad hoc.

---

## Transition Rule Types

For the first pass, transitions fall into three categories:

- **allowed**
- **allowed with explicit reason**
- **forbidden**

Each entity-type section below defines explicitly whether status history is required for
that entity's transitions. Refer to the per-entity StatusHistory requirement sections
rather than inferring from this preamble.

---

## Project Status Transitions

Allowed values:

- `active`
- `deferred`
- `archived`

### Allowed transitions
- `active -> deferred`
- `deferred -> active`
- `active -> archived` with explicit reason
- `deferred -> archived` with explicit reason

### Forbidden transitions
- `archived -> active`
- `archived -> deferred`

### StatusHistory requirement

All project status transitions must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `project` for these rows.

The `StatusHistory.reason` field should be populated from the transition `reason` where one
is supplied. For transitions that require an explicit reason, the history row must also carry
that reason. For transitions where reason is optional, the history row carries the reason if
supplied and leaves it null if not.

This requirement covers all transitions through the `/status` route. It does not apply to
the initial `status = active` assignment on creation.

### Notes
Archival is one-way in the first pass.

---

## Objective Status Transitions

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

### Allowed transitions
- `proposed -> active`
- `proposed -> blocked`
- `active -> blocked`
- `blocked -> active`
- `active -> completed`
- `completed -> archived`
- `blocked -> archived` with explicit reason
- `proposed -> archived` with explicit reason

### Forbidden transitions
- `completed -> active`
- `completed -> blocked`
- `archived -> proposed`
- `archived -> active`
- `archived -> blocked`
- `archived -> completed`

### StatusHistory requirement

All objective status transitions must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `objective` for these rows.

The `StatusHistory.reason` field should be populated from the transition `reason` where one
is supplied. For transitions that require an explicit reason, the history row must also carry
that reason. For transitions where reason is optional, the history row carries the reason if
supplied and leaves it null if not.

This requirement covers all transitions through the `/status` route. It does not apply to
the initial `status = proposed` assignment on creation.

### Notes
Direct `proposed -> completed` is forbidden in the first pass.

---

## Initiative Status Transitions

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

### Allowed transitions
- `proposed -> active`
- `proposed -> blocked`
- `active -> blocked`
- `blocked -> active`
- `active -> completed`
- `completed -> archived`
- `blocked -> archived` with explicit reason
- `proposed -> archived` with explicit reason

### Forbidden transitions
- `completed -> active`
- `completed -> blocked`
- `archived -> proposed`
- `archived -> active`
- `archived -> blocked`
- `archived -> completed`

### StatusHistory requirement

All initiative status transitions must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `initiative` for these rows.

The `StatusHistory.reason` field should be populated from the transition `reason` where one
is supplied. For transitions that require an explicit reason, the history row must also carry
that reason. For transitions where reason is optional, the history row carries the reason if
supplied and leaves it null if not.

This requirement covers all transitions through the `/status` route. It does not apply to
the initial `status = proposed` assignment on creation.

---

## Work Item Status Transitions

Allowed values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

### Allowed transitions
- `proposed -> active`
- `proposed -> blocked`
- `active -> blocked`
- `blocked -> active`
- `active -> completed`
- `completed -> archived`
- `blocked -> archived` with explicit reason
- `proposed -> archived` with explicit reason

### Forbidden transitions
- `completed -> active`
- `completed -> blocked`
- `archived -> proposed`
- `archived -> active`
- `archived -> blocked`
- `archived -> completed`
- `proposed -> completed`

### StatusHistory requirement

All work-item status transitions must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `work_item` for these rows.

The `StatusHistory.reason` field should be populated from the transition `reason` where one
is supplied. For transitions that require an explicit reason, the history row must also carry
that reason. For transitions where reason is optional, the history row carries the reason if
supplied and leaves it null if not.

This requirement covers all transitions through the `/status` route. It does not apply to
the initial `status = proposed` assignment on creation.

### Notes
The first pass prefers visible activation before completion.

---

## Handoff Status Transitions

Allowed values:

- `proposed`
- `ready`
- `handed_off`
- `accepted`
- `closed`

### Allowed transitions

#### Forward path
- `proposed -> ready`
- `ready -> handed_off`
- `handed_off -> accepted`
- `accepted -> closed`

#### Direct closure
- `proposed -> closed` with explicit reason
- `ready -> closed` with explicit reason
- `handed_off -> closed` with explicit reason

#### Reverse / re-entry path
- `handed_off -> ready` with explicit reason
- `handed_off -> proposed` with explicit reason

Reverse transitions are operator-initiated only. They exist to support the bounce-back
and rejection posture defined in `docs/architecture/integrations/v-forge-integration.md`.
They must not be used to silently reopen a handoff without a recoverable reason.

### Forbidden transitions
- `accepted -> handed_off`
- `accepted -> ready`
- `accepted -> proposed`
- `closed -> proposed`
- `closed -> ready`
- `closed -> handed_off`
- `closed -> accepted`
- `proposed -> accepted`
- `proposed -> handed_off`
- `ready -> proposed`
- `ready -> accepted`

### StatusHistory requirement

All handoff status transitions must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `handoff` for these rows. This is a governed value in the
controlled vocabulary.

The `StatusHistory.reason` field should be populated from the transition `reason` where one
is supplied. For transitions that require an explicit reason, the history row must also carry
that reason. For transitions where reason is optional, the history row carries the reason if
supplied and leaves it null if not.

`completedAt` on the `Handoff` record must be set to `now()` atomically in the same
transaction when the status transitions to `closed`. For all other transitions, `completedAt`
remains null.

### Notes
Handoff progression is normally forward and linear. Reverse re-entry transitions
(`handed_off -> ready`, `handed_off -> proposed`) are explicitly allowed but require an
explicit reason and must leave a recoverable `StatusHistory` row. Once a handoff reaches
`accepted` or `closed`, no reverse transition is allowed in the first pass.

The `accepted` state is a receiving-boundary acknowledgement. Once recorded, it cannot
be walked back; if circumstances change materially after acceptance, close the existing
handoff and create a new one.

---

## Decision Record Status Transitions

Allowed values:

- `recorded`
- `superseded`

### Allowed transitions
- `recorded -> superseded` with explicit reason

### Forbidden transitions
- `superseded -> recorded`

### StatusHistory requirement
The `recorded -> superseded` transition must write a `StatusHistory` row in the same transaction.

`StatusHistory.entityType` must be `decision_record` for these rows. This is a governed value in the controlled vocabulary.

### Notes
Decision records are intended to preserve decision history rather than bounce between statuses. Supersedence should be one-way in the first pass.

---

## Research Doc Status Transitions

Allowed values:

- `active`
- `archived`

### Allowed transitions
- `active -> archived` with explicit reason

### Forbidden transitions
- `archived -> active`

### Notes
Research-doc archival is one-way in the first pass.

The `active -> archived` transition requires an explicit non-empty `reason`. Although research-doc status is mutated through PATCH rather than a dedicated `/status` route (see `docs/api/research-docs-api.md`), the reason requirement is not waived. The PATCH handler must enforce it.

---

## Dependency Status Transitions

Allowed values:

- `active`
- `resolved`

### Allowed transitions
- `active -> resolved`

### Forbidden transitions
- `resolved -> active`

### Notes
The first pass treats dependency resolution as one-way. If reopening is needed later, it should be modeled explicitly.

---

## Audit Run Status Transitions

Allowed values:

- `pass`
- `fail`
- `warning`
- `stale`

### Allowed transitions
- `pass -> stale` with explicit reason
- `fail -> stale` with explicit reason
- `warning -> stale` with explicit reason

### Forbidden transitions
- `stale -> pass`
- `stale -> fail`
- `stale -> warning`

### StatusHistory requirement
The staleness transitions (`pass -> stale`, `fail -> stale`, `warning -> stale`) must write a `StatusHistory` row in the same transaction when the staleness path is explicitly triggered through the governed invalidation mechanism.

`StatusHistory.entityType` must be `audit_run` for these rows. This is a governed value in the controlled vocabulary.

Note: audit results set during initial audit execution (the server computing `pass`, `fail`, or `warning` as part of running the audit) are not status transitions in the same sense and do not require a `StatusHistory` row. Only the post-execution staleness transition requires one.

### Notes
Audit results are normally set by audit execution rather than casual mutation. Staleness through a governed invalidation path is the main explicit post-result transition in the first pass.

---

## Audit Gap Status Transitions

Allowed values:

- `open`
- `resolved`
- `invalidated`

### Allowed transitions
- `open -> resolved`
- `open -> invalidated` with explicit reason
- `resolved -> invalidated` with explicit reason

### Forbidden transitions
- `invalidated -> open`
- `invalidated -> resolved`

---

## GitHub Link Handling Rule

`GitHubLink` does not use a governed lifecycle status in the first pass.

It should be created, updated in bounded ways, or superseded by new linkage records as needed rather than forced into an artificial status-transition model.

---

## Readiness Result Handling Rule

Readiness evaluation results are controlled vocabulary outputs, not generic status-transition records.

They should not be treated as mutable lifecycle statuses through the same explicit status-transition routes used for Objective, Initiative, WorkItem, Project, or Handoff.

---

## Transition Requirements

All transition routes must require:

- explicit target status
- explicit reason when the transition is marked as requiring one; missing or empty reason
  on a required-reason transition must fail with `400 Bad Request`
- deterministic rejection of forbidden transitions with `422 Unprocessable Entity`
- atomic status/history write for all entity types whose StatusHistory requirement section
  mandates history (currently: Project, Objective, Initiative, WorkItem, Handoff,
  DecisionRecord, AuditRun)

---

## Final Rule

Status transitions are governed behavior.

If a desired transition is not listed as allowed here, it should be treated as forbidden until explicitly added through governance.



