# Schema Build Sheet

## Purpose

This document converts the governed first-pass Project V schema into an implementation-ready build sheet.

It exists to answer:

```text
What should be built table by table, what belongs in SQL vs application logic, what transition/history hooks are required, and what hammer cases should be added immediately?
```

This is an implementation planning artifact.
It is not the canonical schema authority.
When this document conflicts with a stronger authority doc, the stronger authority doc wins.

Read this with:

- `docs/architecture/data/schema-authority.md`
- `docs/architecture/data/schema-specification.md`
- `docs/architecture/data/controlled-vocabularies.md`
- `docs/architecture/data/status-transitions.md`
- `docs/architecture/data/polymorphic-reference-enforcement.md`
- `docs/architecture/data/audit-and-gap-model.md`
- `docs/architecture/core/multi-project-doctrine.md`
- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/architecture/core/audit-evaluation-rules.md`
- `docs/api/api-conventions.md`

---

## Core Build Rules

### 1. Build the governed tables exactly

Do not add convenience tables, lifecycle tables, or blob fields during first-pass implementation unless governance explicitly approves them.

### 2. Keep SQL and application responsibilities separate

Use PostgreSQL for:

- primary keys
- foreign keys where direct references exist
- uniqueness constraints
- non-null guarantees
- basic range or shape checks where the rule is stable and not polymorphic
- index support for the documented query patterns

Use application/service logic for:

- same-project enforcement across optional parent links and polymorphic references
- controlled-vocabulary validation unless a later enum/check strategy is explicitly chosen
- status transition legality
- required-reason enforcement
- archived-parent freeze rules
- readiness and audit result computation
- atomic state/history write orchestration
- `updatedAt` maintenance

### 3. Prefer explicit service-layer validators over scattered route checks

The first pass should centralize:

- polymorphic entity resolution
- project-scope validation
- archived-parent validation
- transition legality checks
- status-history write requirements

### 4. No delete behavior in first pass

No canonical first-pass table should expose destructive delete semantics.

### 5. Deterministic ordering is mandatory

Every list query must use explicit ordering with a stable tie-breaker.

---

## Recommended Migration Sequence

### Migration 001 - core anchors
- `Project`
- `Objective`
- `Initiative`
- `WorkItem`

### Migration 002 - relationship and state governance
- `Dependency`
- `DecisionRecord`
- `StatusHistory`

### Migration 003 - readiness layer
- `ReadinessEvaluation`
- `ReadinessGap`

### Migration 004 - research, evidence, handoff
- `ResearchDoc`
- `EvidenceLink`
- `Handoff`

### Migration 005 - BYDA and implementation traceability
- `AuditRun`
- `AuditGap`
- `GitHubLink`

---

## Common Implementation Conventions

### IDs and timestamps
- use `uuid` primary keys
- use `timestamptz`
- use `now()` defaults on `createdAt`
- maintain `updatedAt` in service logic in the same transaction as the governed write

### Stable ordering convention
Unless an endpoint contract says otherwise, prefer:

- business sort fields first
- then `updatedAt desc` or `createdAt desc`
- then `id asc` as final tie-breaker

### Controlled-vocabulary validation convention
In the first pass, validate controlled vocabulary values in the application layer from a shared canonical vocabulary registry derived from:

- `docs/architecture/data/controlled-vocabularies.md`

Do not allow routes or repositories to define local allowed-value sets independently.

### PATCH and input validation rules
A bounded patch allows mutation of only the explicitly listed fields.

For all create and PATCH routes:

- unknown or forbidden fields must be rejected with `400 Bad Request`
- silent ignore of extra or invalid fields is not allowed
- if a field is not explicitly allowed for that mutation path, it must be rejected

See:

- `docs/api/api-conventions.md`

### Transition parameter exception to unknown-field rejection

Some PATCH routes use `reason` as a required transition parameter that is consumed by `StatusHistory` but not stored as a column on the patched table. Where a PATCH route governs a status transition that requires `reason`, the `reason` field must be accepted in the PATCH body without triggering unknown-field rejection. This applies to:

- `DecisionRecord` PATCH (`recorded -> superseded` requires `reason`)
- `ResearchDoc` PATCH (`active -> archived` requires `reason`)

The `reason` field is a transition parameter, not a stored column. It must not be rejected as unknown, and it must not be persisted on the patched row.

### Create-time lifecycle status rule
For `Project`, `Objective`, `Initiative`, `WorkItem`, and `Handoff`:

- the server assigns initial `status` on creation
- callers must not supply `status` in the create body
- supplying `status` must fail with `400 Bad Request`

Documented exceptions:

- `ResearchDoc` requires caller-supplied `status` at creation
- `DecisionRecord` requires caller-supplied `status` and `actor` at creation

See:

- `docs/api/research-docs-api.md`
- `docs/api/decision-records-api.md`

### Actor resolution convention
Where an API path writes `StatusHistory`, the `actor` field is server-resolved from the authenticated request context.

- callers must not supply `actor`
- supplying `actor` must fail with `400 Bad Request`

This rule does not override documented create-time exceptions on canonical tables such as `DecisionRecord`, whose own `actor` column is caller-supplied at creation.

See:

- `docs/api/api-conventions.md`

### Read-path project enforcement convention
All project-scoped read endpoints must resolve project context explicitly.

UUID-only reads that match a row in another project must behave as unavailable.
No cross-project existence leakage is allowed.

### Same-project validation convention
Where a row references another project-scoped row:

- direct FK is not enough when `projectId` must also match
- validate referenced row existence and same-project ownership in the service layer before commit

### Polymorphic reference convention
All polymorphic references should resolve through one central resolver service.

The resolver should:

- validate allowed entity type
- load the referenced row by entity type and id
- verify same-project ownership
- return a normalized resolution result
- fail with deterministic error shape when the reference is invalid
- return the same error shape for cross-project targets as for non-existent targets; no cross-project existence leakage is allowed

Do not duplicate polymorphic resolution logic per endpoint family.

### Internal service mutation discipline
Internal server-side mutation paths must follow the same mutation safety rules as public routes where the same fields and invariants are involved.

That means:

- no forbidden field mutation
- no hidden state transition bypass
- atomicity rules still apply
- `StatusHistory` requirements still apply where defined
- server-owned fields remain server-owned even when no public endpoint family exists

---

## 1. `Project`

### Build now

#### SQL
```sql
create table "Project" (
  "id" uuid primary key,
  "key" text not null,
  "name" text not null,
  "status" text not null default 'active',
  "description" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "project_key_non_empty" check (btrim("key") <> ''),
  constraint "project_name_non_empty" check (btrim("name") <> '')
);

