# Schema Specification

## Purpose

This document defines the first-pass concrete schema specification for Project V.

It exists to answer:

```text
What are the exact columns, types, constraints, indexes, and allowed mutations for the first-pass Project V schema?
```

Read this with:

- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-governance.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/core/multi-project-doctrine.md`

If this document conflicts with `schema-authority.md`, the conflict must be resolved explicitly. Neither should be silently ignored.

---

## Type Conventions

These specifications assume PostgreSQL.

Recommended baseline type posture:

- primary keys: `uuid`
- foreign keys: `uuid`
- short stable keys: `text`
- titles and descriptions: `text`
- status and controlled-vocabulary fields: `text` constrained by application and later enum/check strategy
- timestamps: `timestamptz`
- booleans: `boolean`
- bounded flexible payloads only where justified: `jsonb`

---

## Controlled Vocabulary Rule

Controlled vocabulary fields should remain explicit and small.

They may initially be implemented as constrained `text` values, with a later decision on database enum vs check-constraint strategy.

The following fields should use controlled vocabularies in the first pass:

- project `status`
- objective `status`
- initiative `status`
- initiative `targetSystem`
- work item `type`
- work item `status`
- work item `readinessState`
- work item `targetSystem`
- dependency `dependencyType`
- dependency `status`
- readiness evaluation `entityType`
- readiness evaluation `evaluationType`
- readiness evaluation `result`
- decision record `status`
- audit run `auditType`
- audit run `result`
- audit gap `severity`
- audit gap `status`
- GitHub link `linkType`
- readiness gap `severity`
- handoff `sourceEntityType`
- handoff `targetSystem`
- handoff `handoffType`
- handoff `status`
- status history `entityType`

---

## 1. `Project`

### Purpose
Project-scoped planning anchor.

### Columns
- `id uuid primary key`
- `key text not null`
- `name text not null`
- `status text not null default 'active'`
- `description text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- unique: `(key)`
- `key` must be non-empty
- `key` must conform to the governed key format
- `name` must be non-empty

### Indexes
- unique index on `key`
- index on `(status, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `name`, `description`
- explicit status transition route or governed mutation path for `status`
- no delete in first pass

---

## 2. `Objective`

### Purpose
Project-scoped major outcome.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `key text not null`
- `title text not null`
- `description text null`
- `status text not null default 'proposed'`
- `priority integer not null default 100`
- `targetStartAt timestamptz null`
- `targetEndAt timestamptz null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- unique: `(projectId, key)`
- `key` must conform to the governed key format
- `title` must be non-empty
- if both target dates exist, `targetEndAt >= targetStartAt`

### Indexes
- unique index on `(projectId, key)`
- index on `(projectId, status, priority, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `title`, `description`, `priority`, `targetStartAt`, `targetEndAt`
- explicit status transition route or governed mutation path
- no delete in first pass

---

## 3. `Initiative`

### Purpose
Project-scoped bounded body of work.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `objectiveId uuid null references Objective(id)`
- `key text not null`
- `title text not null`
- `description text null`
- `status text not null default 'proposed'`
- `priority integer not null default 100`
- `targetSystem text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- unique: `(projectId, key)`
- `key` must conform to the governed key format
- `title` must be non-empty
- if `objectiveId` is not null, the referenced Objective must belong to the same `projectId`

### Indexes
- unique index on `(projectId, key)`
- index on `(projectId, objectiveId)`
- index on `(projectId, status, priority, updatedAt desc, id)`
- index on `(projectId, targetSystem, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `title`, `description`, `objectiveId`, `priority`, `targetSystem`
- explicit status transition route or governed mutation path
- no delete in first pass

---

## 4. `WorkItem`

### Purpose
Project-scoped planning or execution-preparation unit.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `initiativeId uuid null references Initiative(id)`
- `key text not null`
- `title text not null`
- `description text null`
- `type text not null`
- `status text not null default 'proposed'`
- `readinessState text not null default 'unevaluated'`
- `targetSystem text not null`
- `blocked boolean not null default false`
- `blockedReason text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- unique: `(projectId, key)`
- `key` must conform to the governed key format
- `title` must be non-empty
- if `initiativeId` is not null, the referenced Initiative must belong to the same `projectId`
- if `blocked = true`, `blockedReason` must be non-null and non-empty (application-layer validation rule; enforced by the mutation path, not a DB-level CHECK constraint)

