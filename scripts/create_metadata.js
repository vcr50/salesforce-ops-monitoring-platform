const fs = require('fs');
const path = require('path');

function createDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

function writeFile(filePath, content) {
    fs.writeFileSync(filePath, content.trim());
}

const baseDir = path.join(__dirname, '../force-app/main/default/objects');

// 1. System_Log__c
const sysLogDir = path.join(baseDir, 'System_Log__c');
createDir(path.join(sysLogDir, 'fields'));

writeFile(path.join(sysLogDir, 'System_Log__c.object-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>System Log</label>
    <nameField>
        <displayFormat>SL-{000000}</displayFormat>
        <label>Log Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>System Logs</pluralLabel>
    <searchLayouts/>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
`);

writeFile(path.join(sysLogDir, 'fields', 'Class_Name__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Class_Name__c</fullName>
    <externalId>false</externalId>
    <label>Class Name</label>
    <length>255</length>
    <required>false</required>
    <trackTrending>false</trackTrending>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
`);

writeFile(path.join(sysLogDir, 'fields', 'Method_Name__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Method_Name__c</fullName>
    <externalId>false</externalId>
    <label>Method Name</label>
    <length>255</length>
    <required>false</required>
    <trackTrending>false</trackTrending>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
`);

writeFile(path.join(sysLogDir, 'fields', 'Exception_Message__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Exception_Message__c</fullName>
    <externalId>false</externalId>
    <label>Exception Message</label>
    <length>131072</length>
    <trackTrending>false</trackTrending>
    <type>LongTextArea</type>
    <visibleLines>5</visibleLines>
</CustomField>
`);

writeFile(path.join(sysLogDir, 'fields', 'Stack_Trace__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Stack_Trace__c</fullName>
    <externalId>false</externalId>
    <label>Stack Trace</label>
    <length>131072</length>
    <trackTrending>false</trackTrending>
    <type>LongTextArea</type>
    <visibleLines>5</visibleLines>
</CustomField>
`);

// 2. AI_Rule__mdt
const aiRuleDir = path.join(baseDir, 'AI_Rule__mdt');
createDir(path.join(aiRuleDir, 'fields'));

writeFile(path.join(aiRuleDir, 'AI_Rule__mdt.object-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>AI Rule</label>
    <pluralLabel>AI Rules</pluralLabel>
    <visibility>Public</visibility>
</CustomObject>
`);

writeFile(path.join(aiRuleDir, 'fields', 'Keyword__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Keyword__c</fullName>
    <externalId>false</externalId>
    <fieldManageability>DeveloperControlled</fieldManageability>
    <label>Keyword</label>
    <length>255</length>
    <required>true</required>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
`);

writeFile(path.join(aiRuleDir, 'fields', 'Root_Cause__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Root_Cause__c</fullName>
    <externalId>false</externalId>
    <fieldManageability>DeveloperControlled</fieldManageability>
    <label>Root Cause</label>
    <length>131072</length>
    <type>LongTextArea</type>
    <visibleLines>3</visibleLines>
</CustomField>
`);

writeFile(path.join(aiRuleDir, 'fields', 'Recommendation__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Recommendation__c</fullName>
    <externalId>false</externalId>
    <fieldManageability>DeveloperControlled</fieldManageability>
    <label>Recommendation</label>
    <length>255</length>
    <required>true</required>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
`);

writeFile(path.join(aiRuleDir, 'fields', 'Confidence__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Confidence__c</fullName>
    <externalId>false</externalId>
    <fieldManageability>DeveloperControlled</fieldManageability>
    <label>Confidence</label>
    <precision>3</precision>
    <required>false</required>
    <scale>0</scale>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
`);

writeFile(path.join(aiRuleDir, 'fields', 'Impact_Level__c.field-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Impact_Level__c</fullName>
    <externalId>false</externalId>
    <fieldManageability>DeveloperControlled</fieldManageability>
    <label>Impact Level</label>
    <length>50</length>
    <required>false</required>
    <type>Text</type>
    <unique>false</unique>
</CustomField>
`);

// 3. Create Custom Metadata records directory
const cmdtDir = path.join(__dirname, '../force-app/main/default/customMetadata');
createDir(cmdtDir);

writeFile(path.join(cmdtDir, 'AI_Rule.Stripe_Timeout.md-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Stripe Timeout</label>
    <protected>false</protected>
    <values>
        <field>Confidence__c</field>
        <value xsi:type="xsd:double">92.0</value>
    </values>
    <values>
        <field>Impact_Level__c</field>
        <value xsi:type="xsd:string">Critical</value>
    </values>
    <values>
        <field>Keyword__c</field>
        <value xsi:type="xsd:string">stripe</value>
    </values>
    <values>
        <field>Recommendation__c</field>
        <value xsi:type="xsd:string">Switch region</value>
    </values>
    <values>
        <field>Root_Cause__c</field>
        <value xsi:type="xsd:string">API latency spike resulting in TCP timeouts</value>
    </values>
</CustomMetadata>
`);

writeFile(path.join(cmdtDir, 'AI_Rule.Auth0_Rate_Limit.md-meta.xml'), `
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Auth0 Rate Limit</label>
    <protected>false</protected>
    <values>
        <field>Confidence__c</field>
        <value xsi:type="xsd:double">95.0</value>
    </values>
    <values>
        <field>Impact_Level__c</field>
        <value xsi:type="xsd:string">High</value>
    </values>
    <values>
        <field>Keyword__c</field>
        <value xsi:type="xsd:string">auth0</value>
    </values>
    <values>
        <field>Recommendation__c</field>
        <value xsi:type="xsd:string">Enable token caching</value>
    </values>
    <values>
        <field>Root_Cause__c</field>
        <value xsi:type="xsd:string">Auth0 tenant rate limit reached</value>
    </values>
</CustomMetadata>
`);

console.log('Metadata creation complete.');