create unique index "project_key_uq" on "Project" ("key");
create index "project_status_updatedAt_id_idx"
  on "Project" ("status", "updatedAt" desc, "id");
```

#### Application validation
- enforce governed project key format
- validate `status` against project status vocabulary
- reject caller attempts to mutate fields outside allowed set

### Transition and history hook
- project status changes must run through governed transition validator
- every allowed transition writes `StatusHistory(entityType = 'project')` atomically
- `active -> archived` and `deferred -> archived` require explicit non-empty reason

### Immediate hammer cases
- create with empty `key` fails
- create with duplicate `key` fails
- invalid status value fails
- caller-supplied `status` on create fails with `400`
- forbidden `archived -> active` fails
- required-reason archive transition without reason fails
- status transition without matching history row is impossible

---

## 2. `Objective`

### Build now

#### SQL
```sql
create table "Objective" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "key" text not null,
  "title" text not null,
  "description" text null,
  "status" text not null default 'proposed',
  "priority" integer not null default 100,
  "targetStartAt" timestamptz null,
  "targetEndAt" timestamptz null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "objective_key_non_empty" check (btrim("key") <> ''),
  constraint "objective_title_non_empty" check (btrim("title") <> ''),
  constraint "objective_priority_range" check ("priority" between 1 and 1000),
  constraint "objective_target_date_order"
    check (
      "targetStartAt" is null
      or "targetEndAt" is null
      or "targetEndAt" >= "targetStartAt"
    )
);

create unique index "objective_projectId_key_uq"
  on "Objective" ("projectId", "key");
create index "objective_projectId_status_priority_updatedAt_id_idx"
  on "Objective" ("projectId", "status", "priority", "updatedAt" desc, "id");
```

#### Application validation
- enforce governed key format
- validate `status` vocabulary
- reject out-of-scope project access on reads and writes

### Transition and history hook
- status transitions use governed route/path only
- every transition writes `StatusHistory(entityType = 'objective')`
- `blocked -> archived` and `proposed -> archived` require explicit non-empty reason
- `active -> archived` is **forbidden** per `docs/architecture/data/status-transitions.md`; it must not be implemented as allowed-with-reason

### Authority conflict note
`docs/api/objectives-api.md` currently lists `active -> archived` with reason, while `docs/architecture/data/status-transitions.md` does not include `active -> archived` as an allowed Objective transition.

Until that conflict is resolved explicitly, treat `docs/architecture/data/status-transitions.md` as authoritative for Objective transition legality. The transition validator must reject `active -> archived` for Objectives.

### Archived-parent hook
- if parent project is archived, reject new objective creation
- objective archival freezes normal child initiative growth beneath it

### Immediate hammer cases
- duplicate `(projectId, key)` fails
- invalid priority fails with `422`
- caller-supplied `status` on create fails with `400`
- `targetEndAt < targetStartAt` fails
- UUID-only read from another project behaves unavailable
- forbidden transitions fail with `422`
- `active -> archived` fails with `422` (forbidden, not reason-gated)
- archive from `blocked` or `proposed` without reason fails with `400`

---

## 3. `Initiative`

### Build now

#### SQL
```sql
create table "Initiative" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "objectiveId" uuid null references "Objective"("id"),
  "key" text not null,
  "title" text not null,
  "description" text null,
  "status" text not null default 'proposed',
  "priority" integer not null default 100,
  "targetSystem" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "initiative_key_non_empty" check (btrim("key") <> ''),
  constraint "initiative_title_non_empty" check (btrim("title") <> ''),
  constraint "initiative_priority_range" check ("priority" between 1 and 1000)
);

