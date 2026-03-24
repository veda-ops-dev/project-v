# Database Boundaries

## Purpose

This document defines the database boundary posture for the V Ecosystem as it relates to Project V.

It exists to answer:

```text
How should Project V, VEDA, and V Forge be separated at the database level, and what rules should govern cross-system persistence?
```

---

## Core Decision

The baseline database posture is:

- one shared **Postgres cluster**
- one database per bounded system

Initial shape:

- `project_v` database for Project V
- `veda` database for VEDA
- `v_forge` database for V Forge

This preserves bounded ownership while keeping local and operational infrastructure reasonably simple.

---

## Why This Shape

This shape is preferred because:

- each bounded system owns a different kind of truth
- each bounded system should have a clear canonical persistence boundary
- LLM-assisted development works better when boundaries are reinforced by storage shape
- infrastructure may be shared without collapsing the domain model

Project V owns planning and orchestration truth.
VEDA owns observatory truth.
V Forge owns execution and production truth.

Those truths should not share a canonical database.

---

## What This Decision Is Not

This decision does **not** mean:

- three separate infrastructure estates
- premature microservice theater
- no coordination between systems

This decision means that canonical system truth is kept in the database owned by the system that is responsible for it.

---

## Project V Boundary

The `project_v` database is the canonical persistence boundary for Project V.

It should contain Project V-owned records such as:

- projects relevant to orchestration
- objectives
- initiatives
- work items
- dependencies
- decision records
- readiness records
- handoff records
- planning research traceability

It should not contain canonical observatory truth or canonical execution truth.

---

## VEDA Boundary

The `veda` database is the canonical persistence boundary for VEDA.

It owns observed external reality and project-scoped observatory state.

Project V may reference VEDA entities and observations, but VEDA remains the owner of those records.

---

## V Forge Boundary

The `v_forge` database is the canonical persistence boundary for V Forge.

It owns produced outputs, production workflow, editorial state, revision state, and publishing-related execution truth.

Project V may coordinate readiness and handoff into V Forge, but V Forge remains the owner of execution truth.

---

## Cross-System Rules

### 1. No direct canonical ownership mixing

A record should have one canonical home.

If Project V needs data from VEDA or V Forge, it should reference or request that data through explicit boundaries.
It should not treat another system's database as an extension of its own domain.

### 2. No hidden cross-system write shortcuts

Do not allow Project V to write directly into VEDA or V Forge canonical tables as a convenience shortcut.

Do not allow VEDA or V Forge to write directly into Project V canonical tables unless a deliberately designed boundary says so.

### 3. Explicit references are allowed

Cross-system references are allowed when they are explicit and honest.

Examples:

- a Project V handoff record may reference a V Forge work package identifier
- a Project V decision may cite a VEDA observation or target

A reference is not the same thing as ownership.

### 4. Imported or derived local views must stay honest

If Project V imports or caches selected external information for planning convenience, that imported material must be clearly treated as:

- imported
- derived
- non-canonical outside Project V's own planning interpretation

Imported convenience state must not masquerade as canonical VEDA or V Forge truth.

---

## Why Separate Databases Help LLM Work

LLM-assisted development benefits from explicit, boring constraints.

Separate databases help because they make it easier to say:

- Project V writes here
- VEDA writes there
- V Forge writes there

That reduces the chance of:

- accidental domain blur
- misleading tool descriptions
- code generation that crosses boundaries casually
- schema growth that turns into a convenience blob

Good architecture is good promptability.

---

## Operational Posture

The preferred operational posture is:

- one local/shared Postgres cluster
- separate credentials per system where practical
- migrations managed by the owning system
- backups and restore procedures defined per system boundary

Shared infrastructure is acceptable.
Shared canonical truth is not.

---

## Future Evolution Rule

This database shape should make it easier, not harder, to evolve each system independently later.

That includes the possibility of:

- moving a system to separate infrastructure later
- tightening credentials and access rules
- evolving one schema aggressively without dragging another system with it

If a proposed shortcut makes later separation harder, that shortcut should be treated with suspicion.

---

## Final Rule

Use the simplest storage shape that preserves bounded ownership.

For the V Ecosystem, that means:

- same Postgres cluster
- separate databases per bounded system
- explicit cross-system coordination
- no mixed canonical ownership
