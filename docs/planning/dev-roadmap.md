# Project V Development Roadmap

## Status

Project V is in pre-implementation phase.

- Architecture: complete
- Data authority: complete
- API contracts: defined
- Hammer doctrine: defined
- Implementation: not started

---

## Purpose

This roadmap defines the governed development path for Project V.

It exists to ensure:

- implementation follows architectural authority
- hammer coverage is built alongside features
- no uncontrolled system drift occurs
- LLM-driven development remains deterministic and auditable

---

## Authority Rule

If any implementation, roadmap step, or generated code conflicts with architecture or data authority documents:

THE DOCUMENTS WIN.

---

## Required Reading (In Order)

### Core Architecture
- docs/architecture/core/project-v.md
- docs/architecture/core/system-invariants.md
- docs/architecture/core/multi-project-doctrine.md
- docs/architecture/core/readiness-methodology.md
- docs/architecture/core/readiness-evaluation-rules.md
- docs/architecture/core/audit-evaluation-rules.md

### Data Authority
- docs/architecture/data/schema-authority.md
- docs/architecture/data/schema-specification.md
- docs/architecture/data/controlled-vocabularies.md
- docs/architecture/data/status-transitions.md
- docs/architecture/data/polymorphic-reference-enforcement.md
- docs/architecture/data/audit-and-gap-model.md

### API Governance
- docs/api/api-conventions.md
- docs/api/endpoint-governance.md
- All endpoint family docs listed in docs/api/endpoint-governance.md

### Testing Doctrine
- docs/architecture/testing/hammer-doctrine.md
- docs/architecture/testing/hammer-plan.md
- docs/architecture/testing/hammer-coverage-map.md

---

## Definition of Done

Project V is operational when:

- canonical schema is implemented and enforced
- all status transitions are governed and atomic
- mutation boundaries are enforced
- readiness is server-computed and reproducible
- audit constrains readiness correctly
- hammer suite is modular, complete, and passing
- no cross-project leakage exists
- no schema drift exists
- no hidden business logic exists in routes

---

# Implementation Phases

## Phase 0 — Foundation

### Goal
Establish schema and enforcement layer before any feature logic.

### 0.1 Migration 001

Implement all canonical tables defined in:

- docs/architecture/data/schema-authority.md
- docs/architecture/data/schema-specification.md

Rules:

- no schema deviation
- no additions
- no omissions

### 0.2 Shared Enforcement Layer

Required components:

- project scope enforcement
- mutation validator
- controlled vocabulary registry (must enforce docs/architecture/data/controlled-vocabularies.md)
- transition validator (must enforce docs/architecture/data/status-transitions.md)
- polymorphic reference enforcement (must enforce docs/architecture/data/polymorphic-reference-enforcement.md)
- transaction helper

### 0.3 Hammer Core Setup

Directory structure:

/hammer/
  core/
  entities/
  readiness/
  audit/
  integration/
  coordinator/

Each hammer module is a single file named `hammer-<bounded-concern>.ts` (or `.js`).

### Phase 0 Hammer Modules

- hammer-scope-isolation
- hammer-mutation
- hammer-vocabulary
- hammer-transitions
- hammer-transaction-rollback
- hammer-polymorphic-references

---

## Phase 1 — Core Entities

### Entities

- Project
- Objective
- Initiative
- WorkItem

### Rules

- strict project isolation
- governed status transitions
- no readiness logic yet
- no audit logic yet

### Hammer

- hammer-core-projects
- hammer-core-objectives
- hammer-core-initiatives
- hammer-core-work-items

---

## Phase 2 — Dependencies, Decisions, History

### Entities

- Dependency
- DecisionRecord
- StatusHistory
- ResearchDoc

### Rules

- same-project enforcement
- atomic state/history alignment
- decision traceability enforced (including recorded -> superseded transition with StatusHistory)

### Hammer

- hammer-dependencies
- hammer-decisions (must include decision supersedence + StatusHistory atomicity)
- hammer-state-transitions
- hammer-history-integrity

---

## Phase 3 — Readiness System

### Entities

- ReadinessEvaluation
- ReadinessGap

### Rules

- server-computed
- reproducible
- produces gaps
- updates readiness state atomically
- must include audit-coupling awareness per docs/architecture/core/readiness-evaluation-rules.md

### Hammer

- hammer-readiness-core
- hammer-readiness-gaps
- hammer-readiness-reproducibility

---

## Phase 4 — Audit (BYDA)

### Entities

- AuditRun
- AuditGap

### Rules

- server-computed
- detects contradictions and ambiguity
- enforces readiness coupling

### Hammer

- hammer-audits
- hammer-audit-gaps
- hammer-audit-readiness-coupling
- hammer-cross-artifact-consistency
- hammer-ambiguity-detection

---

## Phase 5 — Integration Layer

### Entities

- Handoff
- EvidenceLink
- GitHubLink

### Rules

- explicit cross-system boundaries
- no ownership leakage
- preserved provenance

### Hammer

- hammer-handoffs
- hammer-evidence-links
- hammer-cross-system-references
- hammer-boundary-enforcement

---

## Phase 6 — API Hardening

### Goals

- strict validation
- deterministic responses
- exact error handling

### Hammer

- hammer-contracts-read
- hammer-contracts-write
- hammer-validation
- hammer-ordering

---

## Phase 7 — Full System Validation

### Goal

Run full hammer suite as regression gate.

### Hammer

- hammer-coordinator

---

## Hammer Design Rules

- one module per bounded concern
- no large monolithic test scripts
- modules must be independently runnable

Each module must define:

- invariant tested
- setup
- valid path
- invalid path
- pass criteria

Concurrency probes are required per docs/architecture/testing/hammer-doctrine.md for:

- status transitions
- dependency creation
- readiness evaluation
- project-scoped unique key creation

---

## Claude Workflow

Development loop:

1. select phase
2. generate Claude prompt
3. Claude produces code
4. review against authority docs
5. run hammer
6. approve or reject

---

## GitHub Steward Rules

- enforce clean structure
- prevent duplicate logic
- align commits to roadmap phases
- maintain LLM readability

---

## Non-Negotiable Rules

- no schema drift
- no skipping hammer
- no hidden logic
- no cross-project leakage
- no uncontrolled transitions

---

## Final Rule

Project V is not complete when it works once.

Project V is complete when it survives the hammer repeatedly under valid and invalid conditions.