create unique index "initiative_projectId_key_uq"
  on "Initiative" ("projectId", "key");
create index "initiative_projectId_objectiveId_idx"
  on "Initiative" ("projectId", "objectiveId");
create index "initiative_projectId_status_priority_updatedAt_id_idx"
  on "Initiative" ("projectId", "status", "priority", "updatedAt" desc, "id");
create index "initiative_projectId_targetSystem_updatedAt_id_idx"
  on "Initiative" ("projectId", "targetSystem", "updatedAt" desc, "id");
```

#### Application validation
- enforce governed key format
- validate `status` vocabulary
- validate optional `targetSystem` vocabulary
- if `objectiveId` is present, verify referenced objective belongs to same `projectId`
- reject create or re-parent under archived objective

### Transition and history hook
- status transitions use governed route/path only
- every transition writes `StatusHistory(entityType = 'initiative')`
- `blocked -> archived` and `proposed -> archived` require explicit non-empty reason
- `active -> archived` is **forbidden** per `docs/architecture/data/status-transitions.md`; it must not be implemented as allowed-with-reason

### Authority conflict note
`docs/api/initiatives-api.md` currently lists `active -> archived` with reason, while `docs/architecture/data/status-transitions.md` does not include `active -> archived` as an allowed Initiative transition.

Until that conflict is resolved explicitly, treat `docs/architecture/data/status-transitions.md` as authoritative for Initiative transition legality. The transition validator must reject `active -> archived` for Initiatives.

### Immediate hammer cases
- cross-project `objectiveId` linkage fails
- caller-supplied `status` on create fails with `400`
- create under archived objective fails
- re-parent active initiative under archived objective fails
- invalid `targetSystem` fails
- forbidden transitions fail deterministically
- `active -> archived` fails with `422` (forbidden, not reason-gated)
- archive from `blocked` or `proposed` without reason fails with `400`

---

## 4. `WorkItem`

### Build now

#### SQL
```sql
create table "WorkItem" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "initiativeId" uuid null references "Initiative"("id"),
  "key" text not null,
  "title" text not null,
  "description" text null,
  "type" text not null,
  "status" text not null default 'proposed',
  "readinessState" text not null default 'unevaluated',
  "targetSystem" text not null,
  "blocked" boolean not null default false,
  "blockedReason" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "workItem_key_non_empty" check (btrim("key") <> ''),
  constraint "workItem_title_non_empty" check (btrim("title") <> '')
);

create unique index "workItem_projectId_key_uq"
  on "WorkItem" ("projectId", "key");
create index "workItem_projectId_initiativeId_idx"
  on "WorkItem" ("projectId", "initiativeId");
create index "workItem_projectId_status_updatedAt_id_idx"
  on "WorkItem" ("projectId", "status", "updatedAt" desc, "id");
create index "workItem_projectId_readinessState_updatedAt_id_idx"
  on "WorkItem" ("projectId", "readinessState", "updatedAt" desc, "id");
create index "workItem_projectId_targetSystem_updatedAt_id_idx"
  on "WorkItem" ("projectId", "targetSystem", "updatedAt" desc, "id");
create index "workItem_projectId_blocked_updatedAt_id_idx"
  on "WorkItem" ("projectId", "blocked", "updatedAt" desc, "id");
```

#### Application validation
- enforce governed key format
- validate `type`, `status`, `readinessState`, `targetSystem`
- if `initiativeId` is present, verify same-project initiative
- reject create or re-parent under archived initiative
- if `blocked = true`, require non-empty `blockedReason`
- reject caller attempts to mutate `readinessState` with `400 Bad Request`

### Transition and history hook
- status transitions use governed route/path only
- every transition writes `StatusHistory(entityType = 'work_item')`
- `blocked -> archived` and `proposed -> archived` require explicit non-empty reason
- `readinessState` changes only through readiness evaluation service logic

### Readiness sync hook
When a new readiness evaluation is created for a work item:
- create `ReadinessEvaluation`
- create any required `ReadinessGap` rows
- update `WorkItem.readinessState`
- do all three atomically

### Immediate hammer cases
- caller-supplied `status` on create fails with `400`
- caller-supplied `readinessState` on create or patch is rejected with `400`
- cross-project `initiativeId` linkage fails
- create under archived initiative fails
- `blocked = true` without reason fails
- `proposed -> completed` fails
- archive from `blocked` or `proposed` without reason fails with `400`
- stale required audit invalidation resets readiness state to `unevaluated`

---

## 5. `Dependency`

### Build now

#### SQL
```sql
create table "Dependency" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "sourceEntityType" text not null,
  "sourceEntityId" uuid not null,
  "targetEntityType" text not null,
  "targetEntityId" uuid not null,
  "dependencyType" text not null,
  "status" text not null default 'active',
  "rationale" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "dependency_not_self"
    check (not ("sourceEntityType" = "targetEntityType" and "sourceEntityId" = "targetEntityId"))
);

