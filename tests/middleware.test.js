const authMiddleware = require('../src/middleware/auth');
const errorHandler = require('../src/middleware/errorHandler');

const createResponse = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

describe('auth middleware', () => {
  test('rejects unauthenticated requests', () => {
    const req = { path: '/private', isAuthenticated: jest.fn().mockReturnValue(false) };
    const res = createResponse();
    const next = jest.fn();

    authMiddleware(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      error: 'Unauthorized',
      message: 'Please authenticate first'
    });
    expect(next).not.toHaveBeenCalled();
  });

  test('allows authenticated requests', () => {
    const req = { path: '/private', isAuthenticated: jest.fn().mockReturnValue(true) };
    const res = createResponse();
    const next = jest.fn();

    authMiddleware(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(res.status).not.toHaveBeenCalled();
  });
});

describe('error handler middleware', () => {
  test('uses explicit error status', () => {
    const req = { path: '/bad', method: 'POST', query: {}, body: { bad: true } };
    const res = createResponse();
    const err = Object.assign(new Error('Invalid input'), { status: 422 });

    errorHandler(err, req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({
      error: expect.objectContaining({
        message: 'Invalid input',
        status: 422,
        path: '/bad',
        timestamp: expect.any(String)
      })
    });
  });

  test('defaults to 500 when no status is present', () => {
    const req = { path: '/boom', method: 'GET', query: {}, body: {} };
    const res = createResponse();

    errorHandler(new Error('Boom'), req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      error: expect.objectContaining({
        message: 'Boom',
        status: 500,
        path: '/boom'
      })
    });
  });
});
