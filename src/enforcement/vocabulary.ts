/**
 * enforcement/vocabulary.ts
 *
 * Controlled vocabulary registry.
 *
 * Authority: docs/architecture/data/controlled-vocabularies.md
 *
 * This is the single source of truth for allowed controlled-vocabulary values in
 * application logic. Route handlers and service modules must validate against this
 * registry and must not maintain local copies of allowed value sets.
 *
 * Rule: a vocabulary change is a governed architectural change.
 * Before adding or removing values, update controlled-vocabularies.md first.
 */

// ── Project ────────────────────────────────────────────────────────────────────
export const PROJECT_STATUSES = ['active', 'deferred', 'archived'] as const;
export type ProjectStatus = typeof PROJECT_STATUSES[number];

// ── Objective ─────────────────────────────────────────────────────────────────
export const OBJECTIVE_STATUSES = ['proposed', 'active', 'blocked', 'completed', 'archived'] as const;
export type ObjectiveStatus = typeof OBJECTIVE_STATUSES[number];

// ── Initiative ────────────────────────────────────────────────────────────────
export const INITIATIVE_STATUSES = ['proposed', 'active', 'blocked', 'completed', 'archived'] as const;
export type InitiativeStatus = typeof INITIATIVE_STATUSES[number];

export const INITIATIVE_TARGET_SYSTEMS = ['project_v', 'veda', 'v_forge'] as const;
export type InitiativeTargetSystem = typeof INITIATIVE_TARGET_SYSTEMS[number];

// ── WorkItem ──────────────────────────────────────────────────────────────────
export const WORK_ITEM_STATUSES = ['proposed', 'active', 'blocked', 'completed', 'archived'] as const;
export type WorkItemStatus = typeof WORK_ITEM_STATUSES[number];

export const WORK_ITEM_TYPES = [
  'analysis', 'planning', 'specification', 'handoff-preparation', 'governance',
] as const;
export type WorkItemType = typeof WORK_ITEM_TYPES[number];

export const WORK_ITEM_READINESS_STATES = [
  'unevaluated', 'not_ready', 'ready_with_warnings', 'ready', 'deferred',
] as const;
export type WorkItemReadinessState = typeof WORK_ITEM_READINESS_STATES[number];

export const WORK_ITEM_TARGET_SYSTEMS = ['project_v', 'veda', 'v_forge'] as const;
export type WorkItemTargetSystem = typeof WORK_ITEM_TARGET_SYSTEMS[number];

// ── Dependency ────────────────────────────────────────────────────────────────
export const DEPENDENCY_TYPES = ['blocks', 'requires', 'relates_to'] as const;
export type DependencyType = typeof DEPENDENCY_TYPES[number];

export const DEPENDENCY_STATUSES = ['active', 'resolved'] as const;
export type DependencyStatus = typeof DEPENDENCY_STATUSES[number];

export const DEPENDENCY_ENTITY_TYPES = ['objective', 'initiative', 'work_item', 'handoff'] as const;
export type DependencyEntityType = typeof DEPENDENCY_ENTITY_TYPES[number];

// ── DecisionRecord ────────────────────────────────────────────────────────────
export const DECISION_RECORD_STATUSES = ['recorded', 'superseded'] as const;
export type DecisionRecordStatus = typeof DECISION_RECORD_STATUSES[number];

export const DECISION_RECORD_ENTITY_TYPES = ['objective', 'initiative', 'work_item', 'handoff'] as const;
export type DecisionRecordEntityType = typeof DECISION_RECORD_ENTITY_TYPES[number];

// ── ResearchDoc ────────────────────────────────────────────────────────────────
export const RESEARCH_DOC_SOURCE_TYPES = ['manual', 'imported', 'veda_reference', 'external_reference'] as const;
export type ResearchDocSourceType = typeof RESEARCH_DOC_SOURCE_TYPES[number];

export const RESEARCH_DOC_STATUSES = ['active', 'archived'] as const;
export type ResearchDocStatus = typeof RESEARCH_DOC_STATUSES[number];

// ── EvidenceLink ───────────────────────────────────────────────────────────────
export const EVIDENCE_LINK_SOURCE_ENTITY_TYPES = [
  'objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc',
] as const;
export type EvidenceLinkSourceEntityType = typeof EVIDENCE_LINK_SOURCE_ENTITY_TYPES[number];

export const EVIDENCE_LINK_TYPES = ['document', 'observation', 'decision_basis', 'external_reference'] as const;
export type EvidenceLinkType = typeof EVIDENCE_LINK_TYPES[number];

// ── ReadinessEvaluation ────────────────────────────────────────────────────────
export const READINESS_ENTITY_TYPES = ['objective', 'initiative', 'work_item', 'handoff'] as const;
export type ReadinessEntityType = typeof READINESS_ENTITY_TYPES[number];

export const READINESS_EVALUATION_TYPES = [
  'research', 'planning', 'implementation_readiness', 'code_alignment', 'handoff', 'hygiene',
] as const;
export type ReadinessEvaluationType = typeof READINESS_EVALUATION_TYPES[number];

