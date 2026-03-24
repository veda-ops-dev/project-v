# Documentation Rules

## Purpose

This document defines the naming, structure, and writing rules for Project V documentation.

The goal is to keep documentation:

- explicit
- searchable
- low-ambiguity
- LLM-readable
- durable under long-term iteration

---

## Core Principles

### 1. Prefer explicit names over clever names

Good:

- `system-invariants.md`
- `db-boundaries.md`
- `veda-integration.md`

Bad:

- `brain.md`
- `thoughts.md`
- `stuff-to-do.md`

### 2. One topic per file

A document should have one primary concern.
If a file needs to explain multiple unrelated concerns, split it.

### 3. One canonical location per concern

A topic should have one active home.
Do not keep multiple active docs describing the same system truth in different folders.

### 4. Stable paths matter

Avoid renaming folders casually.
Links, prompts, tools, MCP references, and future automation all get safer when paths stay boring and stable.

### 5. Folder names should describe category, not project mythology

Use plain category names:

- `architecture`
- `planning`
- `research`
- `runbooks`

Do not use vague or branded bucket names unless they represent a real bounded concept.

---

## Folder Naming Rules

### Rule

Use **lowercase kebab-case** for all folder names.

Examples:

- `operator-surfaces`
- `runbooks`
- `architecture`
- `integrations`

### Avoid

- spaces
- underscores
- camelCase
- repeated nesting like `architecture/architecture`
- generic buckets like `misc` or `other`

---

## File Naming Rules

### Rule

Use **lowercase kebab-case** for documentation files.

Examples:

- `project-v.md`
- `system-invariants.md`
- `db-boundaries.md`
- `carry-forward-from-project-planner.md`

### Allowed exceptions

- `README.md` for folder index files
- `ADR-0001-short-title.md` for architecture decision records

### Avoid

- dates at the front of file names unless the document is inherently time-based
- version suffixes like `final`, `final-v2`, `new`, `latest`
- vague labels like `notes.md`, `ideas.md`, `draft.md`

---

## Decision Record Naming

Architecture decision records belong in `docs/architecture/decisions/`.

Format:

```text
ADR-0001-short-title.md
ADR-0002-short-title.md
```

Rules:

- use a zero-padded numeric sequence
- keep titles short and descriptive
- never reuse a number
- do not rename an ADR after it is referenced; supersede it with a later ADR if needed

---

## README Rules

Each significant folder should contain a `README.md` that answers:

- what belongs here
- what does not belong here
- which files should be read first
- whether the folder contains active truth, working material, or archived material

Folder `README.md` files are navigation anchors for both humans and LLMs.

---

## Writing Rules for LLM Readability

### Prefer direct headings

Good:

- `## Purpose`
- `## Ownership`
- `## Non-Goals`
- `## Rules`
- `## What This Doc Is Not`

### Prefer bounded statements

Good:

- `Project V owns orchestration truth.`
- `Project V does not own observatory truth.`

Bad:

- `Project V kind of sits between several things.`

### Prefer repeated canonical terms

Choose one term and keep using it.

Examples:

- always use `Project V`
- always use `V Forge`
- always use `operator surface`

Do not drift between near-synonyms without reason.

### Prefer short sections over long mixed sections

LLMs retrieve and summarize better when sections are narrow and clearly headed.

### Prefer truth over prose flourish

Architecture docs should optimize for precision first.

---

## Link and Reference Rules

- Use relative links inside the repo.
- Reference exact file paths when naming a companion doc.
- Avoid saying `see other doc` without naming the file.
- When a document is superseded, update inbound references where practical.

---

## Archive Rules

When a doc is no longer active truth but still matters for provenance:

1. move it to `docs/archive/`
2. preserve the filename where practical
3. add a clear archival note at the top
4. point to the replacement active doc if one exists

Never leave stale architecture docs mixed into active folders without explanation.

---

## Anti-Patterns

Do not create:

- `misc/`
- `temp/`
- `random-notes.md`
- `overview-final-v3.md`
- duplicate active copies of the same topic
- deep nesting with no clear reason

---

## Final Rule

When unsure, choose the naming and folder shape that is:

- more explicit
- more stable
- less clever
- easier to retrieve
- easier to maintain
