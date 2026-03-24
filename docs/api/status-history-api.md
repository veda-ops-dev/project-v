# Status History API

## Status

**DEFERRED — read surface not part of the first-pass active API surface.**

This document records the intended design for the Project V `status-history` read endpoint family for future implementation.

It must not be treated as an active API contract until it is explicitly promoted through governance.

See:
- `docs/api/endpoint-governance.md` — Explicitly Deferred Endpoint Families
- `docs/architecture/data/controlled-vocabularies.md` — Status History Read Surface

---

## Purpose

This document defines the future Project V `status-history` read endpoint family.

It exists to answer:

```text
How is recoverable project-scoped status history listed and retrieved without weakening state/history alignment rules?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/status-transitions.md`

---

## First-Pass Deferral

In the first pass, `StatusHistory` is **write-only from the API surface**.

- StatusHistory records are written atomically as a side effect of governed status transitions (project, objective, initiative, work item, handoff, decision record).
- No read routes are exposed to callers in the first pass.
- This is an explicit documented gap. If transition audit trail inspection becomes a workflow requirement, a read surface must be added through governance.

The schema supports read access. The first-pass API surface does not expose it.

---

## Family Scope (Future)

This family will manage read access to project-scoped StatusHistory records.

Status history is created exclusively as a side effect of governed status transitions. There is no general-purpose public create route in the first pass or in the planned future surface.

---

## Write Posture

### No generic public create route

Status history is written by governed mutation paths:

- project status transitions
- objective status transitions
- initiative status transitions
- work-item status transitions
- handoff status transitions
- decision-record status transitions

This is not relaxed in a future read surface. A public write route for status history must not be added without an explicit governance decision.

### No generic update route

Status history is append-only. If a history entry is wrong, the fix must occur through explicit corrective action, not rewriting the original record.

---

## Planned Route Family (Future)

### `GET /api/projects/:projectId/status-history`
List status-history entries for one project.

### `GET /api/projects/:projectId/status-history/:statusHistoryId`
Get one status-history entry.

No `POST`, `PATCH`, or delete routes in any pass.

---

## Scope Rules (Future)

- every route is project-scoped
- `statusHistoryId` alone must not bypass project ownership rules
- history entries must correspond to entities in the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/status-history` (Future)

### Query parameters
Allowed filters:

- `entityType`
- `entityId`
- `newStatus`
- `actor`
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
- `entityType`
- `entityId`
- `previousStatus`
- `newStatus`
- `reason`
- `actor`
- `createdAt`

---

## `GET /api/projects/:projectId/status-history/:statusHistoryId` (Future)

### Failure posture
- `404` if the status-history entry does not belong to the project or does not exist
- `400` for malformed identifiers

---

## Error Posture (Future)

- `400 Bad Request` for malformed input or unrecognized query parameters
- `404 Not Found` for missing or out-of-scope records

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations (Future)

This family must be hammered before activation for:

- project-scope enforcement
- deterministic listing
- append-only posture verification
- state/history alignment through transition routes
- invalid cross-project history lookup rejection

---

## Final Rule

The Status History API is a recoverability surface, not a freeform event-writing surface.
If history can be fabricated independently of governed transitions, the design is too weak.