export const READINESS_EVALUATION_RESULTS = ['ready', 'not_ready', 'ready_with_warnings', 'deferred'] as const;
export type ReadinessEvaluationResult = typeof READINESS_EVALUATION_RESULTS[number];

export const READINESS_GAP_SEVERITIES = ['critical', 'major', 'minor', 'advisory'] as const;
export type ReadinessGapSeverity = typeof READINESS_GAP_SEVERITIES[number];

/** Canonical severity rank for ordering. Never use raw text sort on these. */
export const READINESS_GAP_SEVERITY_RANK: Record<ReadinessGapSeverity, number> = {
  critical: 4,
  major: 3,
  minor: 2,
  advisory: 1,
};

// ── Handoff ────────────────────────────────────────────────────────────────────
export const HANDOFF_SOURCE_ENTITY_TYPES = ['objective', 'initiative', 'work_item'] as const;
export type HandoffSourceEntityType = typeof HANDOFF_SOURCE_ENTITY_TYPES[number];

export const HANDOFF_TARGET_SYSTEMS = ['project_v', 'veda', 'v_forge'] as const;
export type HandoffTargetSystem = typeof HANDOFF_TARGET_SYSTEMS[number];

export const HANDOFF_TYPES = ['execution', 'analysis', 'governance', 'review'] as const;
export type HandoffType = typeof HANDOFF_TYPES[number];

export const HANDOFF_STATUSES = ['proposed', 'ready', 'handed_off', 'accepted', 'closed'] as const;
export type HandoffStatus = typeof HANDOFF_STATUSES[number];

// ── Audit ──────────────────────────────────────────────────────────────────────
export const AUDIT_TYPES = [
  'research', 'planning', 'implementation_readiness', 'code_alignment', 'handoff', 'hygiene',
] as const;
export type AuditType = typeof AUDIT_TYPES[number];

export const AUDIT_RESULTS = ['pass', 'fail', 'warning', 'stale'] as const;
export type AuditResult = typeof AUDIT_RESULTS[number];

export const AUDIT_GAP_SEVERITIES = ['critical', 'major', 'minor', 'advisory'] as const;
export type AuditGapSeverity = typeof AUDIT_GAP_SEVERITIES[number];

/** Canonical severity rank for ordering. Same mapping as ReadinessGapSeverity. */
export const AUDIT_GAP_SEVERITY_RANK: Record<AuditGapSeverity, number> = {
  critical: 4,
  major: 3,
  minor: 2,
  advisory: 1,
};

export const AUDIT_GAP_STATUSES = ['open', 'resolved', 'invalidated'] as const;
export type AuditGapStatus = typeof AUDIT_GAP_STATUSES[number];

// ── StatusHistory ──────────────────────────────────────────────────────────────
export const STATUS_HISTORY_ENTITY_TYPES = [
  'project', 'objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'audit_run',
] as const;
export type StatusHistoryEntityType = typeof STATUS_HISTORY_ENTITY_TYPES[number];

// ── GitHubLink ─────────────────────────────────────────────────────────────────
export const GITHUB_LINK_SOURCE_ENTITY_TYPES = [
  'objective', 'initiative', 'work_item', 'handoff', 'decision_record', 'research_doc', 'audit_run',
] as const;
export type GitHubLinkSourceEntityType = typeof GITHUB_LINK_SOURCE_ENTITY_TYPES[number];

export const GITHUB_LINK_TYPES = ['repository', 'branch', 'pull_request', 'commit', 'issue'] as const;
export type GitHubLinkType = typeof GITHUB_LINK_TYPES[number];

// ── Rule Package Defaults ──────────────────────────────────────────────────────
// Authority: controlled-vocabularies.md "Rule Package Vocabulary"
export const RULE_PACKAGE_DEFAULTS: Record<ReadinessEvaluationType, string> = {
  research: 'standard_research_v1',
  planning: 'standard_planning_v1',
  implementation_readiness: 'standard_impl_readiness_v1',
  code_alignment: 'standard_code_alignment_v1',
  handoff: 'standard_handoff_v1',
  hygiene: 'standard_hygiene_v1',
};

// ── Priority ───────────────────────────────────────────────────────────────────
export const PRIORITY_MIN = 1;
export const PRIORITY_MAX = 1000;
export const PRIORITY_DEFAULT = 100;

// ── Key format ─────────────────────────────────────────────────────────────────
// Authority: docs/architecture/data/schema-governance.md "Key Format Rule"
export const KEY_FORMAT_REGEX = /^[a-z0-9]+(-[a-z0-9]+)*$/;
export const KEY_MIN_LENGTH = 3;
export const KEY_MAX_LENGTH = 64;

// ── Generic vocabulary validation helper ──────────────────────────────────────

/**
 * Returns true if the given value is a member of the given vocabulary tuple.
 * Use this to guard controlled-vocabulary fields before writing to the database.
 */
export function isAllowed<T extends string>(
  value: unknown,
  vocab: readonly T[]
): value is T {
  return typeof value === 'string' && (vocab as readonly string[]).includes(value);
}
