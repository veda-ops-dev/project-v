# Handoffs API

## Purpose

This document defines the Project V `handoffs` endpoint family.

It exists to answer:

```text
How are bounded handoff records created, listed, retrieved, and updated without collapsing ownership between Project V and downstream systems?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/integrations/v-forge-integration.md`
- `docs/architecture/integrations/veda-integration.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`

---

## Family Scope

This family manages project-scoped Handoff records.

A handoff is a bounded transition of responsibility.
It is not shared ownership.

---

## Route Family

### `GET /api/projects/:projectId/handoffs`
List handoffs for one project.

### `GET /api/projects/:projectId/handoffs/:handoffId`
Get one handoff.

### `POST /api/projects/:projectId/handoffs`
Create a handoff.

### `PATCH /api/projects/:projectId/handoffs/:handoffId`
Update bounded mutable handoff fields.

### `POST /api/projects/:projectId/handoffs/:handoffId/status`
Execute an explicit status transition for a handoff.

No delete route exists in the first pass.

---

## Scope Rules

- every route is project-scoped
- `handoffId` alone must not bypass project ownership rules
- source entity references must belong to the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/handoffs`

### Query parameters
Allowed first-pass filters:

- `status`
- `targetSystem`
- `handoffType`
- `sourceEntityType`
- `sourceEntityId`
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
- `sourceEntityType`
- `sourceEntityId`
- `targetSystem`
- `handoffType`
- `status`
- `readinessBasisSummary`
- `createdAt`
- `completedAt`
- `updatedAt`

### completedAt population rule
`completedAt` is server-set. The server assigns `completedAt = now()` atomically when the status transitions to `closed`. For all other transitions, `completedAt` remains null. Callers must not supply `completedAt`.

---

## `GET /api/projects/:projectId/handoffs/:handoffId`

### Failure posture
- `404` if the handoff does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `POST /api/projects/:projectId/handoffs`

### Required input
- `sourceEntityType`
- `sourceEntityId`
- `targetSystem`
- `handoffType`

### Optional input
- `readinessBasisSummary`

### Initial status
The server assigns `status = proposed` on creation. Callers must not supply a `status` field at creation. Supplying one must fail with `400 Bad Request`.

### Validation
- source entity must exist in the same project
- `sourceEntityType` must use controlled vocabulary (`objective`, `initiative`, `work_item`)
- `targetSystem` must use controlled vocabulary (`project_v`, `veda`, `v_forge`)
- `handoffType` must use controlled vocabulary (`execution`, `analysis`, `governance`, `review`)
- handoff creation does **not** require a passing readiness evaluation in the first pass; readiness is tracked separately and does not gate creation
- if a readiness gate before handoff creation is required later, it must be modeled explicitly through governance

### Response
- `201 Created` with canonical handoff record

---

## `PATCH /api/projects/:projectId/handoffs/:handoffId`

### Allowed mutable fields
- `readinessBasisSummary`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- changing source entity identity after creation
- changing `targetSystem` is forbidden; attempting to do so must fail with `400 Bad Request`
- silently performing status transitions through generic patch if explicit status routes are used

Attempting to supply any other forbidden field in a PATCH body must fail with `400 Bad Request`.

### Response
- `200 OK` with updated canonical handoff record

---

## `POST /api/projects/:projectId/handoffs/:handoffId/status`

### Required input
- `newStatus`
- `reason` — required for the following transitions:
  - `proposed -> closed`
  - `ready -> closed`
  - `handed_off -> closed`
  - `handed_off -> ready`
  - `handed_off -> proposed`

  Optional for all other allowed transitions.

### Validation
- `newStatus` must use controlled vocabulary (`proposed`, `ready`, `handed_off`, `accepted`, `closed`)
- only transitions defined as allowed in `docs/architecture/data/status-transitions.md` are accepted; all others must fail deterministically with `422 Unprocessable Entity`
- `reason` must be non-empty when required for the transition; a missing or empty reason on a required-reason transition must fail with `400 Bad Request`
- all handoff status transitions must write a `StatusHistory` row atomically in the same transaction; this applies to every transition, not only close transitions
- when the transition target is `closed`, the server must also set `completedAt = now()` atomically in the same transaction

### Reverse / re-entry transitions
The transitions `handed_off -> ready` and `handed_off -> proposed` are the supported
first-pass re-entry paths for bounce-back or rejection scenarios.

These transitions:
- require an explicit non-empty `reason`
- must write a `StatusHistory` row atomically
- are operator-initiated; the API must not trigger them automatically
- do not reset `readinessBasisSummary`; callers may update that field separately via PATCH
  after re-entering if the basis has changed

See `docs/architecture/integrations/v-forge-integration.md` and
`docs/architecture/data/status-transitions.md` for the full transition authority.

### Response
- `200 OK` with updated handoff record and status-history confirmation fields

---

## Controlled Vocabularies

All handoff controlled vocabulary values are governed by `docs/architecture/data/controlled-vocabularies.md`.

### Target system
Governed values (must match controlled vocabulary):

- `project_v`
- `veda`
- `v_forge`

### Handoff status
Governed values (must match controlled vocabulary):

- `proposed`
- `ready`
- `handed_off`
- `accepted`
- `closed`

### Handoff type
Governed values (must match controlled vocabulary):

- `execution`
- `analysis`
- `governance`
- `review`

---

## Hammer Expectations

This family should be hammered for:

- same-project source-entity enforcement
- invalid target-system rejection
- invalid handoff-type rejection
- deterministic listing
- illegal status transition rejection (all forbidden transitions fail with `422`)
- reverse transition rejection from `accepted` and `closed`
- reverse transition acceptance from `handed_off` with reason
- reverse transition rejection from `handed_off` without reason
- `StatusHistory` row written for every transition
- `completedAt` set atomically on `closed` transition
- scope leakage rejection

---

## Final Rule

The Handoffs API records bounded transitions of responsibility only.
It must not become a shadow execution-state API.
