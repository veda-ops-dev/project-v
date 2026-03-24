# Decision Records API

## Purpose

This document defines the Project V `decision-records` endpoint family.

It exists to answer:

```text
How are project-scoped decision records listed, retrieved, and created so important planning decisions remain recoverable instead of disappearing into prose?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/core/project-v-operational-workflow.md`

---

## Family Scope

This family manages project-scoped DecisionRecord records.

Decision records exist to preserve significant planning and orchestration decisions.
They are not generic notes.

---

## Route Family

### `GET /api/projects/:projectId/decision-records`
List decision records for one project.

### `GET /api/projects/:projectId/decision-records/:decisionRecordId`
Get one decision record.

### `POST /api/projects/:projectId/decision-records`
Create a decision record.

### `PATCH /api/projects/:projectId/decision-records/:decisionRecordId`
Update bounded mutable decision-record fields if lifecycle status management is needed.

No delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `decisionRecordId` alone must not bypass project ownership rules
- related entity references, when present, must belong to the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/decision-records`

### Query parameters
Allowed first-pass filters:

- `entityType`
- `entityId`
- `status`
- `actor`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
createdAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `entityType`
- `entityId`
- `title`
- `decisionSummary`
- `rationale`
- `status`
- `actor`
- `createdAt`

---

## `GET /api/projects/:projectId/decision-records/:decisionRecordId`

### Failure posture
- `404` if the decision record does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/decision-records`

### Required input
- `title`
- `decisionSummary`
- `rationale`
- `status`
- `actor`

### Optional input
- `entityType`
- `entityId`

### Validation
- `title` must be non-empty
- `decisionSummary` must be non-empty
- `rationale` must be non-empty
- `status` must use controlled vocabulary
- if `entityType` and `entityId` are supplied, the referenced entity must belong to the same project

### Response
- `201 Created` with canonical decision record

---

## `PATCH /api/projects/:projectId/decision-records/:decisionRecordId`

### Allowed mutable fields in the first pass
- `status`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- rewriting `decisionSummary` or `rationale` silently after record creation
- reassigning the related entity to another record through generic patch

Attempting to supply a forbidden field in a PATCH body must fail with `400 Bad Request`.

### Validation
- `status` must use controlled vocabulary (`recorded`, `superseded`)
- only the `recorded -> superseded` transition is allowed; all other transitions must fail deterministically
- the `recorded -> superseded` transition requires a non-empty `reason` field in the PATCH body; omitting it must fail with `400 Bad Request`
- the status change and the required `StatusHistory` row must be written atomically in the same transaction (see Transaction Boundary Rule in `docs/api/api-conventions.md`)
- the `actor` field for the resulting `StatusHistory` row is server-resolved from the authenticated request context; callers must not supply it (see Actor Rule in `docs/api/api-conventions.md`)

### Response
- `200 OK` with updated canonical decision record

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input, missing required fields, forbidden fields in PATCH body, or missing `reason` on governed transition
- `404 Not Found` for missing project or decision record
- `422 Unprocessable Entity` for controlled-vocabulary violations, illegal status transitions, or same-project integrity failures

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- same-project related-entity enforcement
- deterministic listing
- non-empty rationale enforcement
- invalid related-entity rejection
- illegal status transition rejection
- missing `reason` rejection on `recorded -> superseded` transition
- status/history alignment on governed transition

---

## Final Rule

The Decision Records API must keep important planning decisions explicit and recoverable.
If the system can make meaningful decisions without leaving a governed record where required, the surface is too weak.


