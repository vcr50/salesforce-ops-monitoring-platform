
/**
 * Idempotency Service
 * Tracks processed event IDs to prevent duplicate webhook processing.
 * Replaces the module-level Set in billingController with a
 * resettable, evictable service suitable for testing and production.
 */

const { logger } = require('../middleware/logger');

const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

class IdempotencyService {
  constructor(ttlMs = DEFAULT_TTL_MS) {
    this._events = new Map();
    this._ttlMs = ttlMs;
  }

  /**
   * Check if an event has already been processed.
   * @param {string} eventId
   * @returns {boolean}
   */
  has(eventId) {
    if (!eventId) return false;
    const entry = this._events.get(eventId);
    if (!entry) return false;

    // Evict if expired
    if (Date.now() > entry.expiry) {
      this._events.delete(eventId);
      return false;
    }
    return true;
  }

  /**
   * Mark an event as processed.
   * @param {string} eventId
   */
  mark(eventId) {
    if (!eventId) return;
    this._events.set(eventId, {
      expiry: Date.now() + this._ttlMs
    });
  }

  /**
   * Remove expired entries to prevent unbounded memory growth.
   * @returns {number} Number of evicted entries
   */
  cleanup() {
    let evicted = 0;
    const now = Date.now();
    for (const [key, entry] of this._events.entries()) {
      if (now > entry.expiry) {
        this._events.delete(key);
        evicted++;
      }
    }
    if (evicted > 0) {
      logger.debug({ evicted }, 'Idempotency cleanup completed');
    }
    return evicted;
  }

  /**
   * Reset all tracked events (primarily for testing).
   */
  clear() {
    this._events.clear();
  }

  /**
   * Current number of tracked events.
   */
  get size() {
    return this._events.size;
  }
}

// Singleton for production use
const idempotencyService = new IdempotencyService();

// Periodic cleanup every hour
const _cleanupTimer = setInterval(() => {
  idempotencyService.cleanup();
}, 60 * 60 * 1000);

// Allow tests to stop the timer
const stopCleanup = () => {
  clearInterval(_cleanupTimer);
};

module.exports = { IdempotencyService, idempotencyService, stopCleanup };
