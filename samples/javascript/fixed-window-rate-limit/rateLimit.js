import { createHash } from "node:crypto";

/**
 * A fixed window per client rate limit.
 *
 * @typedef {object} Store
 * @property {(key: string, ttlSeconds: number) => Promise<number>} increment
 *   Increments the key, sets the expiry on first write, returns the new count. Rejects if the store
 *   is unreachable; this module treats that as "not checked", never as "denied".
 */

/**
 * Identifiers are hashed before they reach the store, and truncated: 16 hex characters are plenty to
 * separate callers within one window, and short enough that the key is not a re-identifiable record.
 */
const HASH_LENGTH = 16;

/**
 * @param {object} options
 * @param {Store} options.store
 * @param {string} options.endpoint   Salt as well as namespace: the same IP on two routes hashes
 *                                    differently, so keys cannot be correlated across endpoints.
 * @param {string | null | undefined} options.identifier
 * @param {number} options.limit
 * @param {number} options.windowSeconds
 * @returns {Promise<{ allowed: boolean, count: number, limit: number, checked: boolean }>}
 */
export async function rateLimit({ store, endpoint, identifier, limit, windowSeconds }) {
  if (!Number.isInteger(limit) || limit <= 0) {
    // A limit of zero would deny everything and a NaN would compare false against every count,
    // quietly disabling the throttle. Both are configuration bugs, not runtime states.
    throw new TypeError(`rateLimit: limit must be a positive integer, received ${limit}`);
  }

  const window = Math.floor(Date.now() / 1000 / windowSeconds);
  const subject = createHash("sha256")
    .update(`${identifier ?? "unknown"}|${endpoint}`)
    .digest("hex")
    .slice(0, HASH_LENGTH);
  const key = `rl:${endpoint}:${subject}:${window}`;

  try {
    const count = await store.increment(key, windowSeconds);
    return { allowed: count <= limit, count, limit, checked: true };
  } catch (error) {
    // FAIL OPEN, and say so. The worst case of allowing one extra request is a cost; the worst case
    // of denying every request because a cache is down is that the feature is offline. `checked` is
    // the field that stops a broken store looking like quiet traffic on a dashboard.
    console.warn(`[rateLimit] ${endpoint}: store unavailable, allowing through`, error);
    return { allowed: true, count: 0, limit, checked: false };
  }
}
