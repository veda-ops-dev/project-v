# Project V MCP Surface

## Purpose

This document defines the first-pass MCP posture for Project V.

It exists to answer:

```text
What should the Project V MCP surface expose, what should it not expose, how should it relate to the VS Code extension, and what rules keep it bounded and implementation-safe?
```

---

## Read This With

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/core/implementation-traceability.md`
- `docs/architecture/operator-surfaces/project-v-vscode-extension.md`

---

## Core Rule

The Project V MCP surface is a **bounded tool and resource surface** for Project V.

It exists so LLM-assisted operators can:

- read bounded Project V context
- perform governed Project V actions
- retrieve explicit Project V resources
- follow structured Project V prompts or workflows where later promoted

The MCP surface must not:

- become a second application backend with different rules
- bypass Project V API or domain governance
- expose observatory or execution truth as though Project V owned it
- turn Project V into a vague chat-driven blob

---

## First-Pass Goal

The first-pass MCP surface should support practical LLM-assisted use with minimal ambiguity.

That means:

- explicit tools for high-value governed actions
- explicit resources for high-value Project V context
- explicit project scope behavior
- no hidden mutation shortcuts
- compatibility with Claude Desktop now
- future compatibility with other MCP-aware clients later

---

## Relationship to the VS Code Extension

The VS Code extension and the MCP surface are complementary, not interchangeable.

Preferred posture:

- VS Code extension = native operator UX inside the editor
- MCP surface = tool/resource layer for Claude Desktop now and other MCP clients later

The extension may eventually consume or mirror the same bounded actions.
But the MCP surface should remain independently coherent.

Do not assume:

- that every operator uses chat
- that every operator uses VS Code
- that MCP replaces native UX

---

## First-Pass Surface Types

The first-pass MCP surface may expose:

### 1. Tools

Use MCP tools for explicit Project V actions such as:

- list or fetch project-scoped records
- create objective / initiative / work item
- execute governed status transitions
- evaluate readiness
- create handoff
- create or inspect GitHub links
- fetch current gaps or blockers

Tool contracts should remain:

- explicit
- deterministic
- scope-honest
- aligned to Project V API and domain rules

### 2. Resources

Use MCP resources for read-oriented contextual material such as:

- current project context
- objectives / initiatives / work items summaries
- current gaps and blockers
- current handoffs
- deferred judgments or related operator docs where useful

Resources should remain:

- bounded
- recoverable from Project V truth
- honest about whether they are canonical or derived

### 3. Prompts

Prompt surfaces may exist later where they are clearly useful for:

- guided planning review
- readiness review
- handoff review
- hammer-driven hardening workflows

Prompt surfaces are not required in the first pass.
They should only be promoted when the underlying action and resource surfaces are already stable.

---

## First-Pass Tooling Rule

Every mutating MCP tool must correspond to a governed Project V action that already makes sense outside MCP.

That means:

- MCP must not invent special write paths
- MCP must not bypass status transition rules
- MCP must not allow callers to set server-owned fields directly
- MCP must not mutate Project V through convenience payloads that the normal API would reject

If a tool cannot be described as a bounded Project V action, it should not exist.

---

## Scope Rule

The MCP surface must reinforce Project V multi-project discipline.

That means:

- project scope must be explicit in tool behavior
- reads must not leak cross-project existence casually
- writes must not rely on hidden current-project inference
- resources must make project context visible where applicable

The MCP surface should make it easier for an LLM-assisted operator to stay in the correct project, not easier to blur scope.

---

## Resource Honesty Rule

Resources may include:

- canonical Project V truth
- clearly labeled derived summaries
- clearly labeled convenience context

They must not:

- masquerade as VEDA observatory truth
- masquerade as V Forge execution truth
- hide derivation when derivation matters
- silently replace canonical Project V records

A convenience summary is not the same thing as canonical planning truth.

---

## Current LLM Posture

The practical first-pass LLM posture is:

- Claude Desktop is the primary MCP client
- model API spend is intentionally avoided for now where possible
- the MCP surface should remain useful without assuming paid API access inside VS Code

This posture may evolve later.
It should not change the bounded design of the MCP surface.

---

## Auth and Client Boundary Posture

The MCP surface should follow least-privilege and explicit-boundary principles.

### Client posture

Clients may call Project V MCP tools and resources only through the bounded MCP contract.
They must not assume hidden direct database or cross-system access.

### Credential posture

Credentials used by the MCP surface should be owned by the Project V boundary they act through.
Do not let the MCP layer become a hidden credential escalator.

### Read vs write posture

Read-oriented resources and tools should remain clearly distinguishable from mutating tools.
Mutating tools must be treated with the same governance posture as normal API writes.

This is a policy-level posture.
It does not prescribe a particular deployment topology or secret-management system.

---

## Relationship to External Systems

The MCP surface may expose Project V's bounded interpretation of external relationships.

Examples:

- GitHub linkage as planning-side traceability
- VEDA references as planning support context
- V Forge handoff state from the orchestration perspective

It must not expose:

- raw VEDA observatory truth as though Project V owns it
- raw V Forge execution truth as though Project V owns it
- GitHub as a mirrored source-control warehouse

The MCP surface is a Project V surface, not a multi-system god surface.

---

## Guardrails Against MCP Sprawl

Do not create MCP tools for:

- loosely defined “do whatever seems right” workflows
- hidden multi-step mutation blobs
- broad catch-all manager tools
- actions that cannot explain project scope clearly
- actions that rewrite canonical truth without explicit intent

Prefer:

- narrow tools
- explicit resource names
- deterministic outputs
- explicit errors
- boring behavior

---

## Suggested First-Pass MCP Capabilities

A practical first-pass MCP surface should prioritize:

- project listing and project selection context
- objective / initiative / work item reading
- bounded creation of core planning records
- governed status transitions
- readiness and gap inspection
- handoff inspection and creation
- GitHub linkage inspection and creation

Defer richer prompt/app surfaces until the core tool/resource layer proves stable.

---

## Testing and Hardening Rule

The MCP surface should be hammered for:

- project-scope enforcement
- correct error posture
- no bypass of governed mutation rules
- deterministic resource output where appropriate
- no hidden ownership blur across Project V, VEDA, and V Forge
- no client-side invention of canonical truth through convenience mutation

An MCP surface is not trustworthy because a chat demo looked impressive once.

---

## Final Rule

The Project V MCP surface should make LLM-assisted work easier without making Project V less bounded, less explicit, or less governable.

If a proposed MCP capability makes Project V feel more magical and less classifiable, it is wrong.
