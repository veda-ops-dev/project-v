# Hammer Coverage Map

## Purpose

This document provides the explicit mapping between Project V system invariants and the hammer
modules responsible for enforcing them.

It exists to answer:

```text
Which hammer module verifies which invariant?
Are there invariants with no coverage?
```

Without this map, invariants may exist without effective test coverage — creating false confidence.

---

## How to Read This Map

Each invariant from `docs/architecture/core/system-invariants.md` is listed with:

- the hammer module(s) that cover it
- coverage status: **covered**, **partial**, or **gap**
- a gap note where coverage is missing or incomplete

A **gap** does not mean the invariant is wrong. It means the invariant is currently untested and
represents active hardening risk.

---

## Coverage Map

### Section 1 — Bounded Ownership Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 1.1 Project V is orchestration-only | `hammer-boundary-enforcement` | covered | Verifies observatory- and execution-shaped payloads are rejected as canonical PV state |
| 1.2 Must not impersonate VEDA | `hammer-boundary-enforcement`, `hammer-cross-system-references` | covered | Tests that VEDA-owned records cannot be stored as canonical PV truth |
| 1.3 Must not impersonate V Forge | `hammer-boundary-enforcement`, `hammer-handoffs` | covered | Tests that execution-state cannot be smuggled into PV models |

---

### Section 2 — Scope and Isolation Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 2.1 Planning records inside PV ownership | `hammer-scope-isolation`, `hammer-core-projects` | covered | Verifies records require valid PV project anchor |
| 2.2 Cross-system references must be explicit | `hammer-cross-system-references` | covered | Tests that implicit cross-system ownership is rejected |
| 2.3 Cross-system writes must stay bounded | `hammer-boundary-enforcement` | covered | Tests that PV does not write into VEDA or V Forge canonical tables |

---

### Section 3 — Readiness and Audit Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 3.1 Readiness must be inspectable | `hammer-readiness-core`, `hammer-readiness-gaps` | covered | Verifies evaluations record what passed, failed, and what gaps remain |
| 3.2 Audit outputs must not silently mutate canonical state | `hammer-readiness-core`, `hammer-audit-readiness-coupling` | covered | Tests that advisory audit results do not rewrite planning truth without explicit action |
| 3.3 Gating must remain explainable | `hammer-readiness-core` | partial | Valid-path explainability is covered. No dedicated test for the explainability surface under adversarial or LLM-assisted conditions. Low priority for first pass. |

---

### Section 4 — Decision and Traceability Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 4.1 Significant decisions must be recoverable | `hammer-decisions` | covered | Verifies decision records persist correctly with rationale |
| 4.2 Evidence links must remain directional and honest | `hammer-evidence-links` | covered | Tests that evidence links do not overclaim ownership |
| 4.3 Derived summaries are not canonical truth unless promoted | `hammer-derived-honesty` | covered | Tests that derived artifacts do not silently replace source planning truth |

---

### Section 5 — Determinism Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 5.1 List surfaces must have deterministic ordering | `hammer-ordering`, `hammer-contracts-read` | covered | Tests that list results are stable for identical inputs |
| 5.2 Readiness evaluation must be reproducible | `hammer-readiness-reproducibility` | covered | Tests same inputs produce same readiness result |
| 5.3 Context assembly should prefer reproducibility | — | **gap** | No hammer module currently targets context assembly ordering. If a context assembly surface is implemented, add coverage in `hammer-ordering` or a dedicated `hammer-context-assembly` module. |

---

### Section 6 — Transaction and State Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 6.1 Multi-write state changes must be atomic | `hammer-transaction-rollback` | covered | Tests that partial writes do not survive failed mutations |
| 6.2 Status changes and decision/event history must stay aligned | `hammer-state-transitions`, `hammer-decisions` | covered | Tests that state change without required history fails; history without corresponding state change fails |
| 6.3 Explicit action beats silent mutation | `hammer-state-transitions` | covered | Tests that explicit transitions are required and silent rewrites are rejected |

---

### Section 7 — Data Boundary Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 7.1 Project V has its own database boundary | `hammer-boundary-enforcement` | covered | Tests that PV persistence stays inside `project_v` canonical tables |
| 7.2 Shared infrastructure does not justify shared truth | `hammer-boundary-enforcement` | covered | Tests that domain collapse is rejected even where infra is shared |
| 7.3 Cross-database convenience must not weaken boundaries | `hammer-cross-system-references`, `hammer-boundary-enforcement` | covered | Tests that shortcut cross-system paths are rejected |

---

### Section 8 — Operator Surface Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 8.1 Operator surfaces must expose bounded truth honestly | `hammer-contracts-read`, `hammer-contracts-write` | partial | Contract shape is tested. Honesty of bounded-truth framing is harder to assert mechanically. Operator surface explainability remains a doc-level enforcement concern for first pass. |
| 8.2 Proposal visibility is allowed; silent authority escalation is not | — | **gap** | No hammer module currently targets the proposal-to-canonical promotion boundary. If proposal or suggestion surfaces are implemented, coverage should be added under `hammer-readiness-core` or a dedicated module. Flag before implementing any promotion-capable surface. |
| 8.3 LLM assistance must reinforce boundaries, not blur them | — | **gap** | Mechanical enforcement is not practical for first pass. This invariant is enforced at the doc and prompt level. No hammer module is expected here until LLM-facing tool surfaces are implemented and their boundary behavior can be asserted directly. |

---

### Section 9 — Testing and Verification Invariants

| Invariant | Hammer Module(s) | Status | Gap Note |
|---|---|---|---|
| 9.1 Planning and gating rules must be testable | (meta — satisfied by the existence of this coverage map and the hammer plan) | covered | — |
| 9.2 Boundary violations should be probeable | `hammer-boundary-enforcement`, `hammer-scope-isolation`, `hammer-cross-system-references` | covered | Explicit probes for VEDA ownership, V Forge ownership, hidden writes, and misreported readiness |
| 9.3 Repeatability matters | `hammer-readiness-reproducibility`, `hammer-ordering`, `hammer-coordinator` | covered | Coordinator run confirms full-suite repeatability |

---

## Gap Summary

| Invariant | Status |
|---|---|
| 5.3 Context assembly reproducibility | gap — no module yet; add if context assembly surface is implemented |
| 8.2 Proposal-to-canonical promotion boundary | gap — no module yet; must be covered before any promotion-capable surface ships |
| 8.3 LLM boundary reinforcement | gap — doc/prompt enforcement only; mechanical coverage deferred |
| 3.3 Gating explainability under adversarial conditions | partial — low priority for first pass |
| 8.1 Operator surface boundary framing | partial — contract shape covered, framing honesty is doc-level for first pass |

These gaps are documented. They are not oversights.
They must be reviewed when the relevant surfaces are implemented.

---

## Maintenance Rule

When a new invariant is added to `system-invariants.md`:

1. Add a row to this map immediately
2. Assign or flag coverage
3. If no coverage exists, mark it as a gap and note where coverage should live
4. Do not leave a new invariant unmapped

When a new hammer module is added:

1. Identify which invariant(s) it covers
2. Update this map
3. Verify the gap summary is still accurate

This map must stay synchronized with both `system-invariants.md` and `hammer-plan.md`.

---

## Authority Docs

- `docs/architecture/core/system-invariants.md`
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/architecture/testing/hammer-plan.md`
- `docs/architecture/data/db-boundaries.md`
