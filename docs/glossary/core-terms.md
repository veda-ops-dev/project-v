# Core Terms

## Purpose

This document defines the core vocabulary for Project V.

It exists to keep architecture docs, API docs, hammer docs, and future implementation work aligned around stable terminology.

---

## Project V

The planning and orchestration layer of the V Ecosystem.

Project V owns planning truth, orchestration truth, readiness truth, sequencing truth, decision truth, and handoff truth.

Project V does not own observatory truth or execution truth.

---

## VEDA

The observability and intelligence layer of the V Ecosystem.

VEDA owns observed external reality and project-scoped observatory state.

---

## V Forge

The execution and production layer of the V Ecosystem.

V Forge owns drafts, editorial workflow, publishing workflow, produced assets, and execution truth.

---

## Bounded System

A system with explicit ownership, explicit responsibilities, and explicit non-goals.

A bounded system should not casually absorb another system's truth.

---

## Planning Truth

Canonical truth about what should happen, why it should happen, what is blocked, what is ready, and how work should be sequenced.

Planning truth belongs in Project V.

---

## Observatory Truth

Canonical truth about observed external reality, signals, and observatory state.

Observatory truth belongs in VEDA.

---

## Execution Truth

Canonical truth about drafts, production workflow, publishing workflow, produced assets, and execution state.

Execution truth belongs in V Forge.

---

## Project-Scoped

A record that belongs to exactly one project.

Project-scoped records must not leak across project boundaries casually.

---

## Global

A record intentionally shared across projects.

Global records must be rare, justified, and documented.

---

## System Metadata

System-owned metadata that is not a loophole for project-owned canonical truth.

---

## Objective

A major outcome a project is trying to achieve.

---

## Initiative

A bounded body of work that advances an objective.

---

## Work Item

A concrete unit of planning or execution-preparation work inside Project V.

A work item does not become the canonical owner of execution truth.

---

## Dependency

An explicit relationship showing that one Project V record depends on another.

---

## Decision Record

A recoverable record of a meaningful planning or orchestration decision.

---

## Readiness Evaluation

An inspectable evaluation of whether a Project V record is ready to move forward.

---

## Readiness Gap

A missing condition, blocker, or deficiency identified during readiness evaluation.

---

## Evidence Link

A directional link from planning truth to supporting evidence.

A supporting reference is not the same thing as ownership of the referenced truth.

---

## Handoff

A bounded transition from Project V into another system or surface.

A handoff is not shared ownership.
It is a transition of responsibility.

---

## Canonical Truth

The system-owned source of truth for a concept.

A concept should have one canonical home.

---

## Derived Artifact

A summary, synthesis, convenience view, or interpretation derived from canonical truth.

Derived artifacts must not silently replace canonical truth.

---

## Material

Important enough to change governance judgment, readiness confidence, audit confidence, transition legality, or implementation safety.

If a change or contradiction would reasonably affect whether work may proceed, it is material.

---

## Governed Key Format

The standard Project V key shape used for `Project.key` and per-project keys such as `Objective.key`, `Initiative.key`, and `WorkItem.key`.

First-pass shape:

- lowercase letters and digits
- optional internal hyphens
- no spaces
- no underscores
- no leading or trailing hyphen

Recommended regex:

```text
^[a-z0-9]+(?:-[a-z0-9]+)*$
```

---

## Governed Path

An explicitly documented and authorized mechanism for performing a mutation, transition, or system action.

Governed paths are the only legal ways to change state where the architecture requires explicit authorization.

---

## Hammer Test

An invariant-first hardening test designed to verify real behavior, negative-path rejection, transaction safety, boundary safety, and deterministic outcomes.
