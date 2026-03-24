# Work Items API

## Purpose

This document defines the Project V `work-items` endpoint family.

It exists to answer:

```text
How are project-scoped work items listed, retrieved, created, updated, and status-transitioned without drifting into execution ownership?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Family Scope

This family manages project-scoped WorkItem records.

Work items are planning and execution-preparation records.
They do not become the canonical owner of execution truth.

---

## Route Family

### `GET /api/projects/:projectId/work-items`
List work items for one project.

### `GET /api/projects/:projectId/work-items/:workItemId`
Get one work item inside one project.

### `POST /api/projects/:projectId/work-items`
Create a work item inside one project.

### `PATCH /api/projects/:projectId/work-items/:workItemId`
Update bounded mutable work-item fields.

### `POST /api/projects/:projectId/work-items/:workItemId/status`
Execute an explicit status transition for a work item.

No delete route exists in the first pass.

---

## Scope Rules

- every read and write is project-scoped
- `workItemId` alone must not bypass project ownership rules
- `initiativeId`, when present, must belong to the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/work-items`

### Query parameters
Allowed first-pass filters:

- `status`
- `type`
- `readinessState`
- `initiativeId`
- `targetSystem`
- `blocked`
- `limit`
- `cursor`

### Ordering
Default ordering should be deterministic:

```text
updatedAt desc, id asc
```

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `initiativeId`
- `key`
- `title`
- `description`
- `type`
- `status`
- `readinessState`
- `targetSystem`
- `blocked`
- `blockedReason`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/work-items/:workItemId`

### Failure posture
- `404` if the work item does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/work-items`

### Required input
- `key`
- `title`
- `type`
- `targetSystem`

### Optional input
- `description`
- `initiativeId`
- `blocked`
- `blockedReason`

### Initial status
The server assigns `status = proposed` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Validation
- `projectId` must reference a real project and must not be archived; creation under an archived project must fail with `422 Unprocessable Entity`
- `key` must be unique within the project
- `initiativeId`, if supplied, must belong to the same project and must not be archived; linking to an archived initiative must fail with `422 Unprocessable Entity`
- `type` must use controlled vocabulary
- `targetSystem` must use controlled vocabulary
- `blockedReason` must be non-empty when `blocked = true`; omitting it when `blocked = true` must fail with `400 Bad Request`
- `readinessState` is server-managed; callers must not supply it at creation. Supplying it must fail with `400 Bad Request`.

### Response
- `201 Created` with canonical work-item record

---

## `PATCH /api/projects/:projectId/work-items/:workItemId`

### Allowed mutable fields
- `title`
- `description`
- `initiativeId`
- `type`
- `targetSystem`
- `blocked`
- `blockedReason`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- linking to an initiative in another project
- re-parenting to an archived initiative; this must fail with `422 Unprocessable Entity`
- directly patching `readinessState` as caller-owned truth; attempting to do so must fail with `400 Bad Request`
- silently converting planning state into execution-owned state
- silent status transition through generic patch if explicit status routes are used

Attempting to supply any other forbidden field in a PATCH body must fail with `400 Bad Request`.

### readinessState reset behavior
`readinessState` may be reset to `unevaluated` by the server when a readiness basis is invalidated (for example, when a newer evaluation supersedes a prior one or when the basis conditions change). This is a server-managed state change. Operators who observe `readinessState` reverting to `unevaluated` without a direct PATCH should treat this as expected governed behavior. See `docs/architecture/core/readiness-methodology.md`.

### Response
- `200 OK` with updated canonical work-item record

---

## `POST /api/projects/:projectId/work-items/:workItemId/status`

### Required input
- `newStatus`
- `reason` — required for the following transitions: `active -> archived`, `blocked -> archived`, `proposed -> archived`. Optional for all other allowed transitions.

### Validation
- `newStatus` must use controlled vocabulary (`proposed`, `active`, `blocked`, `completed`, `archived`)
- only transitions defined as allowed in `docs/architecture/data/status-transitions.md` are accepted; all others must fail deterministically with `422 Unprocessable Entity`
- `reason` must be non-empty when required for the transition; a missing or empty reason on a required-reason transition must fail with `400 Bad Request`
- all work-item status transitions must write a `StatusHistory` row atomically in the same transaction

### Response
- `200 OK` with updated work-item record and status-history confirmation fields

---

## Recommended Controlled Vocabularies

### Work item status
Recommended initial values:

- `proposed`
- `active`
- `blocked`
- `completed`
- `archived`

### Work item type
Recommended initial values:

- `analysis`
- `planning`
- `specification`
- `handoff-preparation`
- `governance`

### Readiness state
Recommended initial values:

- `unevaluated`
- `not_ready`
- `ready_with_warnings`
- `ready`
- `deferred`

`readinessState` should be treated as a server-managed field derived from governed readiness evaluation behavior rather than a normal caller-controlled patch field.

Exact enum values should align to the schema specification.

---

## Error Posture

First-pass expected error classes:

- `400 Bad Request` for malformed input
- `404 Not Found` for missing project or work item
- `409 Conflict` for duplicate `key` within the project
- `422 Unprocessable Entity` for semantically invalid but well-formed input

Use the common Project V error body shape governed by `docs/api/api-conventions.md`.

---

## Hammer Expectations

This family should be hammered for:

- project-scope enforcement
- per-project key uniqueness
- duplicate key rejection (409)
- same-project initiative enforcement
- invalid controlled-vocabulary rejection
- blocked-reason validation
- deterministic listing
- illegal status transition rejection (all forbidden transitions fail with `422`)
- missing required `reason` rejection for archival transitions
- `StatusHistory` row written for every status transition

---

## Final Rule

The Work Items API manages planning and execution-preparation truth only.
It must not become a disguised execution-state API.






