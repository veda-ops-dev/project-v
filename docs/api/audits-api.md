# Audits API

## Status

**DEFERRED — not part of the first-pass active API surface.**

This document records the intended design for the Project V `audits` endpoint family for future implementation.

It must not be treated as an active API contract until it is explicitly promoted through governance.

See:
- `docs/api/endpoint-governance.md` — Explicitly Deferred Endpoint Families
- `docs/architecture/data/controlled-vocabularies.md` — Audit Run and Audit Gap API Surface

---

## Purpose

This document defines the future Project V `audits` endpoint family.

It exists to answer:

```text
How are project-scoped audit runs and audit gaps listed, retrieved, created, and updated without reducing BYDA-style audit to opaque magic or collapsing audit into readiness?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/core/byda-in-project-v.md`
- `docs/architecture/core/audit-evaluation-rules.md`
- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/architecture/data/audit-and-gap-model.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/status-transitions.md`

---

## First-Pass Deferral

In the first pass, `AuditRun` and `AuditGap` have **no direct caller API surface**.

- `AuditRun` and `AuditGap` records may only be created through internal server-side audit execution logic.
- No read, create, or update routes are exposed to callers in the first pass.
- This is an explicit documented gap, not an oversight.

When the audit API surface is promoted in a later pass, the design below should be reviewed, governed, and hammered before activation.

---

## Family Scope (Future)

This family will manage project-scoped `AuditRun` and `AuditGap` records.

Audit records are distinct from readiness records.

This family will exist to preserve:

- audit type explicitness
- target explicitness
- result explicitness
- gap explicitness
- explainability
- deterministic project scope enforcement

It must not silently collapse audit into readiness or vice versa.

---

## Planned Route Family (Future)

### `GET /api/projects/:projectId/audits`
List audit runs for one project.

### `GET /api/projects/:projectId/audits/:auditId`
Get one audit run.

### `POST /api/projects/:projectId/audits`
Create and execute a new audit run.

### `PATCH /api/projects/:projectId/audits/:auditId`
Apply bounded governed audit-run updates where the contract explicitly allows them.

### `GET /api/projects/:projectId/audit-gaps`
List audit gaps for one project.

### `GET /api/projects/:projectId/audit-gaps/:auditGapId`
Get one audit gap.

### `PATCH /api/projects/:projectId/audit-gaps/:auditGapId`
Update bounded mutable audit-gap fields.

No generic delete routes in the first pass.

---

## Scope Rules (Future)

- every route is project-scoped
- `auditId` alone must not bypass project ownership rules
- `auditGapId` alone must not bypass project ownership rules
- audit targets, where present, must belong to the same project
- cross-project existence leakage is forbidden by default
- audit gaps must belong to audit runs in the same project

---

## `GET /api/projects/:projectId/audits` (Future)

### Query parameters
Allowed filters:

- `auditType`
- `result`
- `targetEntityType`
- `targetEntityId`
- `limit`
- `cursor`

### Ordering

```text
createdAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `auditType`
- `targetEntityType`
- `targetEntityId`
- `result`
- `summary`
- `startedAt`
- `completedAt`
- `createdAt`

---

## `GET /api/projects/:projectId/audits/:auditId` (Future)

### Failure posture
- `404` if the audit run does not belong to the project or does not exist
- `400` for malformed identifiers

### Response notes
The response should preserve enough detail to explain what was audited, what result was produced, and what gaps exist.

---

## `POST /api/projects/:projectId/audits` (Future)

### Required input
- `auditType`

### Optional input
- `targetEntityType`
- `targetEntityId`

### Validation
- `auditType` must use controlled vocabulary
- if `targetEntityType` and `targetEntityId` are supplied, the target must belong to the same project
- audit requests without sufficient basis must fail deterministically
- caller input must not directly set canonical `result`
- caller input must not directly fabricate audit gaps

### Mutation rule
Creating an audit should execute the governed audit logic and produce canonical `result`, canonical `summary`, and audit gaps where required. This behavior must remain explicit and atomic.

### Response
- `201 Created` with canonical audit record and generated gaps

---

## `PATCH /api/projects/:projectId/audits/:auditId` (Future)

### Allowed mutable fields
- `result` only where the governed path is explicitly invalidating a prior audit into `stale`
- `completedAt` only where the audit execution flow requires completion stamping
- `summary` only where the audit execution flow finalizes through a governed path

### Forbidden mutations
- changing `projectId`
- changing canonical `id`
- changing `auditType`
- changing target identity through generic patch
- rewriting `pass` / `fail` / `warning` casually through generic operator patch
- fabricating an audit result disconnected from governed audit rules

---

## `GET /api/projects/:projectId/audit-gaps` (Future)

### Query parameters
Allowed filters:

- `auditRunId`
- `severity`
- `status`
- `limit`
- `cursor`

### Ordering

```text
status asc, severity_rank desc, createdAt desc, id asc
```

where `severity_rank`: `critical = 4`, `major = 3`, `minor = 2`, `advisory = 1`.

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `auditRunId`
- `severity`
- `description`
- `remediation`
- `status`
- `createdAt`
- `updatedAt`

---

## `PATCH /api/projects/:projectId/audit-gaps/:auditGapId` (Future)

### Allowed mutable fields
- `status`
- `remediation`

### Forbidden mutations
- changing `projectId`
- changing canonical `id`
- reassigning the gap to another audit run
- rewriting the original deficiency description after creation

### Validation
- `status` must use controlled vocabulary
- status transitions must follow governed status-transition rules

---

## Controlled Vocabularies

Governed by `docs/architecture/data/controlled-vocabularies.md`:

- audit type
- audit result
- audit gap severity
- audit gap status

---

## Relationship to Readiness

Audit records and readiness records remain separate.

Required audit failures should constrain readiness. Required stale audits should invalidate prior readiness confidence. Readiness should not pretend required audit state does not exist.

That coupling is governed by `docs/architecture/core/readiness-evaluation-rules.md`.

---

## Error Posture (Future)

- `400 Bad Request` for malformed input
- `404 Not Found` for missing or out-of-scope records
- `409 Conflict` for governed write conflicts with current state
- `422 Unprocessable Entity` for semantically invalid but well-formed audit requests

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations (Future)

This family must be hammered before activation for:

- project-scope enforcement
- same-project target enforcement
- deterministic listing
- invalid audit-type rejection
- server-owned audit result generation
- required audit-gap creation where appropriate
- stale invalidation behavior

---

## Final Rule

The Audits API must make BYDA explicit, inspectable, and governable.

If audit results can be fabricated casually, if gaps disappear into prose, or if audit silently collapses into readiness, the design is wrong.
