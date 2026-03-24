# Project V VS Code Extension

## Purpose

This document defines the first-pass VS Code operator surface for Project V.

It exists to answer:

```text
What should the Project V VS Code extension expose, what should it not expose, how should it relate to MCP, and what guardrails keep it useful without turning it into a UX mess?
```

---

## Read This With

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/integrations/project-v-mcp-surface.md`
- `docs/architecture/testing/hammer-doctrine.md`

---

## Core Rule

The Project V VS Code extension is an **operator surface** for Project V.

It exposes bounded planning and orchestration truth inside VS Code.
It must not become:

- a second database
- a shadow execution system
- a shadow observability system
- a chat-first blob that hides system behavior behind prompts

The extension should make Project V easier to navigate, act on, and validate.
It should not redefine Project V truth.

---

## First-Pass Goal

The first-pass VS Code extension should optimize for:

- visibility into current project-scoped planning truth
- low-friction navigation across objectives, initiatives, work items, handoffs, readiness, and gaps
- explicit command execution for governed actions
- bounded validation and hardening workflows
- compatibility with a future-shared MCP tool surface

The first pass should remain boring, explicit, and easy to reason about.

---

## Non-Goals

The first-pass VS Code extension should not attempt to be:

- a full custom project-management application inside a webview
- a replacement for Claude Desktop MCP workflows
- a source-control analytics dashboard
- a VEDA observability console
- a V Forge execution console
- a giant wizard or onboarding maze
- a custom editor for Project V records
- a notebook system

If a proposed feature pushes the extension toward those shapes, the feature should be treated with suspicion.

---

## Surface Ownership Rule

The extension owns **presentation and operator interaction** inside VS Code.

Project V server/API owns:

- canonical planning truth
- status transitions
- readiness results
- audit results
- handoff state

The extension may:

- read Project V truth
- trigger bounded Project V actions
- surface Project V tasks and validations
- display derived summaries where clearly labeled

The extension must not:

- invent local canonical state that diverges from Project V
- allow client-side mutation paths that bypass governed APIs or rules
- silently mutate server-owned fields such as status or readiness state

---

## Information Architecture

The extension must define a clear, minimal, and predictable layout.

### Sidebar Layout

One view container: `Project V`

#### View 1 — Project Context (always visible)

Displays:

- active project key and name
- project status
- quick action to switch project

This view must:

- never be collapsible
- always be visible
- clearly indicate when no project is selected

#### View 2 — Planning Tree (project-scoped)

Hierarchical structure:

```text
OBJECTIVES
  └─ INITIATIVES
       └─ WORK ITEMS