create unique index "dependency_project_scope_logical_uq"
  on "Dependency" (
    "projectId",
    "sourceEntityType",
    "sourceEntityId",
    "targetEntityType",
    "targetEntityId",
    "dependencyType"
  );
create index "dependency_project_source_idx"
  on "Dependency" ("projectId", "sourceEntityType", "sourceEntityId");
create index "dependency_project_target_idx"
  on "Dependency" ("projectId", "targetEntityType", "targetEntityId");
create index "dependency_project_status_updatedAt_id_idx"
  on "Dependency" ("projectId", "status", "updatedAt" desc, "id");
```

#### Application validation
- validate source and target entity types against dependency entity vocabulary
- validate `dependencyType` and `status`
- resolve both polymorphic endpoints through the central resolver
- require both endpoints to belong to same `projectId`

### Mutation hook
- bounded update only for `status` and `rationale`
- `active -> resolved` allowed
- `resolved -> active` forbidden
- dependency status transitions do not require `StatusHistory`

### Immediate hammer cases
- cross-project dependency creation fails
- duplicate logical dependency fails with conflict
- self-dependency fails
- invalid entity type fails
- forbidden reopen transition fails

---

## 6. `DecisionRecord`

### Build now

#### SQL
```sql
create table "DecisionRecord" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "entityType" text null,
  "entityId" uuid null,
  "title" text not null,
  "decisionSummary" text not null,
  "rationale" text not null,
  "status" text not null,
  "actor" text not null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "decisionRecord_title_non_empty" check (btrim("title") <> ''),
  constraint "decisionRecord_summary_non_empty" check (btrim("decisionSummary") <> ''),
  constraint "decisionRecord_rationale_non_empty" check (btrim("rationale") <> '')
);

create index "decisionRecord_project_createdAt_id_idx"
  on "DecisionRecord" ("projectId", "createdAt" desc, "id");
create index "decisionRecord_project_entity_createdAt_id_idx"
  on "DecisionRecord" ("projectId", "entityType", "entityId", "createdAt" desc, "id");
create index "decisionRecord_project_status_createdAt_id_idx"
  on "DecisionRecord" ("projectId", "status", "createdAt" desc, "id");
```

#### Application validation
- validate `status`
- if `entityType` and `entityId` are present, resolve polymorphic entity and enforce same-project ownership
- require non-empty `actor`
- creation requires caller-supplied `status` and `actor`; this is an intentional exception to the usual lifecycle-entity creation pattern

### Transition and history hook
- only governed transition: `recorded -> superseded`
- DecisionRecord PATCH allows `status` as the only mutable column
- the PATCH body also accepts `reason` as a required transition parameter for the `recorded -> superseded` transition; `reason` is consumed by `StatusHistory` and is not a stored DecisionRecord column; it must not be rejected by unknown-field validation
- supersedence requires explicit non-empty reason
- transition writes `StatusHistory(entityType = 'decision_record')` atomically

### Immediate hammer cases
- empty title/summary/rationale fails
- cross-project related entity fails
- create without required caller-supplied `status` or `actor` fails
- `superseded -> recorded` fails
- supersede without reason fails with `400`
- supersede without history row is impossible
- PATCH body with `reason` on `recorded -> superseded` is accepted (not rejected as unknown field)

---

## 7. `ReadinessEvaluation`

### Build now

#### SQL
```sql
create table "ReadinessEvaluation" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "entityType" text not null,
  "entityId" uuid not null,
  "evaluationType" text not null,
  "result" text not null,
  "rulePackage" text not null,
  "summary" text not null,
  "createdAt" timestamptz not null default now(),
  constraint "readinessEvaluation_summary_non_empty" check (btrim("summary") <> '')
);

create index "readinessEvaluation_project_entity_createdAt_id_idx"
  on "ReadinessEvaluation" ("projectId", "entityType", "entityId", "createdAt" desc, "id");
create index "readinessEvaluation_project_result_createdAt_id_idx"
  on "ReadinessEvaluation" ("projectId", "result", "createdAt" desc, "id");
create index "readinessEvaluation_project_evalType_createdAt_id_idx"
  on "ReadinessEvaluation" ("projectId", "evaluationType", "createdAt" desc, "id");
