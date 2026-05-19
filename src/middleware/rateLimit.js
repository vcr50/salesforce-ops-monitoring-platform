const DEFAULT_LIMITS = {
  classification: Number(process.env.RATE_LIMIT_CLASSIFICATION || 60),
  prediction: Number(process.env.RATE_LIMIT_PREDICTION || 60),
  memory: Number(process.env.RATE_LIMIT_MEMORY || 120),
  healing: Number(process.env.RATE_LIMIT_HEALING || 20),
  default: Number(process.env.RATE_LIMIT_DEFAULT || 300)
};

const DEFAULT_WINDOW_MS = Number(process.env.RATE_LIMIT_WINDOW_MS || 60 * 1000);
const buckets = new Map();

const getCategory = (path) => {
  if (/classify|analysis/i.test(path)) return 'classification';
  if (/predict|analytics/i.test(path)) return 'prediction';
  if (/memory/i.test(path)) return 'memory';
  if (/heal|retry|sync/i.test(path)) return 'healing';
  return 'default';
};

const pruneExpiredBuckets = (now) => {
  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) {
      buckets.delete(key);
    }
  }
};

const tenantRateLimit = (options = {}) => {
  const limits = { ...DEFAULT_LIMITS, ...(options.limits || {}) };
  const windowMs = options.windowMs || DEFAULT_WINDOW_MS;

  return (req, res, next) => {
    if (!req.path.startsWith('/api') || !req.context) {
      return next();
    }

    const now = Date.now();
    const category = getCategory(req.path);
    const limit = limits[category] || limits.default;
    const key = `${req.context.tenantId}:${category}`;

    pruneExpiredBuckets(now);

    const bucket = buckets.get(key) || {
      count: 0,
      resetAt: now + windowMs
    };

    bucket.count += 1;
    buckets.set(key, bucket);

    const remaining = Math.max(limit - bucket.count, 0);
    res.setHeader('x-ratelimit-limit', String(limit));
    res.setHeader('x-ratelimit-remaining', String(remaining));
    res.setHeader('x-ratelimit-reset', new Date(bucket.resetAt).toISOString());

    if (bucket.count > limit) {
      return res.status(429).json({
        error: {
          code: 'TENANT_RATE_LIMIT_EXCEEDED',
          message: `Rate limit exceeded for ${category} requests.`,
          status: 429,
          requestId: req.context.requestId
        }
      });
    }

    return next();
  };
};

tenantRateLimit._reset = () => buckets.clear();

module.exports = {
  tenantRateLimit,
  getCategory
};
