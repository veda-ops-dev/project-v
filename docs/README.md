# Project V Documentation

## Purpose

This `docs/` tree is the canonical documentation surface for Project V.

It is organized for:

- bounded-system clarity
- deterministic navigation
- low-ambiguity retrieval by LLMs and humans
- explicit separation between authority docs, working docs, research, and archived material

---

## Start Here

Read these first:

- `docs/document-map.md`
- `docs/standards/documentation-rules.md`
- `docs/architecture/README.md`

---

## Folder Map

```text
docs/
├─ README.md
├─ document-map.md
├─ standards/
├─ architecture/
│  ├─ core/
│  ├─ data/
│  ├─ integrations/
│  ├─ operator-surfaces/
│  └─ decisions/
├─ planning/
├─ research/
├─ api/
├─ runbooks/
├─ glossary/
└─ archive/
```

---

## Folder Purposes

### `standards/`
Documentation rules, naming rules, templates, and writing conventions.

### `architecture/`
System truth for Project V.

- `core/` = purpose, boundaries, invariants, lifecycle framing
- `data/` = database, schema, persistence, events, and state model docs
- `integrations/` = VEDA, V Forge, GitHub, MCP, and external/system boundary docs
- `operator-surfaces/` = MCP, CLI, editor, and other operator-facing surface docs
- `decisions/` = architecture decision records

### `planning/`
Roadmaps, phased plans, carry-forward decisions, and active implementation plans.

### `research/`
Research notes, source-grounded explorations, and analysis packages that may inform planning but are not themselves architecture authority.

### `api/`
API contracts, endpoint packages, validation rules, and surface-level request/response docs.

### `runbooks/`
Operational procedures, setup steps, migrations, recovery, and repeatable operator workflows.

### `glossary/`
System vocabulary and canonical term definitions.

### `archive/`
Retired docs that remain useful for provenance but are not active truth.

---

## Structural Rules

1. Keep one clear purpose per folder.
2. Keep one clear topic per file.
3. Do not duplicate folder names across nested paths.
4. Do not create vague buckets like `misc`, `temp`, `notes`, or `stuff`.
5. Prefer folder `README.md` files as the local index for that folder.
6. Archive old docs instead of leaving stale active copies in place.

---

## Reserved Canonical Docs

These should be created early and kept current:

- `docs/architecture/core/project-v.md`
- `docs/architecture/core/system-invariants.md`
- `docs/architecture/data/db-boundaries.md`
- `docs/planning/carry-forward-from-project-planner.md`
- `docs/planning/initial-domain-model.md`

---

## Read This Next

- `docs/document-map.md`
- `docs/standards/documentation-rules.md`
- `docs/architecture/README.md`
