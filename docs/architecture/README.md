# Architecture Docs

This folder contains the active architecture truth for Project V.

## Subfolders

- `core/` = system purpose, ownership, invariants, and primary authority docs
- `data/` = persistence, schema, DB boundaries, events, and state model docs
- `integrations/` = bounded cross-system and external integration docs
- `operator-surfaces/` = MCP, CLI, VS Code, and other operator-facing surface docs
- `decisions/` = architecture decision records

## Rules

- active architecture truth belongs here, not in `planning/`
- use one file per bounded concern
- keep companion docs linked explicitly