```

#### Application validation
- resolve target entity polymorphically and enforce same-project scope
- validate `entityType`, `evaluationType`, and caller-supplied `rulePackage` override where present
- validate `rulePackage` against governed package mapping and allowed overrides
- rule package defaults and override semantics are governed by `docs/architecture/data/controlled-vocabularies.md` under `Rule Package Vocabulary`
- compute canonical result on server
- generate non-empty summary on server
- callers must not supply canonical `result` or `summary`
- caller input may identify the target entity, evaluation type, optional valid rule-package override, and optional `deferWithReason` (non-empty string to produce a `deferred` result per Condition 2 in `docs/architecture/core/readiness-evaluation-rules.md`)

### Inspectable basis rule
The readiness evaluation service must produce an inspectable basis.

That means:

- a non-empty summary explaining what was evaluated
- any required `ReadinessGap` rows where failed conditions warrant them

A `ReadinessEvaluation` row with only a result and no recoverable basis is invalid.

### Mutation hook
- create only in first pass
- prior evaluations remain historical records; they are not deleted or mutated when a new evaluation is created
- no generic update or delete

### Immediate hammer cases
- caller cannot override server-owned result
- caller cannot supply canonical summary
- missing inspectable basis fails
- identical inputs produce identical result
- invalid rule package fails with `422`
- required audit failure constrains readiness correctly
- caller-supplied unsupported defer intent shape fails deterministically
- valid `deferWithReason` string produces `deferred` result

---

## 8. `ReadinessGap`

### Build now

#### SQL
```sql
create table "ReadinessGap" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "readinessEvaluationId" uuid not null references "ReadinessEvaluation"("id"),
  "severity" text not null,
  "description" text not null,
  "remediationSuggestion" text null,
  "resolved" boolean not null default false,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "readinessGap_description_non_empty" check (btrim("description") <> '')
);

create index "readinessGap_project_readinessEvaluationId_idx"
  on "ReadinessGap" ("projectId", "readinessEvaluationId");
create index "readinessGap_project_resolved_severity_createdAt_id_idx"
  on "ReadinessGap" ("projectId", "resolved", "severity", "createdAt" desc, "id");
```

#### Application validation
- validate same-project linkage to readiness evaluation
- validate severity vocabulary
- enforce non-empty description
- use severity-rank mapping for ordered read surfaces

### Mutation hook
- bounded update of `resolved` and `remediationSuggestion`
- toggling `resolved` both directions is allowed in first pass

### Immediate hammer cases
- orphan gap creation fails
- cross-project readiness evaluation linkage fails
- hard-block readiness failure creates required gap rows
- severity ordering uses canonical rank, not text sort

---

## 9. `ResearchDoc`

### Build now

#### SQL
```sql
create table "ResearchDoc" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "title" text not null,
  "sourceType" text not null,
  "storageLocator" text not null,
  "status" text not null,
  "summary" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "researchDoc_title_non_empty" check (btrim("title") <> ''),
  constraint "researchDoc_storageLocator_non_empty" check (btrim("storageLocator") <> '')
);

create index "researchDoc_project_status_updatedAt_id_idx"
  on "ResearchDoc" ("projectId", "status", "updatedAt" desc, "id");
create index "researchDoc_project_sourceType_updatedAt_id_idx"
  on "ResearchDoc" ("projectId", "sourceType", "updatedAt" desc, "id");
```

#### Application validation
- validate `sourceType` and `status`
- preserve provenance visibility for imported or external material
- creation requires caller-supplied `status`; this is an intentional exception to the usual lifecycle-entity creation pattern

### Mutation hook
- bounded patch for `title`, `status`, `summary`, `storageLocator`
- when a `ResearchDoc` PATCH transitions `status` from `active` to `archived`, the PATCH body must include a non-empty `reason` field; missing or empty `reason` must fail with `400 Bad Request`
- `reason` is a transition parameter consumed by the archival enforcement logic; it is not a stored ResearchDoc column and must not be rejected by unknown-field validation
- `active -> archived` reason enforcement is not waived by using PATCH instead of a dedicated `/status` route
- `archived -> active` forbidden

### Immediate hammer cases
- empty locator fails
- invalid source type fails
- archive without reason fails
- PATCH body with `reason` on `active -> archived` is accepted (not rejected as unknown field)
- unarchive attempt fails

---

## 10. `EvidenceLink`

### Build now

#### SQL
```sql
create table "EvidenceLink" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "sourceEntityType" text not null,
  "sourceEntityId" uuid not null,
  "evidenceType" text not null,
  "targetLocator" text not null,
  "note" text null,
  "relevanceScore" integer null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "evidenceLink_targetLocator_non_empty" check (btrim("targetLocator") <> ''),
  constraint "evidenceLink_relevanceScore_range"
    check ("relevanceScore" is null or "relevanceScore" between 0 and 100)
);

create index "evidenceLink_project_source_createdAt_id_idx"
  on "EvidenceLink" ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" desc, "id");
create index "evidenceLink_project_evidenceType_createdAt_id_idx"
  on "EvidenceLink" ("projectId", "evidenceType", "createdAt" desc, "id");
