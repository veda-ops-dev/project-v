/**
 * db/transaction.ts
 *
 * Transaction helper.
 *
 * Authority: docs/architecture/core/system-invariants.md §6 (Transaction and State Invariants)
 *            docs/api/api-conventions.md (Transaction Boundary Rule)
 *
 * Multi-write state changes that require atomicity (status + history, readiness + gaps,
 * decision supersedence, etc.) must use this helper rather than ad hoc transaction
 * management in service or route code.
 *
 * Usage:
 *   const result = await withTransaction(async (tx) => {
 *     // tx is a postgres TransactionSql bound to the same session
 *     await tx`UPDATE ...`;
 *     await tx`INSERT ...`;
 *     return someValue;
 *   });
 */

import { db } from './client.js';
import type { TransactionSql } from 'postgres';

export type Tx = TransactionSql;

export async function withTransaction<T>(
  fn: (tx: Tx) => Promise<T>
): Promise<T> {
  return db.begin(fn);
}
