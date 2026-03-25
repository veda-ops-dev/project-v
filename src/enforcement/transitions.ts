/**
 * enforcement/transitions.ts
 *
 * Central status transition validator.
 *
 * Authority: docs/architecture/data/status-transitions.md
 *            docs/api/api-conventions.md (Error Code Rule)
 *
 * All governed status transitions must pass through this module before any
 * state is written to the database. Route handlers must not implement their
 * own ad hoc transition tables.
 *
 * Transition rules:
 *   - "allowed"              → permitted without reason
 *   - "allowed_with_reason"  → permitted; non-empty reason is required (400 on missing)
 *   - "forbidden"            → must fail with 422 Unprocessable Entity
 *
 * Side-effect signals:
 *   - requiresStatusHistory  → calling code must write a StatusHistory row atomically
 *   - setCompletedAt         → calling code must set completedAt = now() (Handoff only)
 */

export type TransitionVerdict = 'allowed' | 'allowed_with_reason' | 'forbidden';

export interface TransitionRule {
  verdict: TransitionVerdict;
  requiresStatusHistory: boolean;
  setCompletedAt?: boolean;
}

// ---------------------------------------------------------------------------
// Transition tables
// Source: docs/architecture/data/status-transitions.md
// ---------------------------------------------------------------------------

type TransitionMap = Record<string, Record<string, TransitionRule>>;

const A: TransitionRule = { verdict: 'allowed', requiresStatusHistory: true };
const AR: TransitionRule = { verdict: 'allowed_with_reason', requiresStatusHistory: true };
const F: TransitionRule = { verdict: 'forbidden', requiresStatusHistory: false };

const PROJECT_TRANSITIONS: TransitionMap = {
  active:   { deferred: A, archived: AR },
  deferred: { active: A,   archived: AR },
  archived: { active: F,   deferred: F },
};

const OBJECTIVE_TRANSITIONS: TransitionMap = {
  proposed:  { active: A, blocked: A, archived: AR },
  active:    { blocked: A, completed: A },
  blocked:   { active: A, archived: AR },
  completed: { archived: A, active: F, blocked: F },
  archived:  { proposed: F, active: F, blocked: F, completed: F },
};

const INITIATIVE_TRANSITIONS: TransitionMap = OBJECTIVE_TRANSITIONS;

const WORK_ITEM_TRANSITIONS: TransitionMap = {
  proposed:  { active: A, blocked: A, archived: AR, completed: F },
  active:    { blocked: A, completed: A },
  blocked:   { active: A, archived: AR },
  completed: { archived: A, active: F, blocked: F },
  archived:  { proposed: F, active: F, blocked: F, completed: F },
};

const HANDOFF_TRANSITIONS: TransitionMap = {
  proposed:    { ready: A, closed: AR, handed_off: F, accepted: F },
  ready:       { handed_off: A, closed: AR, proposed: F, accepted: F },
  handed_off:  {
    accepted: A,
    closed:   AR,
    ready:    AR,
    proposed: AR,
  },
  accepted: {
    closed: A,
    handed_off: F, ready: F, proposed: F,
  },
  closed: { proposed: F, ready: F, handed_off: F, accepted: F },
};

// completedAt must be set when transitioning to 'closed'
for (const fromStatus of Object.keys(HANDOFF_TRANSITIONS)) {
  const toMap = HANDOFF_TRANSITIONS[fromStatus];
  if (toMap && toMap['closed'] && toMap['closed'].verdict !== 'forbidden') {
    toMap['closed'] = { ...toMap['closed'], setCompletedAt: true };
  }
}

const DECISION_RECORD_TRANSITIONS: TransitionMap = {
  recorded:  { superseded: AR },
  superseded: { recorded: F },
};

const AUDIT_RUN_TRANSITIONS: TransitionMap = {
  pass:    { stale: AR },
  fail:    { stale: AR },
  warning: { stale: AR },
  stale:   { pass: F, fail: F, warning: F },
};

// ---------------------------------------------------------------------------
// Entity-type-to-transition-table mapping
// ---------------------------------------------------------------------------

const ENTITY_TRANSITION_MAPS: Record<string, TransitionMap> = {
  project:          PROJECT_TRANSITIONS,
  objective:        OBJECTIVE_TRANSITIONS,
  initiative:       INITIATIVE_TRANSITIONS,
  work_item:        WORK_ITEM_TRANSITIONS,
  handoff:          HANDOFF_TRANSITIONS,
  decision_record:  DECISION_RECORD_TRANSITIONS,
  audit_run:        AUDIT_RUN_TRANSITIONS,
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export interface TransitionCheckResult {
  verdict: TransitionVerdict;
  requiresStatusHistory: boolean;
  requiresReason: boolean;
  setCompletedAt: boolean;
}

/**
 * Validate whether a status transition is legal for the given entity type.
 *
 * Returns a TransitionCheckResult describing the outcome and required side effects.
 * Returns null if the entity type is not governed by this module.
 *
 * The calling code must:
 *   - reject 'forbidden' verdicts with 422 Unprocessable Entity
 *   - reject 'allowed_with_reason' verdicts with missing reason with 400 Bad Request
 *   - write StatusHistory atomically when requiresStatusHistory is true
 *   - set completedAt = now() atomically when setCompletedAt is true
 */
export function checkTransition(
  entityType: string,
  fromStatus: string,
  toStatus: string
): TransitionCheckResult | null {
  const map = ENTITY_TRANSITION_MAPS[entityType];
  if (!map) return null;

  const fromMap = map[fromStatus];
  const rule = fromMap?.[toStatus];

  if (!rule) {
    // No rule found — treat as forbidden
    return {
      verdict: 'forbidden',
      requiresStatusHistory: false,
      requiresReason: false,
      setCompletedAt: false,
    };
  }

  return {
    verdict: rule.verdict,
    requiresStatusHistory: rule.requiresStatusHistory,
    requiresReason: rule.verdict === 'allowed_with_reason',
    setCompletedAt: rule.setCompletedAt ?? false,
  };
}
