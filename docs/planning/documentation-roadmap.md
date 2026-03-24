# Documentation Roadmap

## Purpose

This document defines how deep Project V documentation should go, in what order it should be written, and where documentation should stop before it turns into speculative noise.

It exists to answer:

```text
How much documentation is enough, what documentation should exist before implementation, and what should be deferred until later?
```

---

## Core Judgment

Writing things down is the correct move for Project V.

It is **not** a bad move unless documentation starts outrunning real architectural decisions, duplicating itself, or inventing detail that the system has not actually earned yet.

For Project V, the correct goal is:

- document enough to prevent drift
- document enough to make LLM-assisted implementation safe
- document enough to make multi-project behavior explicit
- do not document imaginary futures in fake precision

Project V should be **documented deeply where ambiguity is dangerous** and **lightly where uncertainty is still honest**.

---

## Documentation Depth Rule

Project V docs should go deep on anything that could create:

- schema drift
- endpoint drift
- multi-project leakage
- boundary collapse with VEDA or V Forge
- weak readiness logic
- hidden workflow assumptions
- weak hardening posture
- LLM misinterpretation

Project V docs should stay lighter on:

- speculative future capabilities
- UI details that are not yet bounded
- premature performance tuning detail
- implementation internals that are likely to change soon

---

## What Must Be Written Before Real Implementation

These are the minimum documents that should exist before serious route, migration, and hardening work begins.

### 1. Authority and boundary docs

These define what Project V is and what it is not.

Examples:

- `project-v.md`
- `system-invariants.md`
- `multi-project-doctrine.md`
- `db-boundaries.md`
- integration boundary docs

### 2. Governance docs

These prevent the system from turning into spaghetti during implementation.

Examples:

- `schema-governance.md`
- `endpoint-governance.md`
- `api-conventions.md`
- `controlled-vocabularies.md`
- `status-transitions.md`
- `polymorphic-reference-enforcement.md`

### 3. Canonical data docs

These define what the database is allowed to become.

Examples:

- `schema-authority.md`
- `schema-specification.md`

### 4. Operational workflow docs

These define how ideas move through the system.

Examples:

- `project-v-operational-workflow.md`
- `readiness-methodology.md`
- `readiness-evaluation-rules.md`
- `audit-evaluation-rules.md`
- `byda-in-project-v.md`
- `project-v-lifecycle.md`
- `implementation-traceability.md`

### 5. Hardening docs

These define how the system proves it is safe.

Examples:

- `hammer-doctrine.md`
- `hammer-plan.md`

### 6. Endpoint family contracts for the first implementation surface

Examples:

- `projects-api.md`
- `objectives-api.md`
- `initiatives-api.md`
- `work-items-api.md`
- `readiness-api.md`
- `handoffs-api.md`
- `dependencies-api.md`
- `decision-records-api.md`
- `research-docs-api.md`
- `evidence-links-api.md`
- `status-history-api.md`

---

## What Should Be Written Next

After the current authority pack is stable, Project V should continue documentation in the following order.

### Phase 1: BYDA / implementation-traceability / GitHub extension docs

**Status: Complete.**

All Phase 1 docs have been written and are in the active architecture tree:

- `docs/architecture/data/artifact-manifest-model.md` ✓
- `docs/architecture/data/audit-and-gap-model.md` ✓
- `docs/architecture/data/github-linkage-model.md` ✓
- `docs/architecture/integrations/github-integration.md` ✓
- `AuditRun`, `AuditGap`, and `GitHubLink` governed in `schema-authority.md` and `schema-specification.md` ✓

### Phase 1a: AuditRun / AuditGap API endpoint family (next immediate gap)

`controlled-vocabularies.md` explicitly documents that there is **no first-pass API endpoint family** for `AuditRun` and `AuditGap`. These tables exist in the schema and are used by internal audit execution logic, but no read or mutation surface is exposed yet.

This must be added as a governed endpoint family before those surfaces are built. Write it under `docs/api/` as part of the next API documentation pass.

### Phase 2: Implementation-critical notes and runbooks

Still needed or likely needed next:

- polymorphic-reference implementation notes if code-level clarification becomes necessary
- migration workflow runbook
- local setup runbook
- hammer execution runbook
- recovery / reset workflow

