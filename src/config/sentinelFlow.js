const customObjects = {
  Incident__c: {
    description: 'Stores operational incidents raised from monitoring events.',
    keyFields: [
      'Severity__c',
      'Status__c',
      'Description__c',
      'SLA_Policy__c',
      'Integration_Log__c',
      'Environment__c',
      'Resolved_Time__c'
    ]
  },
  Integration_Log__c: {
    description: 'Captures API and integration execution details.',
    keyFields: [
      'API_Name__c',
      'Status__c',
      'Response_Time__c',
      'Error_Message__c'
    ]
  },
  SLA_Policy__c: {
    description: 'Defines operational response and resolution targets.',
    keyFields: [
      'Severity__c',
      'Response_Time_Min__c',
      'Resolution_Time_Min__c'
    ]
  },
  Environment__c: {
    description: 'Represents the Salesforce org or operational environment.',
    keyFields: [
      'Name',
      'Org_Id__c'
    ]
  },
  Deployment_Record__c: {
    description: 'Tracks deployment execution history.',
    keyFields: [
      'Version__c',
      'Status__c',
      'Start_Time__c',
      'End_Time__c'
    ]
  },
  Audit_Trail__c: {
    description: 'Stores auditable administrator and automation actions.',
    keyFields: [
      'User__c',
      'Action__c',
      'Object_Name__c',
      'Old_Value__c',
      'New_Value__c',
      'Timestamp__c'
    ]
  }
};

const sentinelFlowConfig = {
  platform: {
    name: 'Salesforce Enterprise Operations Monitoring Platform',
    shortName: 'SentinelFlow',
    version: process.env.SentinelFlow_VERSION || '1.0.0',
    phase: process.env.SentinelFlow_PHASE || 'phase-1-foundation'
  },
  environment: {
    nodeEnv: process.env.NODE_ENV || 'development',
    appEnv: process.env.APP_ENV || 'local',
    salesforceOrg: process.env.SALESFORCE_ORG_ALIAS || 'unconfigured',
    timezone: process.env.APP_TIMEZONE || 'UTC'
  },
  services: {
    salesforce: {
      instanceUrl: process.env.SALESFORCE_INSTANCE_URL || null,
      streamingMode: process.env.SALESFORCE_STREAMING_MODE || 'platform-events'
    },
    middleware: {
      port: Number.parseInt(process.env.PORT, 10) || 3000
    },
    queue: {
      provider: process.env.QUEUE_PROVIDER || 'redis',
      topic: process.env.EVENT_TOPIC || 'sentinelFlow.platform-events'
    },
    database: {
      provider: process.env.DB_PROVIDER || 'postgresql',
      urlConfigured: Boolean(process.env.DATABASE_URL)
    },
    notifications: {
      slackWebhookConfigured: Boolean(process.env.SLACK_WEBHOOK_URL),
      emailAlertsEnabled: process.env.EMAIL_ALERTS_ENABLED === 'true'
    }
  },
  salesforce: {
    customObjects
  }
};

const requiredFoundationEnv = [
  'APP_ENV',
  'SALESFORCE_INSTANCE_URL',
  'SALESFORCE_CLIENT_ID',
  'SALESFORCE_CLIENT_SECRET',
  'DATABASE_URL',
  'SESSION_SECRET'
];

const getMissingFoundationEnv = () =>
  requiredFoundationEnv.filter((key) => !process.env[key]);

const getFoundationStatus = () => ({
  phase: sentinelFlowConfig.platform.phase,
  ready: getMissingFoundationEnv().length === 0,
  missingEnv: getMissingFoundationEnv(),
  workstreams: {
    appConfig: true,
    infrastructureScaffold: true,
    dataModelBaseline: true,
    operationalEndpoints: true
  }
});

module.exports = {
  sentinelFlowConfig,
  requiredFoundationEnv,
  getMissingFoundationEnv,
  getFoundationStatus
};