create index "evidenceLink_project_source_updatedAt_id_idx"
  on "EvidenceLink" ("projectId", "sourceEntityType", "sourceEntityId", "updatedAt" desc, "id");
```

#### Application validation
- validate source entity type and evidence type vocabularies
- resolve source entity polymorphically and enforce same-project scope
- keep link semantics directional and honest

### Mutation hook
- bounded patch only for `note` and `relevanceScore`

### Immediate hammer cases
- cross-project source linkage fails
- invalid relevance score fails
- non-empty locator enforced
- evidence link does not claim ownership of external truth

---

## 11. `Handoff`

### Build now

#### SQL
```sql
create table "Handoff" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "sourceEntityType" text not null,
  "sourceEntityId" uuid not null,
  "targetSystem" text not null,
  "handoffType" text not null,
  "status" text not null default 'proposed',
  "readinessBasisSummary" text null,
  "createdAt" timestamptz not null default now(),
  "completedAt" timestamptz null,
  "updatedAt" timestamptz not null default now(),
  constraint "handoff_completedAt_after_createdAt"
    check ("completedAt" is null or "completedAt" >= "createdAt")
);

create index "handoff_project_status_createdAt_id_idx"
  on "Handoff" ("projectId", "status", "createdAt" desc, "id");
create index "handoff_project_targetSystem_createdAt_id_idx"
  on "Handoff" ("projectId", "targetSystem", "createdAt" desc, "id");
create index "handoff_project_source_createdAt_id_idx"
  on "Handoff" ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" desc, "id");
```

#### Application validation
- validate `sourceEntityType`, `targetSystem`, `handoffType`, `status`
- resolve source entity polymorphically and enforce same-project scope
- validate forward and reverse transition legality
- `targetSystem` is immutable after creation; attempts to PATCH it must fail with `400 Bad Request`
- `completedAt` is server-managed and caller-forbidden

### Mutation hook
- bounded patch only for `readinessBasisSummary`
- callers must not supply `completedAt` at creation or PATCH; it is set only by the governed transition to `closed`

### Transition and history hook
- every governed transition writes `StatusHistory(entityType = 'handoff')`
- the following transitions require explicit non-empty reason:
  - `proposed -> closed`
  - `ready -> closed`
  - `handed_off -> closed`
  - `handed_off -> ready`
  - `handed_off -> proposed`
- when transitioning to `closed`, set `completedAt = now()` atomically
- reverse transitions are operator-initiated only and must be explicit

### Immediate hammer cases
- caller-supplied `status` on create fails with `400`
- invalid target system fails
- forbidden: `proposed -> accepted` fails with `422`
- forbidden: `accepted -> ready` fails with `422`
- reason-required: `handed_off -> ready` without reason fails with `400`
- caller-supplied `completedAt` fails with `400`
- `closed` transition stamps `completedAt`

---

## 12. `StatusHistory`

### Build now

#### SQL
```sql
create table "StatusHistory" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "entityType" text not null,
  "entityId" uuid not null,
  "previousStatus" text null,
  "newStatus" text not null,
  "reason" text null,
  "actor" text not null,
  "createdAt" timestamptz not null default now(),
  constraint "statusHistory_newStatus_non_empty" check (btrim("newStatus") <> ''),
  constraint "statusHistory_actor_non_empty" check (btrim("actor") <> '')
);

create index "statusHistory_project_entity_createdAt_id_idx"
  on "StatusHistory" ("projectId", "entityType", "entityId", "createdAt" desc, "id");
create index "statusHistory_project_createdAt_id_idx"
  on "StatusHistory" ("projectId", "createdAt" desc, "id");
```

#### Application validation
- validate `entityType` against the governed Status History Entity Type vocabulary; the full allowed set is: `project`, `objective`, `initiative`, `work_item`, `handoff`, `decision_record`, `audit_run` (see `docs/architecture/data/controlled-vocabularies.md`)
- resolve referenced entity and enforce same-project scope
- allow nullable `previousStatus` for first recorded transition
- `actor` is server-resolved from the authenticated request context and must not be caller-supplied

### Mutation hook
- create only
- no update or delete
- API remains write-only in first pass

### Immediate hammer cases
- invalid entity type fails
- caller-supplied `actor` fails with `400`
- history row for wrong project fails
- required transition cannot commit without matching history row
- `decision_record` and `audit_run` entity types are accepted

---

## 13. `AuditRun`

### Build now

#### SQL
```sql
create table "AuditRun" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "auditType" text not null,
  "targetEntityType" text null,
  "targetEntityId" uuid null,
  "result" text not null,
  "summary" text not null,
  "startedAt" timestamptz null,
  "completedAt" timestamptz null,
  "createdAt" timestamptz not null default now(),
  constraint "auditRun_summary_non_empty" check (btrim("summary") <> ''),
  constraint "auditRun_completedAt_after_startedAt"
    check (
      "startedAt" is null
      or "completedAt" is null
      or "completedAt" >= "startedAt"
    )
);