```

Separate sections:

- HANDOFFS
- READINESS GAPS

Rules:

- the entire planning tree is scoped to the active project
- blocked items must be visually distinct
- readiness gap count must be visible at section level
- handoffs in `ready` or `handed_off` must be visually flagged

#### Optional Later View — Project Navigator

A later flat filtered view of work items across the active project may be added if real operator use shows that the hierarchical tree alone is too slow for daily scanning.

Do not add this in Phase 1 by default.

---

## What Must Be Visible at a Glance

Without expanding nodes:

- active project identity
- blocked entities
- readiness gap counts
- active handoffs

---

## What Must Be Drill-In Only

- full readiness gap details
- decision records
- research docs
- status history
- dependencies
- GitHub link details

---

## Project Switching Posture

Project switching must be explicit and visible.

Rules:

- active project shown in sidebar header and status bar
- switching done via quick pick
- recently active projects should be prioritized in selection where practical
- the entire Planning Tree view re-scopes on switch
- no cross-project views exist in Phase 1
- mutation actions must not rely on hidden project inference

The extension should make it harder, not easier, to act in the wrong project.

---

## First-Pass UX Surfaces

### 1. Tree view

Primary navigation and context surface.

### 2. Command palette

All important extension actions should exist as explicit commands first.

### 3. Quick picks

Use quick pick flows for:

- project selection
- parent selection for child creation
- legal status transition selection
- handoff target selection where applicable

### 4. Context menus and title actions

Expose only a small number of high-value actions.

### 5. Status bar

Shows active project key and provides switch-project affordance.

### 6. Welcome view and walkthrough

One welcome surface and one short walkthrough only.

### 7. Tasks

Use standard VS Code task behavior for hammer and validation flows.

---

## Workflow Action Map

| Lifecycle Phase | Key Extension Actions | Key Commands |
|----------------|-----------------------|--------------|
| Intake / Planning | Create core records | Create Objective / Initiative / Work Item |
| Active Work | Review and transition work safely | Transition Status |
| Readiness | Evaluate readiness and inspect gaps | Evaluate Readiness |
| Audit / Review | Review blockers and hardening work | Open Gaps / Run Hammer |
| Handoff | Prepare and transition handoff state | Create Handoff / Transition Handoff |

The extension serves governed workflow, not just entity browsing.

---

## Commands

All core actions must exist as explicit commands.

Examples:

- `Project V: Switch Active Project`
- `Project V: Create Objective`
- `Project V: Create Initiative`
- `Project V: Create Work Item`
- `Project V: Transition Status`
- `Project V: Evaluate Readiness`
- `Project V: Create Handoff`
- `Project V: Open Linked Resource`
- `Project V: Run Hammer Module`
- `Project V: Run Hammer Coordinator`
- `Project V: Copy Context for LLM`
- `Project V: Copy Project V ID`
- `Project V: Reveal Entity`

Command names should stay aligned with MCP tool vocabulary where practical.

---

## LLM Context Packaging

The extension should help the operator hand useful context to the LLM without requiring in-editor chat.

### Command: Copy Context for LLM

This command should assemble structured Project V context for the selected entity.

Include at least:

- entity type, key, and name
- current status
- parent chain
- open readiness gaps
- blockers
- recent status history
- GitHub links where relevant

Output:

- structured text copied to clipboard

### Command: Copy Project V ID

Include at least:

- project identity
- entity key
- entity type where useful

This helps the human and the LLM refer to the same record unambiguously.

### Reveal Entity

A `Reveal Entity` command may be added so other bounded workflows can navigate the extension tree to a known entity directly.

---

## Chat and LLM Posture

The first-pass VS Code extension should not depend on paid model API access.

The current practical posture is:

- Claude Desktop with MCP is the primary near-term LLM workflow
- the extension must remain useful with no in-editor model access
- future chat inside VS Code is a later enhancement, not a dependency

Do not build the extension as a chat shell.

---

## Relationship to MCP

The VS Code extension and the Project V MCP surface are siblings.

Preferred posture:

- VS Code extension = native operator UX
- MCP surface = tool/resource layer for Claude Desktop now and other MCP clients later

Where both surfaces support the same action, they must align to the same bounded Project V truth and governed mutation rules.

See:

- `docs/architecture/integrations/project-v-mcp-surface.md`

---

## State and Caching Rule

The extension may keep local transient UI state such as:

- selection state
- expansion state
- active project context
- bounded cached fetched data

That state must remain:

- non-canonical
- replaceable
- recoverable from Project V truth

The extension must not present stale cache as though it were authoritative current Project V truth.

---

## Multi-Project Safety Rule

The extension must reinforce Project V multi-project discipline.

That means:

- project context should be visible at all times
- project-scoped actions must stay explicit
- cross-project views must be deliberate, not accidental
- mutation actions must not rely on hidden project inference

---

## Guardrails Against UX Sprawl

The first-pass extension should avoid:

- multiple custom view containers unless clearly justified
- custom webviews where native VS Code views are sufficient
- giant dashboard screens
- custom editors
- notebook interfaces
- overlapping surfaces that expose the same Project V truth in competing ways

When in doubt, prefer:

- one view container
- one project context header
- one planning tree
- explicit commands
- quick picks
- normal tasks

---

## Explicit Do-Not-Build-Yet List

The following should be refused in Phase 1 unless later governance explicitly promotes them:

- custom webview dashboard
- custom editor for Project V records
- notebook interface
- in-editor chat participant
- Gantt or timeline view
- automatic status inference from git activity
- cross-project summary dashboard
- inline editing of readiness gaps
- research doc editor
- MCP proxy layer inside the extension

These ideas may sound attractive in demos while still weakening clarity or boundedness in practice.

---

## Phased Rollout

### Phase 1 — Core operator navigation and action

Goal:

- operator can open VS Code, understand the current project quickly, navigate the planning hierarchy, take governed actions, and hand useful context to Claude Desktop

Ship:

- Project Context view
- hierarchical Planning Tree
- HANDOFFS section
- READINESS GAPS section
- status bar active-project indicator
- core commands
- quick pick flows
- high-value context menus
- welcome view
- one short walkthrough
- `Copy Context for LLM`
- `Copy Project V ID`
- basic hammer task integration

Completion signal:

- operator can complete the normal daily review and planning-action loop without leaving VS Code except for Claude Desktop work

### Phase 2 — Workflow depth and LLM connector polish

Goal:

- extension makes richer workflows faster and reduces friction in human ↔ LLM handoff

Consider adding:

- Project Navigator view
- status-history drill-in
- decision-record section (read-only)
- research-doc section (read-only)
- `Reveal Entity` command
- richer hammer task affordances
- status-bar refinements such as gap or blocked-count indicators
- recent-project ordering improvements

Completion signal:

- operator can do deeper readiness, handoff, and hardening work without losing project context or reconstructing state manually

### Phase 3 — Only after real-use evidence justifies it

Possible additions:

- VS Code chat participant
- deeper MCP-aware workflows inside VS Code
- richer read-only visualization surface
- deliberate cross-project summary surface if real operator need emerges

Do not start Phase 3 based on speculation.
Only start it when a specific earlier workflow proves insufficient.

---

## Testing and Hardening Rule

The extension should be hardened for:

- project-scope clarity in actions
- deterministic ordering where applicable
- correct routing to governed Project V actions
- no hidden mutation of server-owned fields
- stale-cache honesty
- failure behavior when APIs reject invalid actions

A surface is not complete because it rendered something plausible once.

---

## Final Rule

The Project V VS Code extension should make Project V easier to use without making Project V harder to understand.

If a proposed feature adds more confusion than leverage, it is wrong.
