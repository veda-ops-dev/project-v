# Multi-Project Doctrine

## Purpose

This document defines how Project V must behave as a strict multi-project system.

It exists to answer:

```text
What rules must Project V follow so it can safely support 100+ projects without cross-project drift, schema sloppiness, or orchestration confusion?
```

Project V is not being built for a single-project toy environment.
It must be designed from the start for many concurrent projects with clean isolation, predictable retrieval, and durable governance.

---

## Core Judgment

Project V must be **multi-project by structure**, not multi-project by convention.

That means:

- project scoping must be explicit
- project ownership must be enforced
- canonical records must not drift across projects
- schema and endpoint growth must be controlled
- retrieval must remain deterministic as project count grows

A system that works for 3 projects through operator memory but breaks at 100 is not acceptable.

---

## Multi-Project Rule

Every Project V record must be classified as one of the following:

- **project-scoped**
- **intentionally global**
- **system metadata**

Project-scoped records must belong to exactly one project.
Global records must be rare and justified.
System metadata must not become a hidden dumping ground for project truth.

---

## Project Scope Invariants

### 1. Project-scoped rows must belong to exactly one project

Any record representing planning or orchestration truth for a project must belong to exactly one Project V project anchor.

Examples include:

- objectives
- initiatives
- work items
- dependencies
- decision records
- readiness evaluations
- readiness gaps
- research documents
- evidence links
- handoffs

No project-scoped row may exist without a project.

### 2. Global rows must be rare and explicit

A row should only be global if its global nature is intentional, documented, and necessary.

Examples of possible global records:

- rule packages
- system configuration
- shared taxonomies used across projects

Global rows must not become a convenience loophole for avoiding proper project scoping.

### 3. Reads must enforce scope

Project-scoped reads must resolve project context explicitly.

Reading by UUID alone is not enough.
If a row exists but belongs to another project, the read must behave as though it is unavailable.

No cross-project existence leakage is allowed by default.

### 4. Writes must require explicit project context

Any write that touches project-scoped truth must require explicit project context.

Silent fallback for mutations is forbidden.
Implicit project inference is dangerous at 100+ projects.

### 5. Cross-project contamination must fail

Any attempt to connect records across unrelated projects where the domain does not explicitly allow it must fail.

Examples:

- linking a work item in one project to a readiness record from another project
- attaching evidence to the wrong project-owned record
- creating dependencies across projects without explicit modeled support

---

## Modeling Rules for Scale

### 1. Canonical keys must remain stable inside project scope

If a record has a human-meaningful identity surface such as a key, slug, or code, that identifier should be stable and unique within the intended scope.

Examples:

- `Project.key`
- `Objective.projectId + key`
- `Initiative.projectId + key`
- `WorkItem.projectId + key`

### 2. Do not rely on prose for important structure

At 100+ projects, structure must be queryable.

Dependencies, readiness, ownership, handoff targets, and classification should not live only in freeform notes.

### 3. Separate canonical truth from derived convenience

Derived summaries, synthesized context, and convenience indexes may exist.
They must not replace canonical project-scoped records.

### 4. Status and history should be inspectable

As project volume grows, debugging depends on being able to answer:

- what changed
- when it changed
- why it changed
- which project it belonged to

---

## Query and Indexing Posture

Project V should be modeled so common project-scoped queries remain efficient and obvious.

Typical access patterns should be supported intentionally, such as:

- list initiatives for a project
- list open work items for a project
- list blocked items for a project
- fetch readiness gaps for a project or initiative
- fetch decision history for a project
- fetch handoffs targeting a specific system

This implies:

- projectId should be present where ownership matters
- indexes should reflect real query patterns
- uniqueness rules should match actual ownership scope
- ordering should include stable tie-breakers

---

## Operator Surface Rules

At 100+ projects, operator surfaces must not depend on memory or hidden defaults.

That means:

- current project context should be visible
- cross-project views should be explicit
- mutation surfaces should require unambiguous target project selection
- ambiguous operator actions should fail safely

LLM-assisted surfaces should not guess project ownership when multiple plausible targets exist.

---

## Schema Governance for Multi-Project Safety

Project count growth magnifies schema mistakes.

Therefore:

- new tables must classify scope explicitly
- new uniqueness rules must match real ownership scope
- new relations must be checked for cross-project contamination risk
- new JSON fields must not become schema escape hatches
- schema changes must go through governance review before adoption

See:

- `docs/architecture/data/schema-governance.md`

---

## Endpoint Governance for Multi-Project Safety

API growth must also stay controlled.

Therefore:

- new endpoints must justify their bounded purpose
- project scope behavior must be explicit in the contract
- list endpoints must define deterministic ordering
- mutation endpoints must define explicit project requirements

See:

- `docs/api/endpoint-governance.md`

---

## Hammer Requirements

Multi-project claims are not trustworthy until they are hammered.

Project V hammer coverage should include probes for:

- cross-project read leakage
- cross-project write leakage
- orphaned project-scoped records
- illegal cross-project relationships
- nondeterministic ordering under larger project populations
- invalid uniqueness behavior inside and across project scope

See:

- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`

---

## Non-Goals

Project V should not attempt to fake scale through:

- undocumented fallback behavior
- overly broad global tables
- schema shortcuts that skip explicit ownership
- endpoint sprawl used to patch weak modeling
- hidden operator assumptions about the current project

These shortcuts become failure multipliers at 100+ projects.

---

## Final Rule

Project V must treat multi-project discipline as a first-order architectural constraint.

Not later.
Not after the MVP.
Not once the data gets messy.

Project scoping, schema governance, endpoint governance, and hammer coverage must all be designed for 100+ projects from the beginning.
