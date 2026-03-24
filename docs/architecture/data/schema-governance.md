# Schema Governance

## Purpose

This document defines the rules for Project V schema design and schema change.

It exists to answer:

```text
How do we keep the Project V database strict, multi-project-safe, and protected from schema drift during development?
```

---

## Core Judgment

Project V should not grow its schema casually during implementation.

The schema should be treated as governed architecture.
Not as a scratchpad for whatever field feels convenient during the current coding session.

Once the initial schema direction is approved, further schema changes should be rare, justified, documented, reviewed, and hammered.

---

## Primary Rule

No schema addition is allowed merely because it makes the next feature easier.

A schema change must justify:

- why the data belongs in Project V
- why the shape is canonical rather than derived
- why existing tables and fields are insufficient
- how the change preserves multi-project integrity
- what query pattern or invariant requires it

If that justification is weak, the change should not happen.

---

## Schema Design Principles

### 1. Model canonical truth explicitly

If Project V owns a concept canonically, model it clearly.

Prefer:

- explicit tables
- explicit columns
- explicit relations
- explicit status fields

Avoid using JSON as a lazy substitute for real modeling.

### 2. Keep the model small on purpose

A smaller explicit schema is better than a sprawling speculative schema.

Do not add tables or columns for imagined future possibilities unless the need is clear and durable.

### 3. Multi-project scope must be visible in the schema

Every project-scoped table must make project ownership obvious and enforceable.

Project scope must not be implied only at the application layer.

### 4. Uniqueness must match real scope

Uniqueness constraints must reflect actual ownership scope.

If a value is unique only within a project, the uniqueness rule should include project scope.

Global uniqueness should be rare and intentional.

### 5. State should be inspectable

Important orchestration state should not hide in vague text blobs or unstructured metadata.

### 6. Derived convenience data must stay secondary

If something can be deterministically re-derived from canonical truth, be careful about storing it as first-class state.

Stored derivations create drift risk.

---

## Key Format Rule

Project V keys should use one governed shape for readability and consistency.

First-pass key format:

- lowercase ASCII letters and digits
- internal separators may use single hyphens
- no spaces
- no underscores
- no leading or trailing hyphen
- length should remain within a bounded range such as `3..64`

Recommended regex:

```text
^[a-z0-9]+(?:-[a-z0-9]+)*$
```

This rule applies to:

- `Project.key`
- per-project keys such as `Objective.key`, `Initiative.key`, and `WorkItem.key`

---

## `updatedAt` Maintenance Rule

Where a first-pass canonical table has an `updatedAt` column, Project V should maintain that column through the application/service mutation path in the same transaction as the governed write.

The first-pass posture does **not** depend on database triggers for `updatedAt`.

This keeps mutation behavior explicit and easier to reason about during early implementation and hammering.

---

## Schema Change Gate

A schema change should only be allowed when all of the following exist:

1. **clear bounded ownership**
2. **written justification**
3. **updated architecture docs if needed**
4. **migration plan**
5. **hammer coverage or hammer updates**
6. **query/index impact considered**
7. **multi-project contamination risk reviewed**

If one of these is missing, the change is not ready.

---

## Required Questions for Every Schema Change

Before adding or changing schema, answer these questions explicitly:

### Ownership

- Does this truth belong in Project V?
- Is it planning truth or orchestration truth rather than observatory or execution truth?

### Canonical status

- Is this canonical state or derived convenience state?
- If derived, why should it be stored?

### Scope

- Is this project-scoped, global, or system metadata?
- How is that scope enforced?

### Cardinality and integrity

- What relations does it create?
- What illegal cross-project connections must be prevented?
- What orphan risks exist?

### Query shape

- What real query pattern needs this shape?
- What indexes are needed?
- What ordering rules depend on it?

### Mutation behavior

- What writes create or update this record?
- What transaction boundaries are required?
- What rollback behavior matters?

If the answers are vague, the schema change is not ready.

---

## Anti-Drift Rules

### 1. No ad hoc field additions during route implementation

Do not add columns just because a route or screen would be easier to finish that way.

Implementation should conform to the governed model.
The model should not be bent casually around implementation convenience.

### 2. No JSON escape hatches for unresolved modeling

A JSON field may exist where evidence, import payloads, or flexible metadata are truly appropriate.

It must not become the hiding place for unfinished schema thinking.

### 3. No duplicate concepts under different names

Do not create overlapping tables or fields that model the same thing slightly differently.

That is the beginning of spaghetti.

### 4. No premature convenience tables

Do not add cached or denormalized tables unless there is a proven reason.

### 5. No silent broadening of scope

A project-scoped concept must not quietly drift toward global behavior without explicit review and documentation.

---

## Schema Freeze Posture

Project V should adopt a practical schema freeze posture after the initial domain model is approved.

That means:

- the core table set is chosen intentionally
- endpoint design conforms to that model
- later additions are exceptional, not routine
- schema evolution is governed, not casual

This does not mean the schema can never change.
It means schema change becomes a controlled architectural event instead of a habit.

---

## Recommended First-Pass Canonical Tables

The first-pass Project V schema currently includes fifteen canonical tables:

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
- AuditRun
- AuditGap
- GitHubLink

This set should be stressed and hammered before major expansion.

---

## Index and Constraint Posture

The schema should be designed for real multi-project access patterns.

That implies:

- indexes on `projectId` where appropriate
- composite uniqueness where scope requires it
- explicit foreign keys where integrity matters
- ordering support for common list surfaces
- rejection of orphaned records and illegal cross-project relations

The database should help enforce structure.
The application should not carry that burden alone.

---

## Required Companion Updates

When an approved schema change occurs, update the relevant docs as needed:

- `docs/architecture/core/system-invariants.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/data/db-boundaries.md`
- `docs/planning/initial-domain-model.md`
- hammer planning docs

If the docs are not updated, the system truth is drifting.

---

## Final Rule

Treat the Project V schema as a governed contract.

If a change would make the schema:

- broader without stronger justification
- more ambiguous
- less multi-project-safe
- harder to test
- easier to drift

then the change is wrong.