create index "auditRun_project_auditType_createdAt_id_idx"
  on "AuditRun" ("projectId", "auditType", "createdAt" desc, "id");
create index "auditRun_project_result_createdAt_id_idx"
  on "AuditRun" ("projectId", "result", "createdAt" desc, "id");
create index "auditRun_project_target_createdAt_id_idx"
  on "AuditRun" ("projectId", "targetEntityType", "targetEntityId", "createdAt" desc, "id");
```

#### Application validation
- validate `auditType` and `result`
- if target is present, resolve polymorphically and enforce same-project scope
- when `targetEntityType = 'project'`, same-project check is `AuditRun.projectId == targetEntityId`; the resolver must not attempt to read `projectId` from the Project row
- the audit execution path must verify that `auditType` is valid for the supplied `targetEntityType` per the governed allowed-target mapping; polymorphic resolution alone is not sufficient
- the governed audit-type to allowed-target-entity mapping is defined in `docs/architecture/data/audit-and-gap-model.md` under "First-Pass Audit Types"; each audit type lists its allowed targets explicitly (e.g. `code_alignment` targets only `work_item` and `handoff`; `hygiene` targets all five entity types)
- server computes canonical audit result
- `AuditRun.summary` is server-generated; callers must not supply canonical summary content
- no direct public first-pass endpoint family

### Mutation hook
- AuditRun is not create-only in the same way as `ReadinessEvaluation`
- governed invalidation may mutate `result` from `pass`, `fail`, or `warning` to `stale`
- governed invalidation may update `summary` where invalidation context requires it
- no other `result` mutations are allowed

### Transition and history hook
- initial execution may create `pass`, `fail`, or `warning`
- governed invalidation may transition prior result to `stale`
- staleness transition writes `StatusHistory(entityType = 'audit_run')` atomically

### Immediate hammer cases
- caller cannot set canonical result through public mutation path
- caller cannot supply canonical summary
- invalid target scope fails
- invalid audit-type for target entity-type fails deterministically
- contradiction detection produces deterministic fail or warning result
- staleness transition requires explicit reason and matching history row

---

## 14. `AuditGap`

### Build now

#### SQL
```sql
create table "AuditGap" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "auditRunId" uuid not null references "AuditRun"("id"),
  "severity" text not null,
  "description" text not null,
  "remediation" text null,
  "status" text not null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "auditGap_description_non_empty" check (btrim("description") <> '')
);

create index "auditGap_project_auditRunId_idx"
  on "AuditGap" ("projectId", "auditRunId");
create index "auditGap_project_status_severity_createdAt_id_idx"
  on "AuditGap" ("projectId", "status", "severity", "createdAt" desc, "id");
```

#### Application validation
- validate same-project linkage to `AuditRun`
- validate severity and status vocabularies
- use severity-rank mapping for ordered read surfaces
- no dedicated public first-pass endpoint family

### Mutation hook
- bounded update only for `status` and `remediation`
- enforce status transition legality:
  - `open -> resolved`
  - `open -> invalidated` with reason
  - `resolved -> invalidated` with reason

### Immediate hammer cases
- orphan gap creation fails
- cross-project audit linkage fails
- invalidated gap cannot reopen
- severity ordering uses canonical rank

---

## 15. `GitHubLink`

### Build now

#### SQL
```sql
create table "GitHubLink" (
  "id" uuid primary key,
  "projectId" uuid not null references "Project"("id"),
  "sourceEntityType" text not null,
  "sourceEntityId" uuid not null,
  "linkType" text not null,
  "url" text not null,
  "externalId" text null,
  "label" text null,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  constraint "githubLink_url_non_empty" check (btrim("url") <> '')
);

create unique index "githubLink_project_source_linkType_url_uq"
  on "GitHubLink" ("projectId", "sourceEntityType", "sourceEntityId", "linkType", "url");
create index "githubLink_project_source_createdAt_id_idx"
  on "GitHubLink" ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" desc, "id");
create index "githubLink_project_linkType_createdAt_id_idx"
  on "GitHubLink" ("projectId", "linkType", "createdAt" desc, "id");
create index "githubLink_project_updatedAt_id_idx"
  on "GitHubLink" ("projectId", "updatedAt" desc, "id");
```

#### Application validation
- validate source entity type and link type vocabularies
- resolve source entity polymorphically and enforce same-project scope
- require `url` to begin with `https://`
- do not validate remote URL existence in first pass
- duplicate logical linkage fails with `409 Conflict`
- `linkType` is immutable after creation

### Mutation hook
- bounded patch for `label`, `url`, `externalId`
- no governed status lifecycle in first pass

### Immediate hammer cases
- non-https URL fails
- cross-project source linkage fails
- duplicate logical link fails with `409`
- attempt to patch `linkType` fails with `400`
- link does not imply GitHub ownership over Project V truth

