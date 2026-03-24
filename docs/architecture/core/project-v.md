# Project V

## Purpose

This document defines the bounded role of Project V in the V Ecosystem.

It exists to answer:

```text
What is Project V, what does it own, what must it never own, and how does it relate to VEDA and V Forge?
```

Project V is the planning and orchestration layer of the V Ecosystem.

---

## Authority

This is a core architecture authority document for Project V.

Read this together with:

- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/db-boundaries.md`
- `docs/planning/carry-forward-from-project-planner.md`

If a proposed change conflicts with this document, this document wins unless superseded by a later architecture decision record.

---

## Core Definition

Project V is the bounded system that owns:

- planning truth
- orchestration truth
- sequencing truth
- readiness truth
- decision and handoff truth

Project V does not own:

- observatory truth
- production artifact truth
- publishing workflow truth

Project V is the place where the ecosystem decides what should happen next, why it should happen, what system should handle it, and what conditions must be true before that work moves forward.

---

## Role Inside the V Ecosystem

The V Ecosystem is intentionally split into three bounded systems:

- **Project V** = planning and orchestration
- **VEDA** = observability and intelligence
- **V Forge** = execution and production

Project V must remain orchestration-focused.
It must not become a copy of VEDA, a shadow of V Forge, or a generic storage dump for cross-system convenience.

The core ecosystem loop is:

```text
Project V -> decides and sequences
VEDA      -> observes and informs
V Forge   -> executes and produces
```

Project V is responsible for keeping that loop coherent without swallowing the other systems.

---

## What Project V Owns

Project V owns the bounded records and logic needed to move work from ambiguity toward deliberate action.

That includes:

- project definitions relevant to planning and orchestration
- objectives and initiatives
- sequencing and dependency structure
- work decomposition and readiness framing
- planning documents and specification packages
- research-to-plan traceability
- decision records and rationale
- gating outcomes and audit results
- cross-system handoff records
- operator-visible orchestration state

Project V may store derived summaries and planning support artifacts where those artifacts help orchestration and review.

---

## What Project V Does Not Own

Project V does not own external observed reality.
That belongs in VEDA.

Project V does not own produced outputs or execution workflow.
That belongs in V Forge.

Project V must not own:

- SERP snapshots
- GA4 observations
- Search Console observations
- crawl/indexation observations
- YouTube observations
- LLM citation observations
- source-feed observatory truth
- drafts
- editorial workflow
- publishing workflow
- produced assets
- distribution execution state

If a feature is primarily about observed external reality, it belongs in VEDA.
If a feature is primarily about making, revising, approving, or publishing outputs, it belongs in V Forge.

---

## Primary Questions Project V Answers

Project V should answer questions like:

- what are we trying to accomplish?
- what initiative should move next?
- what is blocked?
- what evidence supports the current direction?
- what is ready for execution?
- what system should handle the next bounded step?
- what decision was made, and why?
- what handoff should occur next?

Project V should not answer questions that require it to impersonate VEDA or V Forge truth.

---

## Planning Posture

Project V is documentation-first and audit-friendly.

That means:

- planning should be explicit
- readiness should be inspectable
- rationale should be recoverable
- handoffs should be visible
- operator and LLM assistance should work from bounded, documented system truth

Project V should favor boring, explicit structures over hidden workflow magic.

---

## Relationship to Research

Project V may own research materials that support planning and orchestration.

That includes:

- research briefs
- source-grounded notes
- comparative analysis
- requirement extraction
- traceability between evidence and planning decisions

Research inside Project V is planning support truth, not observatory truth.
Project V may reference VEDA observations, but VEDA remains the owner of those observations.

---

## Relationship to Readiness and Audit

Project V is the correct home for readiness evaluation and audit-style gating.

That includes:

- plan readiness
- specification completeness
- dependency visibility
- implementation readiness
- explicit gaps and blockers

Project V may inherit and adapt the useful parts of Project Planner's readiness methodology, but those capabilities must be rebound to Project V's bounded ownership.

---

## Relationship to VEDA

Project V consumes VEDA signals.
It does not own them.

Project V may:

- request observability context
- reference VEDA entities in planning and handoff records
- use VEDA evidence to support prioritization and decisions

Project V must not:

- directly own observatory state
- duplicate VEDA canonical records as active truth
- mutate VEDA data except through explicit bounded interfaces where appropriate

---

## Relationship to V Forge

Project V directs work toward V Forge.
It does not own V Forge execution truth.

Project V may:

- record intended handoffs
- specify execution-ready work packages
- track whether work is blocked, ready, in handoff, or complete from an orchestration perspective

Project V must not:

- become the system of record for draft state
- own editorial workflow
- own publish-state transitions
- absorb asset lifecycle logic

---

## Database Posture

Project V should have its own database within the shared Postgres cluster.

The baseline ecosystem posture is:

- `project_v` database for Project V
- `veda` database for VEDA
- `v_forge` database for V Forge

This keeps infrastructure reasonably simple while preserving bounded ownership and LLM-readable system shape.

---

## Design Principle

Project V should be easy for both humans and LLMs to reason about.

That requires:

- explicit boundaries
- stable naming
- low-ambiguity records
- deterministic behavior where practical
- visible ownership at every interface

In practice, Project V should be easier to understand than a generic project management system because it is not trying to be a generic project management system.
It is a bounded orchestration system inside the V Ecosystem.

---

## Non-Goals

Project V is not:

- an observability warehouse
- a publishing system
- an asset manager
- a general-purpose analytics system
- a background automation blob
- a substitute for VEDA
- a substitute for V Forge

If a proposed capability pushes Project V toward those shapes, that is an architectural warning sign.

---

## Maintenance Rule

When a new feature is proposed, classify it before implementing it.

Ask:

```text
Is this planning truth, observatory truth, or execution truth?
```

If it is planning or orchestration truth, it may belong in Project V.
If it is observatory truth, it belongs in VEDA.
If it is execution or production truth, it belongs in V Forge.

Project V should remain orchestration-focused.
That boundary is intentional and must be preserved.
