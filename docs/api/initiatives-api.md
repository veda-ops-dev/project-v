# Initiatives API

## Purpose

This document defines the Project V `initiatives` endpoint family.

It exists to answer:

```text
How are project-scoped initiatives listed, retrieved, created, and updated while preserving explicit project scope and optional objective linkage?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Family Scope

This family manages project-scoped Initiative records.

Initiatives are always project-scoped.
An initiative may optionally reference an Objective in the same project.

---

## Route Family

### `GET /api/projects/:projectId/initiatives`
List initiatives for one project.

### `GET /api/projects/:projectId/initiatives/:initiativeId`
Get one initiative inside one project.

### `POST /api/projects/:projectId/initiatives`
Create an initiative inside one project.

### `PATCH /api/projects/:projectId/initiatives/:initiativeId`
Update bounded mutable initiative fields.

### `POST /api/projects/:projectId/initiatives/:initiativeId/status`
Execute an explicit status transition for an initiative.

No delete route exists in the first pass.

---

## Scope Rules

- every read and write is project-scoped
- `initiativeId` alone must not bypass project ownership rules
- `objectiveId`, when present, must belong to the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/initiatives`

### Query parameters
Allowed first-pass filters:

- `status`
- `priority`
- `objectiveId`
- `targetSystem`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
priority asc, updatedAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `objectiveId`
- `key`
- `title`
- `description`
- `status`
- `priority`
- `targetSystem`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/initiatives/:initiativeId`

### Failure posture
- `404` if the initiative does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/initiatives`

### Required input
- `key`
- `title`

### Optional input
- `description`
- `objectiveId`
- `priority`
- `targetSystem`

### Initial status
The server assigns `status = proposed` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Validation
- `projectId` must reference a real project and must not be archived; creation under an archived project must fail with `422 Unprocessable Entity`
- `key` must be unique within the project
- `objectiveId`, if supplied, must belong to the same project and must not be archived; linking to an archived objective must fail with `422 Unprocessable Entity`
- `targetSystem` must use controlled vocabulary (`project_v`, `veda`, `v_forge`)
- `title` must be non-empty

### Response
- `201 Created` with canonical initiative record

---

## `PATCH /api/projects/:projectId/initiatives/:initiativeId`

### Allowed mutable fields
- `title`
- `description`
- `objectiveId`
- `priority`
- `targetSystem`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- linking to an objective in another project
- re-parenting to an archived objective; this must fail with `422 Unprocessable Entity`
- silent status transition through a generic patch if explicit status routes are used

Attempting to supply a forbidden field in a PATCH body must fail with `400 Bad Request`.

### Response
- `200 OK` with updated canonical initiative record

---

## `POST /api/projects/:projectId/initiatives/:initiativeId/status`

### Required input
- `newStatus`
- `reason` — required for the following transitions: `active -> archived`, `blocked -> archived`, `proposed -> archived`. Optional for all other allowed transitions.

### Validation
- `newStatus` must use controlled vocabulary (`proposed`, `active`, `blocked`, `completed`, `archived`)
- only transitions defined as allowed in `docs/architecture/data/status-transitions.md` are accepted; all others must fail deterministically with `422 Unprocessable Entity`
- `reason` must be non-empty when required for the transition; a missing or empty reason on a required-reason transition must fail with `400 Bad Request`
- all initiative status transitions must write a `StatusHistory` row atomically in the same transaction

### Response
- `200 OK` with updated initiative record and status-history confirmation fields

---

## Status Vocabulary

Allowed values (canonical):

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input
- `404 Not Found` for missing project or initiative
- `409 Conflict` for duplicate `key` within the project
- `422 Unprocessable Entity` for semantically invalid but well-formed input

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- per-project key uniqueness
- duplicate key rejection (409)
- same-project objective enforcement
- deterministic listing
- invalid target-system rejection
- illegal status transition rejection (all forbidden transitions fail with `422`)
- missing required `reason` rejection for archival transitions
- `StatusHistory` row written for every status transition

---

## Final Rule

The Initiatives API is project-scoped and must preserve same-project integrity for all links and mutations.
