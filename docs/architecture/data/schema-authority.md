# Schema Authority

## Purpose

This document is the canonical schema authority for Project V.

It exists to answer:

```text
What tables does Project V canonically own, what does each table mean, how is project scope enforced, and what structural rules must the schema preserve?
```

This document is the authority for the first-pass Project V schema shape.
If implementation, migrations, or endpoint design diverge from this document, the divergence must be reviewed and justified.

---

## Read This With

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/data/db-boundaries.md`
- `docs/architecture/data/schema-governance.md`
- `docs/planning/initial-domain-model.md`

If this document and `initial-domain-model.md` disagree, this document wins.

---

## Core Rule

Project V schema must model only canonical planning and orchestration truth that Project V owns.

Project V must not model:

- canonical observatory truth
- canonical execution truth
- convenience copies of another bounded system's state

The schema must be:

- multi-project-safe
- explicit
- small on purpose
- queryable by real operator workflows
- hard to drift casually

---

## Scope Classification Rule

Every table must be classified as one of:

- **project-scoped**
- **intentionally global**
- **system metadata**

Project-scoped tables must belong to exactly one project.
Global tables must be rare and justified.
System metadata must not become a loophole for project truth.

---

## First-Pass Canonical Tables

## 1. `Project`

### Scope
Project-scoped anchor table for Project V orchestration.

### Purpose
Represents the planning identity of a project inside Project V.

### Required traits
- stable primary key
- stable `key`
- name
- status
- description or summary field
- created / updated timestamps

### Constraints
- `key` must be globally unique inside Project V
- `key` must conform to the governed key format
- no row may be created without the required identifying fields

### Notes
This is Project V's planning anchor, not a full copy of all other system-specific project truth.

---

## 2. `Objective`

### Scope
Project-scoped.

### Purpose
Represents a major outcome a project is pursuing.

### Required traits
- primary key
- `projectId`
- stable per-project `key`
- title
- description
- status
- priority
- horizon or target period fields if needed
- created / updated timestamps

### Constraints
- every row belongs to exactly one project
- uniqueness should be scoped at least to `(projectId, key)`
- reads and writes must enforce project ownership

---

## 3. `Initiative`

### Scope
Project-scoped.

### Purpose
Represents a bounded body of work advancing an objective.

### Required traits
- primary key
- `projectId`
- optional `objectiveId`
- stable per-project `key`
- title
- description
- status
- priority
- target-system or owner-surface classification where appropriate
- created / updated timestamps

### Constraints
- every row belongs to exactly one project
- if `objectiveId` exists, the referenced objective must belong to the same project
- uniqueness should be scoped at least to `(projectId, key)`

---

## 4. `WorkItem`

### Scope
Project-scoped.

### Purpose
Represents a concrete unit of planning or execution-preparation work.

### Required traits
- primary key
- `projectId`
- optional `initiativeId`
- stable per-project `key`
- title
- description
- type
- status
- readiness state
- target-system classification
- blocked summary or blocked flag if needed
- created / updated timestamps

### Constraints
- every row belongs to exactly one project
- if `initiativeId` exists, the referenced initiative must belong to the same project
- uniqueness should be scoped at least to `(projectId, key)`
- target-system classification must use a controlled vocabulary

### Notes
Work items do not become the canonical owner of execution truth.

---

## 5. `Dependency`

### Scope
Project-scoped.

### Purpose
Represents an explicit dependency between Project V records.

### Required traits
- primary key
- `projectId`
- source record reference
- target record reference
- dependency type
- status
- optional rationale or notes
- created / updated timestamps

### Constraints
- source and target must belong to the same project unless an explicitly modeled exception is introduced later
- illegal cross-project dependencies must fail
- duplicate logical dependencies (same source, target, and dependency type within a project) must be prevented; this is enforced by a unique constraint on `(projectId, sourceEntityType, sourceEntityId, targetEntityType, targetEntityId, dependencyType)`

### Notes
Dependencies should not live only in prose.

---

## 6. `DecisionRecord`

### Scope
Project-scoped.

### Purpose
Represents a recoverable planning or orchestration decision.

### Required traits
- primary key
- `projectId`
- optional related entity references
- title
- decision summary
- rationale
- status
- actor or author field
- created timestamp
- updated timestamp

### Constraints
- related referenced entities must belong to the same project where applicable
- important state transitions should have an explicit way to align with decision history when required

### Notes
The `updatedAt` column exists on this table because the governed status transition (`recorded -> superseded`) constitutes a meaningful mutation. The concrete column definition and update rule are specified in `docs/architecture/data/schema-specification.md`.

---

## 7. `ReadinessEvaluation`

### Scope
Project-scoped.

### Purpose
Represents an inspectable evaluation of whether a record is ready to move forward.

### Required traits
- primary key
- `projectId`
- evaluated entity reference
- evaluation type
- result
- rule-package or methodology reference
- summary
- created timestamp

### Constraints
- evaluated entity must belong to the same project
- evaluation must preserve inspectable basis
- repeated evaluation against unchanged inputs should be reproducible

---

## 8. `ReadinessGap`

### Scope
Project-scoped.

### Purpose
Represents a missing condition, blocker, or deficiency produced by a readiness evaluation.

### Required traits
- primary key
- `projectId`
- `readinessEvaluationId`
- severity
- description
- remediation suggestion
- resolved flag or state
- created / updated timestamps

### Constraints
- evaluation and gap must belong to the same project
- orphan gaps must be impossible

---

## 9. `ResearchDoc`

### Scope
Project-scoped.

### Purpose
Represents a planning-support research artifact used by Project V.

### Required traits
- primary key
- `projectId`
- title
- source type
- storage locator or path reference
- status
- summary fields if needed
- created / updated timestamps

### Constraints
- every row belongs to exactly one project
- imported or external provenance should remain visible

### Notes
Research docs support planning truth; they are not observatory truth.

---

## 10. `EvidenceLink`

### Scope
Project-scoped.

### Purpose
Represents a directional link from planning truth to supporting evidence.

### Required traits
- primary key
- `projectId`
- source planning record reference
- evidence type
- target reference or locator
- note
- optional relevance or confidence classification
- created timestamp

### Constraints
- the source planning record must belong to the same project
- evidence links must not overclaim canonical ownership of referenced external truth

---

## 11. `Handoff`

### Scope
Project-scoped.

### Purpose
Represents a bounded transition from Project V into another system or surface.

### Required traits
- primary key
- `projectId`
- source entity reference
- target system classification
- handoff type
- readiness basis summary or reference
- status
- created / completed timestamps

### Constraints
- source entity must belong to the same project
- target system classification must use a controlled vocabulary
- handoffs must not collapse ownership between systems

---

## 12. `StatusHistory`

### Scope
Project-scoped.

### Purpose
Represents recoverable status history for meaningful planning and orchestration state changes.

### Required traits
- primary key
- `projectId`
- entity type
- entity id
- prior status
- new status
- reason or transition summary
- actor or origin field
- created timestamp

### Constraints
- referenced entity must belong to the same project
- state/history alignment must be enforceable by application logic and transaction boundaries
- status history must not exist for a project-scoped entity in another project

### Notes
This table exists because the workflow and invariants require recoverable history around meaningful state changes.

---

## 13. `AuditRun`

### Scope
Project-scoped.

### Purpose
Represents a bounded BYDA-style audit execution against a project-scoped target.

### Required traits
- primary key
- `projectId`
- audit type
- optional target entity reference
- result
- summary
- started / completed timestamps where needed
- created timestamp

### Constraints
- target entity must belong to the same project where a target is present
- audit records remain separate from readiness records
- audit invalidation or staleness behavior must remain explicit rather than assumed

---

## 14. `AuditGap`

### Scope
Project-scoped.

### Purpose
Represents a gap, failure, or deficiency identified during an audit run.

### Required traits
- primary key
- `projectId`
- `auditRunId`
- severity
- description
- remediation guidance
- status
- created / updated timestamps

### Constraints
- linked audit run must belong to the same project
- audit gaps remain separate from readiness gaps

---

## 15. `GitHubLink`

### Scope
Project-scoped.

### Purpose
Represents a bounded GitHub linkage record used for implementation traceability.

### Required traits
- primary key
- `projectId`
- source entity reference
- link type
- URL or external identifier
- optional label or summary
- created timestamp
- updated timestamp where mutation exists

### Constraints
- source entity must belong to the same project
- GitHub linkage remains planning-side traceability, not canonical source-control truth

---

## Possible Global Tables

Global tables must be rare.
The only acceptable early candidates are things like:

- rule packages
- controlled vocabularies
- narrowly scoped system configuration

A global table must justify why project scope would be incorrect.

---

## Required Common Columns

Project-scoped tables should strongly prefer the following where relevant:

- `id`
- `projectId`
- `key` where human-meaningful stable identity helps
- `status`
- `createdAt`
- `updatedAt`

Not every table needs every field, but omission should be deliberate.

---

## Integrity Rules

### 1. No orphaned project-scoped records

A project-scoped row must not exist without a valid project.

### 2. No illegal cross-project relations

If one project-scoped row references another, project compatibility must be enforced.

### 3. Canonical scope must be enforced structurally

Critical integrity should be enforced at the database layer where practical, not only in application logic.

### 4. Uniqueness must match real ownership scope

If a key is unique only within a project, uniqueness must include `projectId`.

### 5. Important state should remain explicit

Do not hide important planning state in vague notes or unstructured metadata.

### 6. Status changes and history must stay aligned

Where a transition requires recoverable history, the status change and history record should be created atomically.

---

## Index Posture

The first-pass schema should be indexed for real multi-project access patterns.

At minimum, consider support for queries like:

- list objectives for a project
- list initiatives for a project
- list open work items for a project
- list blocked work items for a project
- list readiness gaps for a project or initiative
- list handoffs by target system
- list decisions by project and time
- list status history for a project and entity

This implies deliberate indexing on:

- `projectId`
- common status filters
- common relation joins
- common ordering fields
- history lookup fields such as entity type and entity id

---

## Ordering Rule

List surfaces must have deterministic ordering.

The schema should support predictable ordering with stable tie-breakers rather than relying on implicit database behavior.

---

## JSON Rule

JSON may be used only where flexible payload storage is truly justified, such as:

- imported external payload traces
- bounded metadata with genuinely variable shape

JSON must not become a substitute for unresolved schema design.

---

## Freeze Posture

This first-pass schema set should be treated as the governed base.

After approval:

- endpoint design should conform to it
- later schema additions should be exceptional
- schema expansion requires governance review and hammer updates

---

## Companion Implementation Rule

Before implementation begins in earnest, each table above should be converted into a concrete schema specification with:

- exact columns
- exact types
- exact relations
- exact constraints
- exact indexes
- exact allowed mutations

That spec should remain subordinate to this authority doc, not replace it casually.

---

## Final Rule

Project V schema exists to preserve strict planning and orchestration truth for many projects without drift.

If a schema proposal would make the model:

- harder to classify
- less project-safe
- easier to sprawl
- more ambiguous
- less testable

then the proposal is wrong.



