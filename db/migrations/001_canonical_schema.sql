-- =============================================================================
-- MIGRATION 001 — Project V Canonical Schema
-- =============================================================================
-- Authority: docs/architecture/data/schema-authority.md
--            docs/architecture/data/schema-specification.md
--            docs/architecture/data/controlled-vocabularies.md
--            docs/architecture/data/polymorphic-reference-enforcement.md
--            docs/architecture/data/schema-governance.md
--            docs/architecture/core/system-invariants.md
--            docs/architecture/core/multi-project-doctrine.md
--
-- Target database: project_v_local
-- Target schema:   app
-- PostgreSQL:      17
--
-- Rules:
--   - No triggers for updatedAt (service-layer managed per schema-governance)
--   - No cascading deletes (no delete in first pass per schema-specification)
--   - Controlled vocabularies enforced via CHECK constraints
--   - Polymorphic entity types enforced via CHECK constraints
--   - Polymorphic same-project resolution enforced at application layer
--   - Parent-child same-project integrity enforced via composite foreign keys
--   - Key format enforced via CHECK: ^[a-z0-9]+(-[a-z0-9]+)*$
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Extension safety
-- gen_random_uuid() is built-in since PG 13, but pgcrypto ensures it exists
-- on any configuration.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Schema creation
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS app;

-- ---------------------------------------------------------------------------
-- 1. Project
-- Purpose: Project-scoped planning anchor for Project V orchestration.
-- Constraints: globally unique key, governed key format, non-empty name.
-- Status vocabulary: active, deferred, archived.
-- ---------------------------------------------------------------------------
CREATE TABLE app.project (
    id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    key             text            NOT NULL,
    name            text            NOT NULL,
    status          text            NOT NULL DEFAULT 'active',
    description     text            NULL,
    "createdAt"     timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"     timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT project_key_format
        CHECK (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(key) BETWEEN 3 AND 64),

    CONSTRAINT project_name_non_empty
        CHECK (char_length(trim(name)) > 0),

    CONSTRAINT project_status_vocab
        CHECK (status IN ('active', 'deferred', 'archived'))
);

CREATE UNIQUE INDEX uix_project_key
    ON app.project (key);

