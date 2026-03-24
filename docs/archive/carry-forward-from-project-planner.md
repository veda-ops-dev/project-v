# Carry Forward From Project Planner

> **ARCHIVED** — This document has served its purpose.
> The principles it captured are now absorbed into `docs/architecture/core/project-v.md`, `docs/architecture/core/system-invariants.md`, and `docs/architecture/core/multi-project-doctrine.md`.
> Do not treat this as active planning guidance.

## Purpose

This document maps what should be carried from Project Planner into Project V.

It exists to answer:

```text
What should Project V keep, reshape, or reject from Project Planner now that Project V is part of the V Ecosystem?
```

---

## Core Judgment

Project Planner is the direct predecessor to Project V.

Project V should keep the strongest parts of Project Planner's planning and readiness brain, but it must discard the assumption that one system should own all project truth.

Project V is not a standalone everything-system.
It is the bounded planning and orchestration layer of the V Ecosystem.

That means the carry-forward posture is:

- keep what supports planning and orchestration
- reshape what assumed broader ownership
- reject what belongs in VEDA or V Forge

---

## Keep

### Documentation-first planning posture

Keep the strong emphasis on explicit documents, inspectable planning state, and clear specification packages.

### Readiness and audit mindset

Keep the readiness-gate posture and the idea that implementation should not proceed from vague or under-specified plans.

### Research-to-task traceability

Keep the ability to link research, notes, evidence, and planning decisions.

### Deterministic context assembly

Keep the bias toward assembling bounded, inspectable context for operators and LLMs.

### Phase and sequencing awareness

Keep the idea that work moves through explicit planning stages and readiness states.

### MCP-friendly structured tooling posture

Keep the emphasis on structured tools with explicit scope and honest descriptions.

---

## Reshape

### Projects, features, and tasks

These concepts should be reshaped into Project V's orchestration language.

Likely replacements or expansions include:

- objectives
- initiatives
- work items
- dependencies
- handoffs
- decisions
- readiness evaluations

### BYDA or equivalent readiness methodology

Carry forward the useful readiness/audit logic, but bind it to Project V's orchestration role.

It should remain a planning and readiness capability, not a universal system truth layer.

### Summaries and synthesis artifacts

Keep them as derived planning aids.
Do not treat them as canonical truth unless explicitly promoted.

### Job and worker concepts

Keep only where they support planning-side ingestion, synthesis, audit, or indexing work.
Do not let Project V drift into execution ownership.

### GitHub linkage

Keep GitHub integration as a helpful repo-work or implementation boundary surface.
Do not let GitHub state become the core identity of Project V.

---

## Reject

### Single-system ownership assumptions

Reject the idea that Project V should become the canonical owner of all relevant project information.

In the V Ecosystem:

- VEDA owns observatory truth
- V Forge owns execution truth
- Project V owns planning and orchestration truth

### Execution-oriented code generation ownership

Reject any carry-forward shape that makes Project V the owner of code generation or production execution truth.

Execution belongs in V Forge or other explicit execution surfaces.

### Generic database query surfaces as first-class operator tools

Reject unrestricted or overly broad query tools as part of the core system surface.

They are dangerous, boundary-weakening, and not necessary for the bounded architecture.

### Generic project-management-software framing

Reject the idea that Project V is just a nicer project tracker.

Project V is specifically the orchestration layer of the V Ecosystem.

---

## Initial Carry-Forward Candidates

The following types of records are strong carry-forward candidates in Project V form:

- projects or project-like orchestration anchors
- research documents
- document chunks or retrieval units
- planning summaries
- task evidence or evidence links
- readiness audits
- readiness gaps
- technology declarations relevant to planning
- feature or work breakdown records

These should be renamed or reshaped where needed so their meaning aligns with Project V rather than legacy Project Planner language.

---

## Initial New Concepts Project V Likely Needs

Project V likely needs some concepts that should be explicit rather than implied:

- objectives
- initiatives
- decision records
- handoff records
- dependency links
- readiness evaluations
- route-to-system classification
- bounded owner assignments

These concepts fit Project V's ecosystem role more directly than generic project-planner terminology.

---

## Carry-Forward Matrix

| Legacy concept | Decision | Project V home |
|---|---|---|
| documentation-first planning | keep | architecture + planning posture |
| readiness/audit gate | keep and reshape | planning readiness model |
| research docs | keep | `docs/research/` + Project V research records |
| research-to-task traceability | keep | evidence and planning linkage |
| project / feature / task hierarchy | reshape | objective / initiative / work-item model |
| summaries | reshape | derived planning aids |
| jobs / worker flows | reshape | bounded planning-side background support |
| GitHub linkage | reshape | integration boundary, not core identity |
| single source of truth posture | reject | incompatible with bounded ecosystem |
| execution ownership | reject | belongs outside Project V |
| observatory ownership | reject | belongs in VEDA |

---

## Practical Rule

When carrying something forward from Project Planner, ask:

```text
Is this fundamentally planning truth, observatory truth, or execution truth?
```

- planning truth may belong in Project V
- observatory truth belongs in VEDA
- execution truth belongs in V Forge

If the old concept mixes multiple kinds of truth, split it before adopting it.

---

## Final Judgment

Project V should inherit the best parts of Project Planner's planning brain.

It should not inherit the old everything-system assumption.

The correct carry-forward shape is:

- keep the planning brain
- keep the readiness discipline
- keep the evidence linkage
- reshape the domain language
- reject ownership that belongs elsewhere
