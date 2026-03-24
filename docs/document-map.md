# Document Map

## Purpose

This document maps **where documentation belongs** in the Project V repo.

It exists to answer:

```text
If I am writing or looking for a document, where should it live?
```

This is a navigation and placement guide.
It is not the primary authority for naming rules.
For naming and structure rules, see:

- `docs/standards/documentation-rules.md`

---

## Core Rule

Put a document in the folder that matches its **primary purpose**, not the folder that feels close enough.

If a document mixes multiple purposes, split it.

---

## Top-Level Map

```text
docs/
├─ README.md
├─ document-map.md
├─ standards/
├─ architecture/
├─ planning/
├─ research/
├─ api/
├─ runbooks/
├─ glossary/
└─ archive/
```

---

## Folder-by-Folder Map

### `docs/`
Use this level for:

- top-level navigation docs
- documentation-wide standards
- maps that explain the full doc tree

Examples:

- `docs/README.md`
- `docs/document-map.md`

Do not use this level for system-specific architecture docs unless the file truly governs the whole documentation tree.

---

### `docs/standards/`
Use this folder for documentation rules and conventions.

Belongs here:

- naming rules
- writing rules
- template rules
- structural rules
- archive rules
- documentation maintenance rules

Examples:

- `documentation-rules.md`
- `doc-template.md`
- `archive-policy.md`

Does not belong here:

- Project V architecture truth
- implementation plans
- system integration docs

---

### `docs/architecture/`
Use this folder for **active architecture truth**.

Belongs here:

- system boundaries
- ownership rules
- invariants
- persistence model docs
- integration boundary docs
- operator surface architecture
- architecture decision records

If a document answers:

- what Project V is
- what Project V owns
- what Project V must not own
- how bounded parts fit together

it probably belongs under `architecture/`.

#### `docs/architecture/core/`
Use for highest-authority core system docs.

Belongs here:

- system purpose
- ownership
- invariants
- lifecycle framing
- system boundary docs

Examples:

- `project-v.md`
- `system-invariants.md`
- `system-boundaries.md`
- `orchestration-lifecycle.md`

#### `docs/architecture/data/`
Use for persistence and state-model docs.

Belongs here:

- database boundaries
- schema guides
- entity model docs
- event model docs
- projection/read-model docs
- migration policy docs

Examples:

- `db-boundaries.md`
- `initial-domain-model.md`
- `event-model.md`
- `migration-policy.md`

#### `docs/architecture/integrations/`
Use for cross-system and external integration docs.

Belongs here:

- VEDA integration boundaries
- V Forge integration boundaries
- GitHub integration docs
- MCP integration docs
- external provider boundary docs

Examples:

- `veda-integration.md`
- `v-forge-integration.md`
- `github-integration.md`
- `project-v-mcp-surface.md`

#### `docs/architecture/operator-surfaces/`
Use for operator-facing surface architecture.

Belongs here:

- editor surface docs
- CLI surface docs
- local operator workflow surface docs
- other native operator experiences that expose Project V truth without owning it

Examples:

- `project-v-vscode-extension.md`
- `cli-surface.md`
- `local-operator-workflow.md`

#### `docs/architecture/decisions/`
Use for architecture decision records only.

Belongs here:

- immutable decision records
- choices that were made at a point in time
- superseded decisions kept for history

Examples:

- `ADR-0001-separate-databases-per-system.md`
- `ADR-0002-project-v-doc-structure.md`

---

### `docs/planning/`
Use this folder for active planning and sequencing material.

Belongs here:

- roadmaps
- phased plans
- carry-forward analysis
- implementation plans
- work breakdown docs
- readiness/gap analysis
- deferred judgment tracking
- repo audit follow-up lists

Examples:

- `roadmap.md`
- `carry-forward-from-project-planner.md`
- `phase-1-plan.md`
- `implementation-sequencing.md`
- `repo-audit/deferred-judgments.md`

Does not belong here:

- permanent architecture truth
- raw research notes
- runbooks

---

### `docs/research/`
Use this folder for source-grounded exploration and analysis.

Belongs here:

- research packages
- comparative analysis
- exploratory notes
- source summaries
- evidence collections

Examples:

- `project-planner-analysis.md`
- `github-project-management-patterns.md`
- `llm-orchestration-research.md`

Research may inform architecture and planning, but research docs are not architecture authority by default.

---

### `docs/api/`
Use this folder for API surface documentation.

Belongs here:

- endpoint family overviews
- contract docs
- validation docs
- request/response shape docs
- API behavior rules

Examples:

- `api-contract-principles.md`
- `validation-and-error-taxonomy.md`
- `work-items-api.md`

Does not belong here:

- database internals unless the API contract directly depends on them
- general architecture docs that are not API-specific

---

### `docs/runbooks/`
Use this folder for repeatable operational procedures.

Belongs here:

- local setup
- DB bootstrap
- migration workflow
- backup/restore
- recovery procedures
- release steps

Examples:

- `local-setup.md`
- `database-bootstrap.md`
- `migration-workflow.md`
- `disaster-recovery.md`

Runbooks describe how to do something operationally.
They are not architecture authority unless explicitly referenced by an authority doc.

---

### `docs/glossary/`
Use this folder for canonical terminology.

Belongs here:

- stable term definitions
- naming disambiguation
- canonical vocabulary

Examples:

- `core-terms.md`
- `system-vocabulary.md`

This folder helps keep prompts, docs, and code language aligned.

---

### `docs/archive/`
Use this folder for retired but preserved documentation.

Belongs here:

- superseded docs
- legacy planning docs
- retired architecture docs kept for provenance
- historical notes that should not be treated as active truth

Examples:

- `legacy-project-planner-notes.md`
- `old-roadmap.md`

Archive docs should include a note explaining:

- that they are archived
- what replaced them, if anything

---

## Quick Placement Rules

### Put the doc in `architecture/` if it explains:

- system truth
- ownership
- invariants
- boundaries
- persistence shape
- integration architecture
- operator surface architecture

### Put the doc in `planning/` if it explains:

- what to do next
- phases
- sequencing
- implementation scope
- carry-forward decisions
- deferred follow-up work

### Put the doc in `research/` if it explains:

- what was investigated
- what sources were reviewed
- what evidence was found
- what options were compared

### Put the doc in `api/` if it explains:

- routes
- contracts
- validation behavior
- request/response surfaces

### Put the doc in `runbooks/` if it explains:

- how to execute an operational procedure
- how to recover something
- how to bootstrap or maintain an environment

---

## Canonical Starter Docs

These are the first high-value docs that should exist in this tree:

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/db-boundaries.md`
- `docs/architecture/integrations/project-v-mcp-surface.md`
- `docs/architecture/operator-surfaces/project-v-vscode-extension.md`
- `docs/planning/carry-forward-from-project-planner.md`
- `docs/planning/initial-domain-model.md`
- `docs/planning/repo-audit/deferred-judgments.md`

---

## Final Rule

When choosing where a doc goes, ask:

```text
What is this document primarily for?
```

Then place it in the folder that matches that answer exactly.

When in doubt, choose the location that is:

- more explicit
- more stable
- less ambiguous
- easier for humans and LLMs to retrieve
