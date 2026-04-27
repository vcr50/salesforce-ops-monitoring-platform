const axios = require('axios');
const { logger } = require('../middleware/logger');
const { SalesforceError } = require('../utils/errors');
const { API_TIMEOUT, RETRY_ATTEMPTS, RETRY_DELAY } = require('../utils/constants');

class SalesforceSoapAPI {
  constructor(accessToken, instanceUrl) {
    this.accessToken = accessToken;
    this.instanceUrl = instanceUrl;
    this.baseURL = `${instanceUrl}/services/Soap/c/58.0`;
  }

  // Build SOAP envelope
  buildSoapEnvelope(body) {
    return `<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:enterprise.soap.sforce.com">
  <soapenv:Header>
    <urn:SessionHeader>
      <urn:sessionId>${this.accessToken}</urn:sessionId>
    </urn:SessionHeader>
  </soapenv:Header>
  <soapenv:Body>
    ${body}
  </soapenv:Body>
</soapenv:Envelope>`;
  }

  async request(soapBody, retries = RETRY_ATTEMPTS) {
    try {
      const response = await axios.post(this.baseURL, this.buildSoapEnvelope(soapBody), {
        headers: {
          'Content-Type': 'text/xml; charset=UTF-8',
          'SOAPAction': '""'
        },
        timeout: API_TIMEOUT
      });

      // Parse and return response
      return response.data;
    } catch (error) {
      if (retries > 0 && this.isRetryableError(error)) {
        logger.warn(`SOAP request failed, retrying... (${RETRY_ATTEMPTS - retries + 1}/${RETRY_ATTEMPTS})`);
        await this.sleep(RETRY_DELAY);
        return this.request(soapBody, retries - 1);
      }

      logger.error(`SOAP API Error: ${error.message}`);
      throw new SalesforceError(error.message, error.response?.status);
    }
  }

  isRetryableError(error) {
    const retryableStatuses = [408, 429, 500, 502, 503, 504];
    return retryableStatuses.includes(error.response?.status);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async login(username, password, securityToken) {
    const body = `
      <urn:login>
        <urn:username>${username}</urn:username>
        <urn:password>${password}${securityToken}</urn:password>
      </urn:login>
    `;
    return this.request(body);
  }

  async retrieve(objectType, ids, fields) {
    const fieldList = fields.map(f => `<urn:fieldList>${f}</urn:fieldList>`).join('');
    const idList = ids.map(id => `<urn:ids>${id}</urn:ids>`).join('');

    const body = `
      <urn:retrieve>
        ${fieldList}
        ${idList}
        <urn:sObjectType>${objectType}</urn:sObjectType>
      </urn:retrieve>
    `;
    return this.request(body);
  }

  async query(soqlQuery) {
    const body = `
      <urn:query>
        <urn:queryString>${soqlQuery.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</urn:queryString>
      </urn:query>
    `;
    return this.request(body);
  }
}

module.exports = SalesforceSoapAPI;