CREATE INDEX ix_project_status_updated
    ON app.project (status, "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 2. Objective
-- Purpose: Project-scoped major outcome.
-- Constraints: per-project unique key, governed key format, non-empty title.
-- Date ordering: targetEndAt >= targetStartAt when both present.
-- Priority range: 1..1000 per controlled-vocabularies.
-- Composite unique on (projectId, id) enables same-project FK from initiative.
-- ---------------------------------------------------------------------------
CREATE TABLE app.objective (
    id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"     uuid            NOT NULL REFERENCES app.project(id),
    key             text            NOT NULL,
    title           text            NOT NULL,
    description     text            NULL,
    status          text            NOT NULL DEFAULT 'proposed',
    priority        integer         NOT NULL DEFAULT 100,
    "targetStartAt" timestamptz     NULL,
    "targetEndAt"   timestamptz     NULL,
    "createdAt"     timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"     timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT objective_key_format
        CHECK (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(key) BETWEEN 3 AND 64),

    CONSTRAINT objective_title_non_empty
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT objective_status_vocab
        CHECK (status IN ('proposed', 'active', 'blocked', 'completed', 'archived')),

    CONSTRAINT objective_priority_range
        CHECK (priority BETWEEN 1 AND 1000),

    CONSTRAINT objective_date_ordering
        CHECK ("targetEndAt" IS NULL OR "targetStartAt" IS NULL OR "targetEndAt" >= "targetStartAt"),

    -- Enables composite FK target for same-project enforcement
    CONSTRAINT uq_objective_project_id UNIQUE ("projectId", id)
);

CREATE UNIQUE INDEX uix_objective_project_key
    ON app.objective ("projectId", key);

CREATE INDEX ix_objective_project_status_priority
    ON app.objective ("projectId", status, priority, "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 3. Initiative
-- Purpose: Project-scoped bounded body of work advancing an objective.
-- Constraints: per-project unique key, optional objectiveId with composite FK
-- enforcing same-project integrity at the database level.
-- Composite unique on (projectId, id) enables same-project FK from work_item.
-- ---------------------------------------------------------------------------
CREATE TABLE app.initiative (
    id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"     uuid            NOT NULL REFERENCES app.project(id),
    "objectiveId"   uuid            NULL,
    key             text            NOT NULL,
    title           text            NOT NULL,
    description     text            NULL,
    status          text            NOT NULL DEFAULT 'proposed',
    priority        integer         NOT NULL DEFAULT 100,
    "targetSystem"  text            NULL,
    "createdAt"     timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"     timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT initiative_key_format
        CHECK (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(key) BETWEEN 3 AND 64),

    CONSTRAINT initiative_title_non_empty
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT initiative_status_vocab
        CHECK (status IN ('proposed', 'active', 'blocked', 'completed', 'archived')),

    CONSTRAINT initiative_priority_range
        CHECK (priority BETWEEN 1 AND 1000),

    CONSTRAINT initiative_target_system_vocab
        CHECK ("targetSystem" IS NULL OR "targetSystem" IN ('project_v', 'veda', 'v_forge')),

    -- Same-project enforcement: objectiveId must belong to same project
    CONSTRAINT fk_initiative_objective_same_project
        FOREIGN KEY ("projectId", "objectiveId")
        REFERENCES app.objective ("projectId", id),

    -- Enables composite FK target for same-project enforcement
    CONSTRAINT uq_initiative_project_id UNIQUE ("projectId", id)
);

CREATE UNIQUE INDEX uix_initiative_project_key
    ON app.initiative ("projectId", key);

CREATE INDEX ix_initiative_project_objective
    ON app.initiative ("projectId", "objectiveId");

CREATE INDEX ix_initiative_project_status_priority
    ON app.initiative ("projectId", status, priority, "updatedAt" DESC, id);

CREATE INDEX ix_initiative_project_target_system
    ON app.initiative ("projectId", "targetSystem", "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 4. WorkItem
-- Purpose: Project-scoped planning or execution-preparation unit.
-- Constraints: per-project unique key, optional initiativeId with composite FK
-- enforcing same-project integrity at the database level.
-- blockedReason enforcement when blocked=true is application-layer per spec.
-- ---------------------------------------------------------------------------
CREATE TABLE app.work_item (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "initiativeId"      uuid            NULL,
    key                 text            NOT NULL,
    title               text            NOT NULL,
    description         text            NULL,
    type                text            NOT NULL,
    status              text            NOT NULL DEFAULT 'proposed',
    "readinessState"    text            NOT NULL DEFAULT 'unevaluated',
    "targetSystem"      text            NOT NULL,
    blocked             boolean         NOT NULL DEFAULT false,
    "blockedReason"     text            NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT work_item_key_format
        CHECK (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(key) BETWEEN 3 AND 64),

    CONSTRAINT work_item_title_non_empty
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT work_item_type_vocab
        CHECK (type IN ('analysis', 'planning', 'specification', 'handoff-preparation', 'governance')),

    CONSTRAINT work_item_status_vocab
        CHECK (status IN ('proposed', 'active', 'blocked', 'completed', 'archived')),

    CONSTRAINT work_item_readiness_state_vocab
        CHECK ("readinessState" IN ('unevaluated', 'not_ready', 'ready_with_warnings', 'ready', 'deferred')),

    CONSTRAINT work_item_target_system_vocab
        CHECK ("targetSystem" IN ('project_v', 'veda', 'v_forge')),

    -- Same-project enforcement: initiativeId must belong to same project
    CONSTRAINT fk_work_item_initiative_same_project
        FOREIGN KEY ("projectId", "initiativeId")
        REFERENCES app.initiative ("projectId", id)
);

CREATE UNIQUE INDEX uix_work_item_project_key
    ON app.work_item ("projectId", key);

CREATE INDEX ix_work_item_project_initiative
    ON app.work_item ("projectId", "initiativeId");

CREATE INDEX ix_work_item_project_status
    ON app.work_item ("projectId", status, "updatedAt" DESC, id);

CREATE INDEX ix_work_item_project_readiness
    ON app.work_item ("projectId", "readinessState", "updatedAt" DESC, id);

CREATE INDEX ix_work_item_project_target_system
    ON app.work_item ("projectId", "targetSystem", "updatedAt" DESC, id);

CREATE INDEX ix_work_item_project_blocked
    ON app.work_item ("projectId", blocked, "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 5. Dependency
-- Purpose: Explicit dependency relationship between Project V records.
-- Polymorphic: sourceEntityType/sourceEntityId, targetEntityType/targetEntityId.
-- Same-project enforcement for polymorphic targets is application-layer.
-- Self-reference prevention: source and target must not be identical pair.
-- Unique constraint prevents duplicate logical dependencies.
-- ---------------------------------------------------------------------------
CREATE TABLE app.dependency (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "sourceEntityType"  text            NOT NULL,
    "sourceEntityId"    uuid            NOT NULL,
    "targetEntityType"  text            NOT NULL,
    "targetEntityId"    uuid            NOT NULL,
    "dependencyType"    text            NOT NULL,
    status              text            NOT NULL DEFAULT 'active',
    rationale           text            NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT dependency_source_entity_type_vocab
        CHECK ("sourceEntityType" IN ('objective', 'initiative', 'work_item', 'handoff')),

    CONSTRAINT dependency_target_entity_type_vocab
        CHECK ("targetEntityType" IN ('objective', 'initiative', 'work_item', 'handoff')),

    CONSTRAINT dependency_type_vocab
        CHECK ("dependencyType" IN ('blocks', 'requires', 'relates_to')),

    CONSTRAINT dependency_status_vocab
        CHECK (status IN ('active', 'resolved')),

    CONSTRAINT dependency_no_self_reference
        CHECK (NOT ("sourceEntityType" = "targetEntityType" AND "sourceEntityId" = "targetEntityId"))
);

CREATE UNIQUE INDEX uix_dependency_logical
    ON app.dependency ("projectId", "sourceEntityType", "sourceEntityId", "targetEntityType", "targetEntityId", "dependencyType");

CREATE INDEX ix_dependency_project_source
    ON app.dependency ("projectId", "sourceEntityType", "sourceEntityId");

CREATE INDEX ix_dependency_project_target
    ON app.dependency ("projectId", "targetEntityType", "targetEntityId");

CREATE INDEX ix_dependency_project_status
    ON app.dependency ("projectId", status, "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 6. DecisionRecord
-- Purpose: Recoverable planning or orchestration decision.
-- Polymorphic: optional entityType/entityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- Status vocabulary: recorded, superseded.
-- Non-empty checks on title, decisionSummary, rationale, actor.
-- entityType and entityId must both be present or both be null.
-- ---------------------------------------------------------------------------
CREATE TABLE app.decision_record (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "entityType"        text            NULL,
    "entityId"          uuid            NULL,
    title               text            NOT NULL,
    "decisionSummary"   text            NOT NULL,
    rationale           text            NOT NULL,
    status              text            NOT NULL,
    actor               text            NOT NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT decision_record_title_non_empty
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT decision_record_summary_non_empty
        CHECK (char_length(trim("decisionSummary")) > 0),

    CONSTRAINT decision_record_rationale_non_empty
        CHECK (char_length(trim(rationale)) > 0),

    CONSTRAINT decision_record_actor_non_empty
        CHECK (char_length(trim(actor)) > 0),

    CONSTRAINT decision_record_status_vocab
        CHECK (status IN ('recorded', 'superseded')),

    CONSTRAINT decision_record_entity_type_vocab
        CHECK ("entityType" IS NULL OR "entityType" IN ('objective', 'initiative', 'work_item', 'handoff')),

    CONSTRAINT decision_record_entity_pair_integrity
        CHECK (("entityType" IS NULL AND "entityId" IS NULL) OR ("entityType" IS NOT NULL AND "entityId" IS NOT NULL))
);

CREATE INDEX ix_decision_record_project_created
    ON app.decision_record ("projectId", "createdAt" DESC, id);

CREATE INDEX ix_decision_record_project_entity
    ON app.decision_record ("projectId", "entityType", "entityId", "createdAt" DESC, id);

CREATE INDEX ix_decision_record_project_status
    ON app.decision_record ("projectId", status, "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 7. ReadinessEvaluation
-- Purpose: Inspectable readiness evaluation result.
-- Polymorphic: entityType/entityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- No updatedAt column (immutable after creation per schema-specification).
-- Composite unique on (projectId, id) enables same-project FK from readiness_gap.
-- ---------------------------------------------------------------------------
CREATE TABLE app.readiness_evaluation (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "entityType"        text            NOT NULL,
    "entityId"          uuid            NOT NULL,
    "evaluationType"    text            NOT NULL,
    result              text            NOT NULL,
    "rulePackage"       text            NOT NULL,
    summary             text            NOT NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT readiness_evaluation_entity_type_vocab
        CHECK ("entityType" IN ('objective', 'initiative', 'work_item', 'handoff')),

    CONSTRAINT readiness_evaluation_type_vocab
        CHECK ("evaluationType" IN ('research', 'planning', 'implementation_readiness', 'code_alignment', 'handoff', 'hygiene')),

    CONSTRAINT readiness_evaluation_result_vocab
        CHECK (result IN ('ready', 'not_ready', 'ready_with_warnings', 'deferred')),

    CONSTRAINT readiness_evaluation_summary_non_empty
        CHECK (char_length(trim(summary)) > 0),

    CONSTRAINT readiness_evaluation_rule_package_non_empty
        CHECK (char_length(trim("rulePackage")) > 0),

    -- Enables composite FK target for same-project enforcement
    CONSTRAINT uq_readiness_evaluation_project_id UNIQUE ("projectId", id)
);

CREATE INDEX ix_readiness_eval_project_entity
    ON app.readiness_evaluation ("projectId", "entityType", "entityId", "createdAt" DESC, id);

CREATE INDEX ix_readiness_eval_project_result
    ON app.readiness_evaluation ("projectId", result, "createdAt" DESC, id);

CREATE INDEX ix_readiness_eval_project_type
    ON app.readiness_evaluation ("projectId", "evaluationType", "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 8. ReadinessGap
-- Purpose: Explicit readiness deficiency or blocker from an evaluation.
-- Composite FK enforces same-project integrity with readiness_evaluation.
-- description must be non-empty.
-- ---------------------------------------------------------------------------
CREATE TABLE app.readiness_gap (
    id                          uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"                 uuid            NOT NULL REFERENCES app.project(id),
    "readinessEvaluationId"     uuid            NOT NULL,
    severity                    text            NOT NULL,
    description                 text            NOT NULL,
    "remediationSuggestion"     text            NULL,
    resolved                    boolean         NOT NULL DEFAULT false,
    "createdAt"                 timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"                 timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT readiness_gap_severity_vocab
        CHECK (severity IN ('critical', 'major', 'minor', 'advisory')),

    CONSTRAINT readiness_gap_description_non_empty
        CHECK (char_length(trim(description)) > 0),

    -- Same-project enforcement: evaluation must belong to same project
    CONSTRAINT fk_readiness_gap_evaluation_same_project
        FOREIGN KEY ("projectId", "readinessEvaluationId")
        REFERENCES app.readiness_evaluation ("projectId", id)
);

CREATE INDEX ix_readiness_gap_project_eval
    ON app.readiness_gap ("projectId", "readinessEvaluationId");

CREATE INDEX ix_readiness_gap_project_resolved_severity
    ON app.readiness_gap ("projectId", resolved, severity, "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 9. ResearchDoc
-- Purpose: Planning-support research artifact.
-- title and storageLocator must be non-empty.
-- ---------------------------------------------------------------------------
CREATE TABLE app.research_doc (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    title               text            NOT NULL,
    "sourceType"        text            NOT NULL,
    "storageLocator"    text            NOT NULL,
    status              text            NOT NULL,
    summary             text            NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT research_doc_title_non_empty
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT research_doc_storage_locator_non_empty
        CHECK (char_length(trim("storageLocator")) > 0),

    CONSTRAINT research_doc_source_type_vocab
        CHECK ("sourceType" IN ('manual', 'imported', 'veda_reference', 'external_reference')),

    CONSTRAINT research_doc_status_vocab
        CHECK (status IN ('active', 'archived'))
);

CREATE INDEX ix_research_doc_project_status
    ON app.research_doc ("projectId", status, "updatedAt" DESC, id);

CREATE INDEX ix_research_doc_project_source_type
    ON app.research_doc ("projectId", "sourceType", "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 10. EvidenceLink
-- Purpose: Directional link from planning truth to supporting evidence.
-- Polymorphic: sourceEntityType/sourceEntityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- targetLocator must be non-empty. relevanceScore range: 0..100.
-- ---------------------------------------------------------------------------
CREATE TABLE app.evidence_link (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "sourceEntityType"  text            NOT NULL,
    "sourceEntityId"    uuid            NOT NULL,
    "evidenceType"      text            NOT NULL,
    "targetLocator"     text            NOT NULL,
    note                text            NULL,
    "relevanceScore"    integer         NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT evidence_link_source_entity_type_vocab
        CHECK ("sourceEntityType" IN ('objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc')),

    CONSTRAINT evidence_link_type_vocab
        CHECK ("evidenceType" IN ('document', 'observation', 'decision_basis', 'external_reference')),

    CONSTRAINT evidence_link_target_locator_non_empty
        CHECK (char_length(trim("targetLocator")) > 0),

    CONSTRAINT evidence_link_relevance_score_range
        CHECK ("relevanceScore" IS NULL OR ("relevanceScore" BETWEEN 0 AND 100))
);

CREATE INDEX ix_evidence_link_project_source_created
    ON app.evidence_link ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" DESC, id);

CREATE INDEX ix_evidence_link_project_type
    ON app.evidence_link ("projectId", "evidenceType", "createdAt" DESC, id);

CREATE INDEX ix_evidence_link_project_source_updated
    ON app.evidence_link ("projectId", "sourceEntityType", "sourceEntityId", "updatedAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 11. Handoff
-- Purpose: Bounded transition of responsibility from Project V to another system.
-- Polymorphic: sourceEntityType/sourceEntityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- completedAt must not precede createdAt.
-- ---------------------------------------------------------------------------
CREATE TABLE app.handoff (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"             uuid            NOT NULL REFERENCES app.project(id),
    "sourceEntityType"      text            NOT NULL,
    "sourceEntityId"        uuid            NOT NULL,
    "targetSystem"          text            NOT NULL,
    "handoffType"           text            NOT NULL,
    status                  text            NOT NULL DEFAULT 'proposed',
    "readinessBasisSummary" text            NULL,
    "createdAt"             timestamptz     NOT NULL DEFAULT now(),
    "completedAt"           timestamptz     NULL,
    "updatedAt"             timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT handoff_source_entity_type_vocab
        CHECK ("sourceEntityType" IN ('objective', 'initiative', 'work_item')),

    CONSTRAINT handoff_target_system_vocab
        CHECK ("targetSystem" IN ('project_v', 'veda', 'v_forge')),

    CONSTRAINT handoff_type_vocab
        CHECK ("handoffType" IN ('execution', 'analysis', 'governance', 'review')),

    CONSTRAINT handoff_status_vocab
        CHECK (status IN ('proposed', 'ready', 'handed_off', 'accepted', 'closed')),

    CONSTRAINT handoff_completed_after_created
        CHECK ("completedAt" IS NULL OR "completedAt" >= "createdAt")
);

CREATE INDEX ix_handoff_project_status
    ON app.handoff ("projectId", status, "createdAt" DESC, id);

CREATE INDEX ix_handoff_project_target_system
    ON app.handoff ("projectId", "targetSystem", "createdAt" DESC, id);

CREATE INDEX ix_handoff_project_source
    ON app.handoff ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 12. StatusHistory
-- Purpose: Recoverable history for meaningful state changes.
-- Polymorphic: entityType/entityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- No updatedAt column (immutable after creation per schema-specification).
-- newStatus must be non-empty. previousStatus is nullable by design.
-- ---------------------------------------------------------------------------
CREATE TABLE app.status_history (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "entityType"        text            NOT NULL,
    "entityId"          uuid            NOT NULL,
    "previousStatus"    text            NULL,
    "newStatus"         text            NOT NULL,
    reason              text            NULL,
    actor               text            NOT NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT status_history_entity_type_vocab
        CHECK ("entityType" IN ('project', 'objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'audit_run')),

    CONSTRAINT status_history_new_status_non_empty
        CHECK (char_length(trim("newStatus")) > 0),

    CONSTRAINT status_history_actor_non_empty
        CHECK (char_length(trim(actor)) > 0)
);

CREATE INDEX ix_status_history_project_entity
    ON app.status_history ("projectId", "entityType", "entityId", "createdAt" DESC, id);

CREATE INDEX ix_status_history_project_created
    ON app.status_history ("projectId", "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 13. AuditRun
-- Purpose: Project-scoped BYDA-style audit execution.
-- Polymorphic: optional targetEntityType/targetEntityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- summary must be non-empty.
-- completedAt must not precede startedAt where both exist.
-- targetEntityType and targetEntityId must be both present or both null.
-- Composite unique on (projectId, id) enables same-project FK from audit_gap.
-- ---------------------------------------------------------------------------
CREATE TABLE app.audit_run (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"             uuid            NOT NULL REFERENCES app.project(id),
    "auditType"             text            NOT NULL,
    "targetEntityType"      text            NULL,
    "targetEntityId"        uuid            NULL,
    result                  text            NOT NULL,
    summary                 text            NOT NULL,
    "startedAt"             timestamptz     NULL,
    "completedAt"           timestamptz     NULL,
    "createdAt"             timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT audit_run_type_vocab
        CHECK ("auditType" IN ('research', 'planning', 'implementation_readiness', 'code_alignment', 'handoff', 'hygiene')),

    CONSTRAINT audit_run_result_vocab
        CHECK (result IN ('pass', 'fail', 'warning', 'stale')),

    CONSTRAINT audit_run_summary_non_empty
        CHECK (char_length(trim(summary)) > 0),

    CONSTRAINT audit_run_completed_after_started
        CHECK ("completedAt" IS NULL OR "startedAt" IS NULL OR "completedAt" >= "startedAt"),

    CONSTRAINT audit_run_target_entity_type_vocab
        CHECK ("targetEntityType" IS NULL OR "targetEntityType" IN ('project', 'objective', 'initiative', 'work_item', 'handoff')),

    CONSTRAINT audit_run_target_pair_integrity
        CHECK (("targetEntityType" IS NULL AND "targetEntityId" IS NULL) OR ("targetEntityType" IS NOT NULL AND "targetEntityId" IS NOT NULL)),

    -- Enables composite FK target for same-project enforcement
    CONSTRAINT uq_audit_run_project_id UNIQUE ("projectId", id)
);

CREATE INDEX ix_audit_run_project_type
    ON app.audit_run ("projectId", "auditType", "createdAt" DESC, id);

CREATE INDEX ix_audit_run_project_result
    ON app.audit_run ("projectId", result, "createdAt" DESC, id);

CREATE INDEX ix_audit_run_project_target
    ON app.audit_run ("projectId", "targetEntityType", "targetEntityId", "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 14. AuditGap
-- Purpose: Project-scoped audit deficiency or failure from an audit run.
-- Composite FK enforces same-project integrity with audit_run.
-- description must be non-empty.
-- Remediation column name per schema-specification field naming note.
-- ---------------------------------------------------------------------------
CREATE TABLE app.audit_gap (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "auditRunId"        uuid            NOT NULL,
    severity            text            NOT NULL,
    description         text            NOT NULL,
    remediation         text            NULL,
    status              text            NOT NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT audit_gap_severity_vocab
        CHECK (severity IN ('critical', 'major', 'minor', 'advisory')),

    CONSTRAINT audit_gap_status_vocab
        CHECK (status IN ('open', 'resolved', 'invalidated')),

    CONSTRAINT audit_gap_description_non_empty
        CHECK (char_length(trim(description)) > 0),

    -- Same-project enforcement: audit run must belong to same project
    CONSTRAINT fk_audit_gap_run_same_project
        FOREIGN KEY ("projectId", "auditRunId")
        REFERENCES app.audit_run ("projectId", id)
);

CREATE INDEX ix_audit_gap_project_run
    ON app.audit_gap ("projectId", "auditRunId");

CREATE INDEX ix_audit_gap_project_status_severity
    ON app.audit_gap ("projectId", status, severity, "createdAt" DESC, id);


-- ---------------------------------------------------------------------------
-- 15. GitHubLink
-- Purpose: Project-scoped bounded GitHub linkage for implementation traceability.
-- Polymorphic: sourceEntityType/sourceEntityId.
-- Same-project enforcement for polymorphic target is application-layer.
-- url must be non-empty; https:// format validation is application-layer per spec.
-- Unique constraint prevents duplicate logical linkage.
-- ---------------------------------------------------------------------------
CREATE TABLE app.github_link (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    "projectId"         uuid            NOT NULL REFERENCES app.project(id),
    "sourceEntityType"  text            NOT NULL,
    "sourceEntityId"    uuid            NOT NULL,
    "linkType"          text            NOT NULL,
    url                 text            NOT NULL,
    "externalId"        text            NULL,
    label               text            NULL,
    "createdAt"         timestamptz     NOT NULL DEFAULT now(),
    "updatedAt"         timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT github_link_source_entity_type_vocab
        CHECK ("sourceEntityType" IN ('objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc', 'audit_run')),

    CONSTRAINT github_link_type_vocab
        CHECK ("linkType" IN ('repository', 'branch', 'pull_request', 'commit', 'issue')),

    CONSTRAINT github_link_url_non_empty
        CHECK (char_length(trim(url)) > 0)
);

CREATE UNIQUE INDEX uix_github_link_logical
    ON app.github_link ("projectId", "sourceEntityType", "sourceEntityId", "linkType", url);

CREATE INDEX ix_github_link_project_source
    ON app.github_link ("projectId", "sourceEntityType", "sourceEntityId", "createdAt" DESC, id);

CREATE INDEX ix_github_link_project_type
    ON app.github_link ("projectId", "linkType", "createdAt" DESC, id);

CREATE INDEX ix_github_link_project_updated
    ON app.github_link ("projectId", "updatedAt" DESC, id);


COMMIT;
