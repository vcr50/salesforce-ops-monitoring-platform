const { logger } = require('../middleware/logger');

class CacheService {
  constructor(ttl = 60000) { // 1 minute default TTL
    this.cache = new Map();
    this.ttl = ttl;
  }

  set(key, value, customTTL = null) {
    const expiry = Date.now() + (customTTL || this.ttl);
    this.cache.set(key, {
      value,
      expiry
    });
    logger.debug(`Cache set: ${key}`);
  }

  get(key) {
    const item = this.cache.get(key);
    
    if (!item) {
      return null;
    }

    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      logger.debug(`Cache expired: ${key}`);
      return null;
    }

    logger.debug(`Cache hit: ${key}`);
    return item.value;
  }

  has(key) {
    return this.get(key) !== null;
  }

  delete(key) {
    this.cache.delete(key);
    logger.debug(`Cache deleted: ${key}`);
  }

  clear() {
    this.cache.clear();
    logger.info(`Cache cleared`);
  }

  getStats() {
    return {
      size: this.cache.size,
      ttl: this.ttl
    };
  }

  // Clean up expired items
  cleanup() {
    let deleted = 0;
    const now = Date.now();

    for (const [key, item] of this.cache.entries()) {
      if (now > item.expiry) {
        this.cache.delete(key);
        deleted++;
      }
    }

    if (deleted > 0) {
      logger.debug(`Cache cleanup: deleted ${deleted} expired items`);
    }

    return deleted;
  }
}

// Create a singleton instance
const cacheService = new CacheService();

// Run cleanup every minute without keeping test/CLI processes alive.
const cleanupTimer = setInterval(() => {
  cacheService.cleanup();
}, 60000);

if (typeof cleanupTimer.unref === 'function') {
  cleanupTimer.unref();
}

module.exports = cacheService;
