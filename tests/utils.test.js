const {
  validateEmail,
  validateObjectName,
  validateRecordId,
  validateAccessToken
} = require('../src/utils/validators');
const {
  formatSalesforceRecord,
  formatSalesforceError,
  formatBulkJobResult
} = require('../src/utils/formatters');
const {
  ValidationError,
  AuthenticationError,
  SalesforceError
} = require('../src/utils/errors');

describe('validators', () => {
  test('validates email shape', () => {
    expect(validateEmail('buyer@example.com')).toBe(true);
    expect(validateEmail('buyer+tag@example.co.in')).toBe(true);
    expect(validateEmail('buyer')).toBe(false);
    expect(validateEmail('buyer@example')).toBe(false);
  });

  test('validates Salesforce object names', () => {
    expect(validateObjectName('Account')).toBe(true);
    expect(validateObjectName('Custom_Object__c')).toBe(true);
    expect(validateObjectName('Bad Object')).toBe(false);
    expect(validateObjectName(null)).toBe(false);
  });

  test('validates Salesforce record ids', () => {
    expect(validateRecordId('001ABCdef123456')).toBe(true);
    expect(validateRecordId('001ABCdef123456XYZ')).toBe(true);
    expect(validateRecordId('001ABCdef12345')).toBe(false);
    expect(validateRecordId('001ABCdef12345!')).toBe(false);
  });

  test('validates access tokens', () => {
    expect(validateAccessToken('token')).toBe(true);
    expect(validateAccessToken('')).toBe(false);
    expect(validateAccessToken(null)).toBe(false);
    expect(validateAccessToken(123)).toBe(false);
  });
});

describe('formatters', () => {
  test('formats Salesforce records without mutating data fields', () => {
    expect(formatSalesforceRecord(null)).toBeNull();
    expect(formatSalesforceRecord({
      Id: '001ABCdef123456',
      attributes: { type: 'Account' },
      Name: 'Acme',
      CreatedDate: '2026-01-01T00:00:00.000Z',
      LastModifiedDate: '2026-01-02T00:00:00.000Z'
    })).toEqual({
      id: '001ABCdef123456',
      attributes: { type: 'Account' },
      data: {
        Name: 'Acme',
        CreatedDate: '2026-01-01T00:00:00.000Z',
        LastModifiedDate: '2026-01-02T00:00:00.000Z'
      },
      createdDate: '2026-01-01T00:00:00.000Z',
      lastModifiedDate: '2026-01-02T00:00:00.000Z'
    });
  });

  test('formats Salesforce errors from arrays and single errors', () => {
    expect(formatSalesforceError([
      { message: 'Required field missing', errorCode: 'REQUIRED_FIELD_MISSING', fields: ['Name'] }
    ])).toEqual([
      { message: 'Required field missing', errorCode: 'REQUIRED_FIELD_MISSING', fields: ['Name'] }
    ]);

    expect(formatSalesforceError({ message: 'Nope', errorCode: 'INVALID_FIELD' })).toEqual({
      message: 'Nope',
      errorCode: 'INVALID_FIELD'
    });

    expect(formatSalesforceError({})).toEqual({
      message: 'Unknown error',
      errorCode: 'UNKNOWN'
    });
  });

  test('formats bulk job results', () => {
    expect(formatBulkJobResult({
      id: 'job_1',
      state: 'JobComplete',
      numberBatchesQueued: 1,
      numberBatchesInProgress: 0,
      numberBatchesCompleted: 1,
      numberBatchesFailed: 0,
      totalProcessingTime: 42
    })).toEqual({
      jobId: 'job_1',
      state: 'JobComplete',
      numberBatchesQueued: 1,
      numberBatchesInProgress: 0,
      numberBatchesCompleted: 1,
      numberBatchesFailed: 0,
      totalProcessingTime: 42
    });
  });
});

describe('custom errors', () => {
  test('expose names and HTTP statuses', () => {
    const validation = new ValidationError('Bad input');
    const auth = new AuthenticationError('Login required');
    const salesforce = new SalesforceError('Salesforce failed', 503);

    expect(validation).toBeInstanceOf(Error);
    expect(validation).toMatchObject({ name: 'ValidationError', status: 400, message: 'Bad input' });
    expect(auth).toMatchObject({ name: 'AuthenticationError', status: 401, message: 'Login required' });
    expect(salesforce).toMatchObject({ name: 'SalesforceError', status: 503, message: 'Salesforce failed' });
    expect(new SalesforceError('Default')).toMatchObject({ status: 500 });
  });
});