Why:

These are the documents that reduce hidden implementation assumptions once the governed pack starts turning into real code.

### Phase 3: Operator-surface docs for the first real interface

Only write these when the surface is real enough to bound.

Examples:

- MCP surface overview
- tool families
- operator workflow surface
- local repo-native workflow docs

Why:

Operator surfaces are where architecture usually gets blurred by convenience.

### Phase 4: Deferred / future-scope docs

Examples:

- advanced search/retrieval inside Project V
- automation patterns
- richer reporting/read models
- future surface expansion

Why:

These should only be documented once they become real enough to govern.

---

## What Should Not Be Written Yet

Do **not** go deep yet on:

- UI pixel-level specs
- speculative dashboards
- speculative agent workflows
- performance docs based on imaginary load patterns
- advanced data pipelines that do not exist yet
- integration contracts for systems not yet bounded

These are the kinds of docs that create fake confidence instead of real control.

---

## Stop Rule

Documentation is deep enough for a given area when all of the following are true:

1. ownership is explicit
2. project scope is explicit
3. allowed mutations are explicit
4. controlled vocabularies are explicit
5. workflow meaning is explicit
6. hardening expectations are explicit
7. implementation would not need to invent core rules

If implementation still has to invent core rules, the docs are not deep enough.

If docs are specifying detail that implementation has not earned or that architecture has not actually decided, the docs are too deep.

---

## Review Pass Rule

Project V documentation should be reviewed in passes.

Recommended pass types:

### 1. Structure pass

Questions:

- does the doc live in the right folder?
- is it authority, planning, research, or operational material?
- is it duplicating another doc?

### 2. Boundary pass

Questions:

- does it preserve Project V ownership?
- does it avoid VEDA / V Forge boundary blur?
- does it stay multi-project-safe?

### 3. Contract pass

Questions:

- are schema rules explicit enough?
- are endpoint rules explicit enough?
- are controlled values and transitions explicit enough?

### 4. Workflow pass

Questions:

- do docs agree on sequencing, readiness, and handoff behavior?
- are correction loops explicit?

### 5. Hardening pass

Questions:

- can hammer tests verify the important claims?
- are failure modes and negative paths considered?

---

## Current Recommendation

For Project V right now, the documentation depth is in the correct range.

The next smart move is not unlimited more documentation.
The next smart move is:

- hold the authority pack steady
- verify the updated pack survives audit cleanly
- move into implementation with targeted runbook and execution-hardening support where needed
- document implementation-sensitive areas only when code would otherwise have to invent rules

That is the balanced path.

---

## Practical Roadmap

### Now

- keep the authority pack stable
- begin implementation against the governed schema and API contracts
- add runbooks where implementation would otherwise invent procedure
- tighten only the small audit findings that remain after review
- avoid reopening settled architecture questions without real implementation pressure

### Next

- decide whether the schema must expand for artifacts, audits, implementation packages, or GitHub linkage
- implement first-pass schema and routes only after that decision is governed
- write runbooks for setup, migrations, and hammer execution
- document implementation-sensitive areas only where code would otherwise have to invent rules

### After first working implementation

- document operator surfaces
- document repo-native workflow
- document failure recovery and maintenance
- document future bounded expansion areas only when they become real

---

## BYDA First-Pass Core and Deferred Enhancements

Project V should keep BYDA strong enough to matter without promoting every possible enhancement immediately.

### First-pass BYDA core

The first-pass BYDA core should now include:

- audit evaluation rules
- audit-readiness coupling
- cross-artifact consistency checks
- ambiguity detection
- explicit staleness / invalidation triggers

### Deferred BYDA enhancements

The following remain planned but intentionally deferred until real hands-on use proves they are needed:

- numerical scoring
- audit profiles
- temporal drift detection
- reverse-audit checks
- gap effort estimation
- dependency mapping between gaps
- richer audit layer hierarchies
- artifact-aware skip logic
- advanced code-diff intelligence
- historical trend views
- supersedence lineage
- audit weighting models

Do not promote these just because they sound sophisticated.
Promote them when the first-pass BYDA core is proven too weak in real use.

---

## Final Rule

Get dangerous ambiguity down on paper.
Do not get imaginary certainty down on paper.

That is the right depth target for Project V.