### Indexes
- unique index on `(projectId, key)`
- index on `(projectId, initiativeId)`
- index on `(projectId, status, updatedAt desc, id)`
- index on `(projectId, readinessState, updatedAt desc, id)`
- index on `(projectId, targetSystem, updatedAt desc, id)`
- index on `(projectId, blocked, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `title`, `description`, `initiativeId`, `type`, `targetSystem`, `blocked`, `blockedReason`
- server-managed update of `readinessState` only through governed readiness evaluation behavior
- explicit status transition route or governed mutation path
- no delete in first pass

---
## 5. `Dependency`

### Purpose
Explicit dependency relationship between Project V records.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `sourceEntityType text not null`
- `sourceEntityId uuid not null`
- `targetEntityType text not null`
- `targetEntityId uuid not null`
- `dependencyType text not null`
- `status text not null default 'active'`
- `rationale text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- source and target entities must belong to the same `projectId`
- source and target must not be identical in both type and id
- duplicates of the same logical dependency should be prevented where practical

### Indexes
- unique index on `(projectId, sourceEntityType, sourceEntityId, targetEntityType, targetEntityId, dependencyType)`
- index on `(projectId, sourceEntityType, sourceEntityId)`
- index on `(projectId, targetEntityType, targetEntityId)`
- index on `(projectId, status, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `status`, `rationale`
- no delete in first pass unless a later ADR explicitly permits dependency removal semantics

---

## 6. `DecisionRecord`

### Purpose
Recoverable decision and rationale.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `entityType text null`
- `entityId uuid null`
- `title text not null`
- `decisionSummary text not null`
- `rationale text not null`
- `status text not null`
- `actor text not null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- if `entityType` and `entityId` are present, the referenced entity must belong to the same `projectId`
- `title`, `decisionSummary`, and `rationale` must be non-empty

### Indexes
- index on `(projectId, createdAt desc, id)`
- index on `(projectId, entityType, entityId, createdAt desc, id)`
- index on `(projectId, status, createdAt desc, id)`

### Allowed mutations
- create
- bounded governed status update only (`recorded -> superseded`); this transition must also write a `StatusHistory` row in the same transaction
- no delete in first pass

---

## 7. `ReadinessEvaluation`

### Purpose
Inspectable readiness evaluation.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `entityType text not null`
- `entityId uuid not null`
- `evaluationType text not null`
- `result text not null`
- `rulePackage text not null`
- `summary text not null`
- `createdAt timestamptz not null default now()`

### Constraints
- evaluated entity must belong to the same `projectId`
- `summary` must be non-empty
- no evaluation may be stored without inspectable basis according to application rules

### Summary generation rule
`summary` is server-generated by the evaluation execution logic. Callers must not supply it as input. The server must produce a non-empty summary as part of completing any readiness evaluation; an evaluation may not be persisted without one.

### Indexes
- index on `(projectId, entityType, entityId, createdAt desc, id)`
- index on `(projectId, result, createdAt desc, id)`
- index on `(projectId, evaluationType, createdAt desc, id)`

### Allowed mutations
- create
- no generic update in first pass
- no delete in first pass

---

## 8. `ReadinessGap`

### Purpose
Explicit readiness deficiency or blocker.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `readinessEvaluationId uuid not null references ReadinessEvaluation(id)`
- `severity text not null`
- `description text not null`
- `remediationSuggestion text null`
- `resolved boolean not null default false`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- linked readiness evaluation must belong to the same `projectId`
- `description` must be non-empty

### Indexes
- index on `(projectId, readinessEvaluationId)`
- index on `(projectId, resolved, severity, createdAt desc, id)`

### Severity ordering rule
The `severity` field uses a text controlled vocabulary. List surfaces ordering by `severity desc` must apply a severity-rank mapping, not raw text ordering. The canonical severity rank from highest to lowest is: `critical` (4), `major` (3), `minor` (2), `advisory` (1). Ordering by `severity desc` means critical first, advisory last. Raw text ordering on these values is incorrect and must not be used.

### Resolved toggle rule
`resolved` may be set from `false` to `true` by a caller through the PATCH route. Setting `resolved` back to `false` is also allowed in the first pass — there is no one-way constraint on this field. If a stricter lifecycle is later required, it should be modeled explicitly.

