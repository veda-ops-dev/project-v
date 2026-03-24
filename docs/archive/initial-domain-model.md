# Initial Domain Model

> **ARCHIVED** — This document has been superseded by `docs/architecture/data/schema-authority.md` and `docs/architecture/data/schema-specification.md`.
> If this document and the schema-authority doc disagree, schema-authority wins.
> Do not treat this as active planning truth.

## Purpose

This document defines the first-pass domain model for Project V.

It exists to answer:

```text
What are the primary records Project V likely needs in order to own planning and orchestration truth cleanly?
```

This is an initial framing document, not a final schema spec.

---

## Core Modeling Principle

Project V should model planning and orchestration truth explicitly.

That means it should represent:

- what is being pursued
- how work is grouped
- what is blocked
- what is ready
- what depends on what
- what decision was made
- what system should handle the next step
- what audit was run
- what audit gap exists
- what GitHub linkage supports implementation traceability

It should not model observatory truth or production artifact truth as canonical Project V data.

---

## Primary Entities

### `Project`

A bounded orchestration anchor for a project inside Project V.

This record should represent the planning identity of a project, not a full copy of every other system's project truth.

Likely fields:

- stable identifier
- key
- name
- status
- description
- created / updated timestamps

### `Objective`

A major outcome the project is trying to achieve.

Likely fields:

- project reference
- title
- description
- status
- priority
- target horizon

### `Initiative`

A bounded body of work that advances an objective.

Likely fields:

- project reference
- objective reference
- title
- description
- status
- priority
- owner surface or owning system target

### `WorkItem`

A concrete unit of planning or execution-preparation work.

Likely fields:

- initiative reference
- title
- description
- status
- type
- readiness state
- blocked flag or block summary
- target system classification

### `Dependency`

An explicit relationship showing that one record depends on another.

Likely fields:

- source record reference
- target record reference
- dependency type
- status
- note or rationale

### `DecisionRecord`

A recoverable record of a significant planning or orchestration decision.

Likely fields:

- related project / objective / initiative / work item
- title
- decision summary
- rationale
- status
- created timestamp
- author or actor

### `ReadinessEvaluation`

A bounded evaluation of whether a record is ready to move forward.

Likely fields:

- evaluated record reference
- evaluation type
- result
- rule package or methodology reference
- summary
- created timestamp

### `ReadinessGap`

A missing condition, blocker, or deficiency identified during readiness evaluation.

Likely fields:

- readiness evaluation reference
- severity
- description
- remediation suggestion
- resolved flag

### `ResearchDoc`

A planning-support research artifact used inside Project V.

Likely fields:

- project reference
- title
- source type
- path or storage locator
- status
- summary fields

### `EvidenceLink`

A directional link from planning truth to supporting evidence.

Likely fields:

- source planning record reference
- evidence type
- target reference or locator
- note
- confidence or relevance classification

### `Handoff`

A record that formalizes a planned transition from Project V into another bounded system or surface.

Likely fields:

- source record reference
- target system
- handoff type
- readiness basis
- status
- created / completed timestamps

### `StatusHistory`

A recoverable record of meaningful lifecycle status transitions.

Likely fields:

- entity type
- entity id
- previous status
- new status
- reason
- actor
- created timestamp

### `AuditRun`

A BYDA-style audit execution against a project-scoped target.

Likely fields:

- target reference
- audit type
- result
- summary
- started / completed timestamps

### `AuditGap`

A recoverable audit deficiency or failure.

Likely fields:

- audit reference
- severity
- description
- remediation
- status

### `GitHubLink`

A bounded GitHub linkage record for implementation traceability.

Likely fields:

- source entity reference
- link type
- URL or external id
- label
- created / updated timestamps where mutation exists

---

## Supporting Concepts

Project V will likely also need supporting concepts such as:

- audit-required gate mapping
- technology declarations
- planning summaries
- import metadata for referenced external material
- future artifact manifests if later promoted
- future drift-finding records if later promoted

These should support the core domain rather than replace it.

---

## Domain Rules

### 1. Objectives organize direction

Objectives define meaningful outcomes.
They should not be used as generic catch-all containers.

### 2. Initiatives group bounded work

Initiatives should sit between objectives and work items where that grouping improves clarity.

### 3. Work items are execution-preparation units, not execution truth

A work item may describe what should happen next.
It should not become the canonical owner of execution state that belongs in V Forge.

### 4. Dependencies must be explicit

Important sequencing should not live only in prose.

### 5. Decisions must be recoverable

If a choice matters, it should be recordable and explainable later.

### 6. Readiness must be inspectable

A readiness result without visible basis is not trustworthy.

### 7. Audits must remain separate from readiness

Audit and readiness should reinforce one another without collapsing into the same record family.

### 8. Handoffs must stay bounded

A handoff records a transition of responsibility.
It does not collapse ownership between systems.

### 9. GitHub linkage remains traceability, not code ownership

GitHub linkage belongs in Project V only as bounded planning-side traceability.

---

## Relationship to Other Systems

### Relationship to VEDA

Project V may reference VEDA entities or observations through evidence links and planning records.
VEDA remains the canonical owner of observatory truth.

### Relationship to V Forge

Project V may create handoff records or execution-ready packages intended for V Forge.
V Forge remains the canonical owner of execution and production truth.

---

## Likely First-Pass Modeling Sequence

A practical first-pass build order is:

1. `Project`
2. `Objective`
3. `Initiative`
4. `WorkItem`
5. `Dependency`
6. `DecisionRecord`
7. `ReadinessEvaluation`
8. `ReadinessGap`
9. `ResearchDoc`
10. `EvidenceLink`
11. `Handoff`
12. `StatusHistory`
13. `AuditRun`
14. `AuditGap`
15. `GitHubLink`

---

## Final Rule

This document is only the first-pass domain-model frame.

If it disagrees with the governed schema authority or schema specification, those stricter docs win.