---

## Cross-Table Service Hooks

## 1. Polymorphic entity resolver

Build one shared resolver for these tables and flows:

- `Dependency`
- `DecisionRecord`
- `ReadinessEvaluation`
- `EvidenceLink`
- `Handoff`
- `AuditRun`
- `GitHubLink`
- `StatusHistory`

Resolver contract should return:
- resolved entity type
- entity id
- project id
- current status if applicable
- archived flag if applicable

When `entityType = 'project'`, the target row is the `Project` table itself, which has no `projectId` column. The same-project check for this case is `ownerRow.projectId == targetEntityId`. The resolver must handle this explicitly and must not attempt to read `projectId` from the resolved Project row.

## 2. Archived-parent guard

Build one shared guard for:
- create objective under project
- create initiative under project or under objective
- create work item under project or under initiative
- patch initiative objective link
- patch work item initiative link

The guard must reject:
- new child creation when the owning project is archived
- new child creation under an archived parent entity (objective or initiative)
- re-parenting active child under archived parent entity

## 3. Transition validator

Build one central transition validator keyed by:
- entity family
- previous status
- target status
- optional reason

It should return:
- allowed or forbidden
- reason-required yes or no
- whether `StatusHistory` is mandatory
- any side effects such as `Handoff.completedAt = now()`

## 4. Severity ordering helper

Build one shared ordering helper for:
- `ReadinessGap`
- `AuditGap`

Canonical mapping:
- `critical` = 4
- `major` = 3
- `minor` = 2
- `advisory` = 1

Never rely on raw text sort.

## 5. Vocabulary registry

Build one shared vocabulary source in code for all first-pass controlled values.

Do not let route handlers or repository classes hand-roll local copies.

## 6. Audit-readiness coupling

When readiness evaluation considers audit state, the following rules apply:

- required audit `fail` normally produces `not_ready`
- required audit `warning` may allow `ready_with_warnings` only when findings are non-blocking
- required audit `stale` forces re-evaluation and invalidates prior readiness confidence

A readiness evaluation that ignores required audit state is invalid.

Re-evaluation should occur when:

- a required audit becomes `stale`
- a required audit result changes materially in a way that weakens readiness confidence
- a superseding decision changes scope or sequencing materially
- materially relevant linkage or implementation evidence changes invalidate the prior basis

For work items, invalidation resets `WorkItem.readinessState` to `unevaluated` until a new evaluation is recorded.

See:

- `docs/architecture/core/readiness-evaluation-rules.md`
- `docs/architecture/data/audit-and-gap-model.md`

## 7. Ready-with-warnings operator approval

Where workflow rules require explicit operator approval to proceed from `ready_with_warnings`, record that approval through a `DecisionRecord` in the same project.

The first-pass implementation should not silently treat `ready_with_warnings` as automatically approved for forward progression where governance requires an explicit approval record.

See:

- `docs/architecture/core/readiness-evaluation-rules.md`

---

## Immediate Build Order Inside the Codebase

### Step 1
Implement migration 001 and the shared vocabulary registry.

### Step 2
Implement central transition validator and same-project parent checks.

### Step 3
Implement migration 002 plus shared polymorphic resolver.

### Step 4
Implement readiness service with atomic work-item sync behavior.

### Step 5
Implement handoff service with transition side effects.

### Step 6
Implement audit execution service and audit invalidation path.

### Step 7
Add hammer coverage after each migration, not only at the end.

---

## Minimum Hammer Matrix By Phase

### After migration 001
- duplicate key failures
- invalid vocab failures
- create-body forbidden status fields fail with `400`
- cross-project reads unavailable
- forbidden status transitions rejected
- `active -> archived` rejected for Objective and Initiative (forbidden, not reason-gated)

### After migration 002
- illegal dependency edges fail
- dependency status transitions do not create `StatusHistory`
- required status history is always written where mandated
- decision supersedence works atomically
- DecisionRecord PATCH accepts `reason` as transition parameter without unknown-field rejection

### After migration 003
- readiness result is server-owned
- readiness summary is server-generated
- work-item readiness sync is atomic
- stale required audit invalidation behavior works
- `ready_with_warnings` approval recording works where required
- `deferWithReason` produces `deferred` result

### After migration 004
- archived-parent freeze is enforced
- handoff transition graph is enforced
- caller-supplied `completedAt` fails
- evidence and research stay bounded and honest
- ResearchDoc PATCH accepts `reason` as transition parameter on `active -> archived` without unknown-field rejection

### After migration 005
- audit contradiction detection is deterministic
- audit summaries are server-generated
- audit staleness transition is recoverable
- invalid audit-type for target entity-type is rejected
- GitHub links remain traceability only

---

## Final Rule

The first-pass schema should be built in a way that is:

- boring to reason about
- hard to misuse
- explicit about ownership
- strict about project scope
- aligned to readiness, audit, and history rules
- ready to hammer continuously during implementation
