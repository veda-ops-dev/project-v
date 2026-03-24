# Polymorphic Reference Enforcement

## Purpose

This document defines how Project V enforces polymorphic references safely.

It exists to answer:

```text
How do tables that use entityType + entityId references stay valid, same-project, and implementation-safe when normal database foreign keys cannot enforce them directly?
```

Read this with:

- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/controlled-vocabularies.md`

---

## Core Rule

Project V uses polymorphic references in several first-pass tables.

That means some records point at a target through:

- `entityType`
- `entityId`

rather than a single normal foreign key.

Because PostgreSQL cannot enforce this shape with a single native foreign key, Project V must enforce it deliberately and consistently.

Implementation must not invent different enforcement strategies in different routes or services.

---

## Tables Affected

First-pass tables that use polymorphic references include:

- `Dependency`
- `DecisionRecord`
- `ReadinessEvaluation`
- `EvidenceLink`
- `Handoff`
- `StatusHistory`
- `AuditRun`
- `GitHubLink`

These tables are valid only if the referenced entity:

- exists
- belongs to the same project
- matches the declared `entityType`

---

## Canonical Enforcement Strategy

Project V should use a **central polymorphic-reference resolver** in application logic.

That resolver should:

1. map each allowed `entityType` to a canonical Project V table
2. verify the referenced row exists
3. verify the referenced row belongs to the supplied `projectId`
4. fail deterministically if the row does not exist or belongs to another project
5. return a normalized resolution result for the calling mutation path

This logic should not be reimplemented differently in each route handler.

---

## Allowed Entity Types By Table

### `Dependency`
Allowed `sourceEntityType` and `targetEntityType` values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

### `DecisionRecord`
Allowed `entityType` values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

### `ReadinessEvaluation`
Allowed `entityType` values:

- `objective`
- `initiative`
- `work_item`
- `handoff`

### `EvidenceLink`
Allowed `sourceEntityType` values:

- `objective`
- `initiative`
- `work_item`
- `handoff`
- `decision_record`
- `research_doc`

### `Handoff`
Allowed `sourceEntityType` values:

- `objective`
- `initiative`
- `work_item`

### `StatusHistory`
Allowed `entityType` values:

- `project`
- `objective`
- `initiative`
- `work_item`
- `handoff`

### `AuditRun`
Allowed `targetEntityType` values:

- `project`
- `objective`
- `initiative`
- `work_item`
- `handoff`

### Same-project resolution edge case for `targetEntityType = 'project'`

All other polymorphic tables resolve same-project ownership by checking:
```
targetRow.projectId == ownerRow.projectId
```

When `AuditRun.targetEntityType = 'project'`, the target row **is** the `Project` table. The `Project` table has no `projectId` column — its `id` is the project anchor itself.

The same-project check for this case is therefore:
```
AuditRun.projectId == targetEntityId
```

The central polymorphic resolver must handle this case explicitly. It must not attempt to read a `projectId` field from the resolved `Project` row, as none exists.

### Additional applicability rule
Polymorphic resolution alone is not sufficient for audit execution.

The audit execution path must also verify that the requested `auditType` is valid for the supplied `targetEntityType` according to the governed allowed-target mapping in the audit model and audit-evaluation rules.

### `GitHubLink`
Allowed `sourceEntityType` values:

- `objective`
- `initiative`
- `work_item`
- `handoff`
- `decision_record`
- `research_doc`
- `audit_run`

If a new entity type is introduced later, update:

- `docs/architecture/data/controlled-vocabularies.md`
- this enforcement doc
- affected schema/API docs
- hammer expectations

---

## Same-Project Enforcement Rule

Every polymorphic reference must resolve inside the same `projectId` as the owning row.

Example:

- a `Dependency` row in project A may not point to an `Initiative` in project B
- a `ReadinessEvaluation` row in project A may not evaluate a `WorkItem` in project B
- a `StatusHistory` row in project A may not record a transition for a `Handoff` in project B

If the referenced row exists but belongs to another project, the operation must fail as unavailable or invalid according to the relevant contract.

No cross-project existence leakage is allowed by default.

---

## Read and Write Enforcement Rule

### Writes
All writes that create or mutate polymorphic references must resolve the reference before commit.

The write must fail if:

- `entityType` is not allowed
- `entityId` does not exist
- `entityId` exists under another project
- the reference shape is illegal for that table

### Reads
Read surfaces that expose these references should not promise more than they can validate.

When filtering by polymorphic targets, the filter behavior must remain explicit and deterministic.

---

## Query Strategy Rule

For read filters that rely on a referenced entity not stored directly on the filtered table, document the filter as **join-based** or **resolver-based**.

Do not pretend a table has a direct field when the filter actually depends on traversing a related record.

This is especially important for surfaces like readiness gaps filtered by evaluated entity.

---

## Transaction Rule

If a mutation both:

- changes a referenced entity state
- and writes a polymorphic record about that entity

the operation should use one transaction where the invariant requires atomicity.

This is especially important for:

- status transitions + `StatusHistory`
- readiness evaluation + `ReadinessGap`
- governed transitions + `DecisionRecord` where required

---

## Error Posture Rule

Polymorphic reference failures should be deterministic.

Recommended behavior:

- malformed `entityType` -> validation failure
- unknown `entityType` -> validation failure
- non-existent `entityId` in project scope -> not found or semantically invalid according to route contract
- cross-project target -> unavailable or semantically invalid without existence leakage

The route family should keep that posture stable.

---

## Hammer Expectations

The hammer suite should verify at least:

- illegal `entityType` rejection
- same-project enforcement for all polymorphic tables
- cross-project target rejection without leakage
- invalid `entityId` rejection
- transaction alignment where polymorphic writes are coupled to state transitions

---

## Final Rule

Polymorphic references are allowed in Project V only because they are governed.

If implementation treats them as casual string-plus-UUID fields without a shared enforcement strategy, the design is wrong.