### Allowed mutations
- create
- bounded update of `resolved`, `remediationSuggestion`
- no delete in first pass

---

## 9. `ResearchDoc`

### Purpose
Planning-support research artifact.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `title text not null`
- `sourceType text not null`
- `storageLocator text not null`
- `status text not null`
- `summary text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- `title` must be non-empty
- `storageLocator` must be non-empty

### Indexes
- index on `(projectId, status, updatedAt desc, id)`
- index on `(projectId, sourceType, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `title`, `status`, `summary`, `storageLocator`
- no delete in first pass

---

## 10. `EvidenceLink`

### Purpose
Directional link from planning truth to supporting evidence.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `sourceEntityType text not null`
- `sourceEntityId uuid not null`
- `evidenceType text not null`
- `targetLocator text not null`
- `note text null`
- `relevanceScore integer null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- source entity must belong to the same `projectId`
- `targetLocator` must be non-empty
- if `relevanceScore` exists, it must stay within the governed range `0..100`

### Indexes
- index on `(projectId, sourceEntityType, sourceEntityId, createdAt desc, id)`
- index on `(projectId, evidenceType, createdAt desc, id)`
- index on `(projectId, sourceEntityType, sourceEntityId, updatedAt desc, id)`

### Index note
Both source-entity indexes are intentional in the first pass: one supports created-time ordered evidence traversal, and the other supports updated-time ordered evidence traversal.

### Allowed mutations
- create
- bounded update of `note`, `relevanceScore`
- no delete in first pass

---

## 11. `Handoff`

### Purpose
Bounded transition of responsibility.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `sourceEntityType text not null`
- `sourceEntityId uuid not null`
- `targetSystem text not null`
- `handoffType text not null`
- `status text not null default 'proposed'`
- `readinessBasisSummary text null`
- `createdAt timestamptz not null default now()`
- `completedAt timestamptz null`
- `updatedAt timestamptz not null default now()`

### Constraints
- source entity must belong to the same `projectId`
- `targetSystem` and `handoffType` must use controlled vocabulary
- `completedAt` must not precede `createdAt`

### Indexes
- index on `(projectId, status, createdAt desc, id)`
- index on `(projectId, targetSystem, createdAt desc, id)`
- index on `(projectId, sourceEntityType, sourceEntityId, createdAt desc, id)`

### Allowed mutations
- create
- bounded update of `readinessBasisSummary`
- explicit status transition route or governed mutation path
- no delete in first pass

---

## 12. `StatusHistory`

### Purpose
Recoverable history for meaningful state changes.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `entityType text not null`
- `entityId uuid not null`
- `previousStatus text null`
- `newStatus text not null`
- `reason text null`
- `actor text not null`
- `createdAt timestamptz not null default now()`

### Constraints
- referenced entity must belong to the same `projectId`
- `newStatus` must be non-empty
- history entries should be created atomically with the transitions they describe when history is required

### previousStatus nullability note
`previousStatus` is nullable by design. The first transition for a given entity may not have a known prior status recoverable at write time. Null means no prior status was recorded, not that one did not exist.

### Indexes
- index on `(projectId, entityType, entityId, createdAt desc, id)`
- index on `(projectId, createdAt desc, id)`

### Allowed mutations
- create
- no update in first pass
- no delete in first pass

---

## 13. `AuditRun`

### Purpose
Project-scoped BYDA-style audit execution.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `auditType text not null`
- `targetEntityType text null`
- `targetEntityId uuid null`
- `result text not null`
- `summary text not null`
- `startedAt timestamptz null`
- `completedAt timestamptz null`
- `createdAt timestamptz not null default now()`

### Constraints
- if `targetEntityType` and `targetEntityId` are present, the referenced entity must belong to the same `projectId`
- `summary` must be non-empty
- `completedAt` must not precede `startedAt` where both exist

### Indexes
- index on `(projectId, auditType, createdAt desc, id)`
- index on `(projectId, result, createdAt desc, id)`
- index on `(projectId, targetEntityType, targetEntityId, createdAt desc, id)`

### Allowed mutations
- create
- bounded update of `completedAt` where the audit execution path requires completion stamping
- bounded governed update of `result` only where a prior audit is explicitly invalidated into `stale`
- bounded governed update of `summary` only where audit execution finalization or invalidation requires it
- no delete in first pass

---

## 14. `AuditGap`

### Purpose
Project-scoped audit deficiency or failure.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `auditRunId uuid not null references AuditRun(id)`
- `severity text not null`
- `description text not null`
- `remediation text null`
- `status text not null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- linked audit run must belong to the same `projectId`
- `description` must be non-empty

### Field naming note
The `remediation` column corresponds to what `schema-authority.md` calls "remediation guidance" in the AuditGap required traits. These refer to the same field. The canonical column name is `remediation`.

### Indexes
- index on `(projectId, auditRunId)`
- index on `(projectId, status, severity, createdAt desc, id)`

### Allowed mutations
- create
- bounded update of `status`, `remediation`
- no delete in first pass

---

## 15. `GitHubLink`

### Purpose
Project-scoped bounded GitHub linkage for implementation traceability.

### Columns
- `id uuid primary key`
- `projectId uuid not null references Project(id)`
- `sourceEntityType text not null`
- `sourceEntityId uuid not null`
- `linkType text not null`
- `url text not null`
- `externalId text null`
- `label text null`
- `createdAt timestamptz not null default now()`
- `updatedAt timestamptz not null default now()`

### Constraints
- source entity must belong to the same `projectId`
- `url` must be non-empty and must begin with `https://`; format validation is enforced at the application layer
- existence of the referenced URL is not validated at the database or application layer
- unique: `(projectId, sourceEntityType, sourceEntityId, linkType, url)`; duplicate logical linkage must fail with `409 Conflict`

### Note on `updatedAt`
Mutations are explicitly allowed on this table (`label`, `url`, `externalId`). `updatedAt` is therefore non-nullable with a default and must be maintained by the mutation path in the same transaction as the governed write.

### Indexes
- unique index on `(projectId, sourceEntityType, sourceEntityId, linkType, url)`
- index on `(projectId, sourceEntityType, sourceEntityId, createdAt desc, id)`
- index on `(projectId, linkType, createdAt desc, id)`
- index on `(projectId, updatedAt desc, id)`

### Allowed mutations
- create
- bounded update of `label`, `url`, `externalId`
- no delete in first pass

---

## Archived-Parent Integrity Rule

In the first pass, archived parent records should freeze normal forward child growth beneath them.

That means:

- do not create child objectives, initiatives, or work items under an archived parent
- do not re-parent active children under an archived parent

If an exception is later needed, it should be modeled explicitly.

---

## `updatedAt` Maintenance Rule

Where a first-pass canonical table has an `updatedAt` column, Project V should update that column through the application/service mutation path in the same transaction as the governed write.

The first-pass posture does not depend on database triggers for `updatedAt`.

---

## Cross-Table Integrity Rules

### Same-project relation rule
Where one project-scoped record references another, both must belong to the same `projectId` unless a later ADR explicitly introduces a bounded exception.

### Orphan prevention rule
Project-scoped child records must not outlive the project anchor without an explicit archival or cascade strategy.

### Atomic state/history rule
Where a transition requires status history, the state change and history row should be written in the same transaction.

### Deterministic ordering support rule
All list surfaces must be supportable by explicit ordering backed by stable tie-breakers.

---

## Mutation Summary

### Create allowed in first pass
- Project
- Objective
- Initiative
- WorkItem
- Dependency
- DecisionRecord
- ReadinessEvaluation
- ReadinessGap
- ResearchDoc
- EvidenceLink
- Handoff
- StatusHistory

### Generic update allowed in first pass
- Project (bounded fields)
- Objective (bounded fields)
- Initiative (bounded fields)
- WorkItem (bounded fields)
- Dependency (bounded fields)
- DecisionRecord (governed status transition only; `recorded -> superseded` with StatusHistory row required)
- ReadinessGap (bounded fields)
- ResearchDoc (bounded fields)
- EvidenceLink (bounded fields)
- Handoff (bounded fields)

### Explicit status-transition path preferred
- Objective
- Initiative
- WorkItem
- Handoff
- Project if lifecycle status changes are governed explicitly

### No delete in first pass
No canonical first-pass table should expose destructive delete behavior until deletion semantics are explicitly modeled and hammered.

---

## Final Rule

This schema specification is intentionally strict.

If implementation pressure suggests broadening it casually, the correct response is governance review, not improvisation.














