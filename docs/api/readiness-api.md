# Readiness API

## Purpose

This document defines the Project V `readiness` endpoint family.

It exists to answer:

```text
How are readiness evaluations and readiness gaps created, listed, and retrieved without turning readiness into opaque workflow theater?
```

Read this with:

- `docs/api/api-conventions.md`
- `docs/api/endpoint-governance.md`
- `docs/architecture/core/readiness-methodology.md`
- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/status-transitions.md`

---

## Family Scope

This family manages project-scoped readiness evaluations and readiness gaps.

Readiness remains planning and orchestration truth.
It does not silently mutate canonical planning truth.

---

## Route Family

### `GET /api/projects/:projectId/readiness-evaluations`
List readiness evaluations for one project.

### `GET /api/projects/:projectId/readiness-evaluations/:readinessEvaluationId`
Get one readiness evaluation.

### `POST /api/projects/:projectId/readiness-evaluations`
Create a readiness evaluation.

### `GET /api/projects/:projectId/readiness-gaps`
List readiness gaps for one project.

### `GET /api/projects/:projectId/readiness-gaps/:readinessGapId`
Get one readiness gap.

### `PATCH /api/projects/:projectId/readiness-gaps/:readinessGapId`
Update bounded mutable readiness-gap fields.

No delete routes exist in the first pass.

---

## Scope Rules

- every route is project-scoped
- evaluation and gap IDs alone must not bypass project ownership rules
- evaluated entities must belong to the same project
- cross-project existence leakage is forbidden by default

---

## `GET /api/projects/:projectId/readiness-evaluations`

### Query parameters
Allowed first-pass filters:

- `evaluationType`
- `result`
- `entityType`
- `entityId`
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
- `evaluationType`
- `result`
- `rulePackage`
- `summary`
- `createdAt`

---

## `GET /api/projects/:projectId/readiness-evaluations/:readinessEvaluationId`

### Failure posture
- `404` if the evaluation does not belong to the project or does not exist
- `400` for malformed identifiers

### Response notes
The response should include enough detail to preserve explainability.
If related gaps are embedded, the embedding behavior must remain stable and documented.

---

## `POST /api/projects/:projectId/readiness-evaluations`

### Required input
- `entityType`
- `entityId`
- `evaluationType`

### Optional input
- `rulePackage` — if omitted, the server applies the governed standard package for the given `evaluationType`. An explicit value overrides the default. If an unknown or incompatible `rulePackage` value is supplied, the request must fail with `422 Unprocessable Entity`. See `docs/architecture/core/readiness-evaluation-rules.md` for the allowed rule packages per evaluation type.

### Forbidden caller input
- `result` is server-owned. Callers must not supply it. The server computes it from the evaluation execution.
- `summary` is server-generated. Callers must not supply it. The server produces it as part of evaluation execution.

### Validation
- evaluated entity must exist inside the same project
- `evaluationType` must use controlled vocabulary (`research`, `planning`, `implementation_readiness`, `code_alignment`, `handoff`, `hygiene`); an unknown value must fail with `422 Unprocessable Entity`
- `entityType` must use controlled vocabulary (`objective`, `initiative`, `work_item`, `handoff`); an unknown value must fail with `422 Unprocessable Entity`
- pre-flight inspectable basis checks: the evaluated entity must have a non-empty `title`, must exist in an evaluable status (not `archived`), and must be resolvable through the central polymorphic resolver defined in `docs/architecture/data/polymorphic-reference-enforcement.md`; failure of any pre-flight check must fail the request with `422 Unprocessable Entity` before evaluation execution begins

### Evaluation execution model
Readiness evaluation execution is **synchronous** in the first pass. The `result` and `summary` are computed and persisted before the 201 response is returned. There is no async deferred result.

### Mutation rule
Creating an evaluation creates related `ReadinessGap` records atomically where the governed evaluation process identifies deficiencies. Zero gaps is a valid outcome if no deficiencies are found.

Where the evaluated entity is a `WorkItem`, the server synchronizes the work item’s `readinessState` in the same transaction according to this mapping:
- evaluation `result = ready` → `readinessState = ready`
- evaluation `result = ready_with_warnings` → `readinessState = ready_with_warnings`
- evaluation `result = not_ready` → `readinessState = not_ready`
- evaluation `result = deferred` → `readinessState = deferred`

If a subsequent evaluation supersedes a prior one, the work item’s `readinessState` is updated to match the latest evaluation result.

### Response
- `201 Created` with canonical evaluation record
- response includes a `gaps` array containing any `ReadinessGap` records created during this evaluation (may be empty)

---

## `GET /api/projects/:projectId/readiness-gaps`

### Query parameters
Allowed first-pass filters:

- `severity`
- `resolved`
- `entityType`
- `entityId`
- `readinessEvaluationId`
- `limit`
- `cursor`

### Filtering note
- `severity`, `resolved`, and `readinessEvaluationId` are direct gap filters
- `entityType` and `entityId` are join-based filters through the related readiness evaluation rather than direct readiness-gap fields; these filters return all readiness gaps associated with any readiness evaluation for the specified entity, across all evaluations for that entity, ordered by the standard list ordering

### Ordering
Default ordering should be deterministic:

```text
resolved asc, severity_rank desc, createdAt desc, id asc
```

where `severity_rank` maps the severity vocabulary to an integer for correct ordering: `critical = 4`, `major = 3`, `minor = 2`, `advisory = 1`. Critical gaps appear before advisory gaps. Raw text ordering on these values is incorrect.

### Response shape
Each item should expose at least:

- `id`
- `projectId`
- `readinessEvaluationId`
- `severity`
- `description`
- `remediationSuggestion`
- `resolved`
- `createdAt`
- `updatedAt`

---

## `GET /api/projects/:projectId/readiness-gaps/:readinessGapId`

### Failure posture
- `404` if the gap does not belong to the project or does not exist
- `400` for malformed identifiers

---

## `PATCH /api/projects/:projectId/readiness-gaps/:readinessGapId`

### Allowed mutable fields
- `resolved`
- `remediationSuggestion`

### Forbidden first-pass mutations
- changing `projectId`
- changing canonical `id`
- reassigning the gap to another evaluation
- rewriting gap history silently if the system later adds explicit history records

### Validation
- `resolved` must be a boolean value
- `resolved` may be set to `true` (marking the gap resolved) or back to `false` (reopening it) in the first pass; there is no one-way constraint
- if a stricter resolved lifecycle is needed later, it must be modeled explicitly through governance

### Response
- `200 OK` with updated canonical gap record

---

## Controlled Vocabularies

### Evaluation result
Allowed values are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

### Gap severity
Allowed values are governed by:

- `docs/architecture/data/controlled-vocabularies.md`

---

## Hammer Expectations

This family should be hammered for:

- same-project entity enforcement
- explainability preservation
- deterministic listing
- readiness-gap creation where required
- invalid evaluation attempts without basis
- advisory outputs not silently mutating canonical planning truth
- server-owned result computation
- join-based readiness-gap filtering correctness

---

## Final Rule

The Readiness API must keep readiness explicit, inspectable, and reproducible.
If the surface becomes magic, it is wrong.

