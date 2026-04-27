const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateObjectName = (objectName) => {
  if (!objectName || typeof objectName !== 'string') {
    return false;
  }
  // Salesforce object names are alphanumeric with underscores
  return /^[a-zA-Z0-9_]+$/.test(objectName);
};

const validateRecordId = (recordId) => {
  // Salesforce IDs are 15 or 18 characters
  return /^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(recordId);
};

const validateAccessToken = (token) => {
  return token && typeof token === 'string' && token.length > 0;
};

module.exports = {
  validateEmail,
  validateObjectName,
  validateRecordId,
  validateAccessToken
};
