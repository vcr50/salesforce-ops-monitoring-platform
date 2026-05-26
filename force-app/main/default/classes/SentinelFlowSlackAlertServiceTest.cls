@IsTest
private class SentinelFlowSlackAlertServiceTest {
    @IsTest
    static void formatAlert_buildsCriticalIncidentMessage() {
        Incident__c incident = createIncident('Critical', 'New', 'Queued');

        SentinelFlowSlackAlertService.AlertMessage message =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT,
                incident.Id
            );

        System.assertEquals(SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT, message.alertType);
        System.assert(message.text.contains('SentinelFlow critical incident'));
        System.assert(message.text.contains('Incident:'));
        System.assert(message.text.contains('Severity: Critical'));
        System.assert(message.text.contains('Revenue at risk: $5000'));
        System.assert(message.text.contains('Review in Salesforce:'));
        System.assertEquals('CRITICAL_INCIDENT', message.payload.get('eventType'));
        System.assertEquals('Critical', message.payload.get('severity'));
        assertNoUnsafeActionText(message.text);
        assertNoSecretText(message.text);
    }

    @IsTest
    static void formatAlert_buildsApprovalAndActionMessages() {
        Incident__c incident = createIncident('High', 'Escalated', 'Pending Review');

        SentinelFlowSlackAlertService.AlertMessage approval =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.APPROVAL_REQUIRED,
                incident.Id
            );
        System.assert(approval.text.contains('SentinelFlow clearance required'));
        System.assert(approval.text.contains('Recommended action: Restart service after operator approval'));
        System.assert(approval.text.contains('Root cause: OAuth token expired'));
        assertNoUnsafeActionText(approval.text);
        assertNoSecretText(approval.text);

        SentinelFlowSlackAlertService.AlertMessage action =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.ACTION_EXECUTED,
                incident.Id
            );
        System.assert(action.text.contains('SentinelFlow governed action updated'));
        System.assert(action.text.contains('Auto-heal status: Pending Review'));
        System.assert(action.text.contains('View execution evidence:'));
        assertNoUnsafeActionText(action.text);
        assertNoSecretText(action.text);
    }

    @IsTest
    static void formatAlert_buildsCaseOrgHealthAndDeliveryMessages() {
        Incident__c incident = createIncident('Medium', 'In Progress', 'In Progress');

        SentinelFlowSlackAlertService.AlertMessage caseMessage =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CASE_CREATED,
                incident.Id
            );
        System.assert(caseMessage.text.contains('SentinelFlow case follow-up required'));
        System.assert(caseMessage.text.contains('No case record linked'));
        assertNoUnsafeActionText(caseMessage.text);
        assertNoSecretText(caseMessage.text);

        SentinelFlowSlackAlertService.AlertMessage orgHealth =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.ORG_HEALTH_WATCH,
                incident.Id
            );
        System.assert(orgHealth.text.contains('SentinelFlow org health watch'));
        System.assert(orgHealth.text.contains('Status: In Progress'));
        System.assert(orgHealth.text.contains('Open Command Center:'));
        System.assertEquals('ORG_HEALTH_WATCH', orgHealth.payload.get('eventType'));
        assertNoUnsafeActionText(orgHealth.text);
        assertNoSecretText(orgHealth.text);

        SentinelFlowSlackAlertService.AlertMessage deliveryIssue =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.DELIVERY_ISSUE,
                incident.Id
            );
        System.assert(deliveryIssue.text.contains('SentinelFlow alert delivery issue'));
        System.assert(deliveryIssue.text.contains('Safe failure context only'));
        System.assertEquals('DELIVERY_ISSUE', deliveryIssue.payload.get('eventType'));
        assertNoUnsafeActionText(deliveryIssue.text);
        assertNoSecretText(deliveryIssue.text);
    }

    @IsTest
    static void formatAlert_payloadContainsExpectedFields() {
        Incident__c incident = createIncident('Critical', 'New', 'Queued');

        SentinelFlowSlackAlertService.AlertMessage message =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT,
                incident.Id
            );

        System.assertEquals(message.text, message.payload.get('text'));
        System.assertEquals('Critical', message.payload.get('severity'));
        System.assertEquals('New', message.payload.get('status'));
        System.assertEquals('OAuth token expired', message.payload.get('rootCause'));
        System.assertEquals('Restart service after operator approval', message.payload.get('recommendedAction'));
        System.assertEquals(Decimal.valueOf(5000), message.payload.get('revenueAtRisk'));
        System.assertEquals(Decimal.valueOf(50), message.payload.get('usersAffected'));
        System.assertEquals('Queued', message.payload.get('autoHealStatus'));
        System.assert(String.valueOf(message.payload.get('salesforceRecordUrl')).contains('/lightning/r/'));
        System.assert(String.valueOf(message.payload.get('salesforceRecordUrl')).endsWith('/view'));
        assertNoSecretText(String.valueOf(message.payload));
    }

    @IsTest
    static void formatAlert_usesFallbacksForSparseIncidentData() {
        Incident__c sparseIncident = new Incident__c(
            Severity__c = 'Low',
            Status__c = 'New',
            Description__c = 'Sparse formatter fixture'
        );
        insert sparseIncident;

        SentinelFlowSlackAlertService.AlertMessage message =
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT,
                sparseIncident.Id
            );

        System.assert(message.text.contains('Users affected: 0'));
        System.assert(message.text.contains('Revenue at risk: $0'));
        System.assert(message.text.contains('Recommended action: Not reported'));
        assertNoUnsafeActionText(message.text);
        assertNoSecretText(message.text);
    }

    @IsTest
    static void formatAlert_handlesNullInputs() {
        Boolean missingTypeThrown = false;
        try {
            SentinelFlowSlackAlertService.formatAlert(null, createIncident('Critical', 'New', 'Queued').Id);
        } catch (SentinelFlowSlackAlertService.SentinelFlowSlackAlertException e) {
            missingTypeThrown = true;
        }
        System.assert(missingTypeThrown, 'Missing alert type should throw a controlled exception.');

        Boolean missingIdThrown = false;
        try {
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT,
                (Id) null
            );
        } catch (SentinelFlowSlackAlertService.SentinelFlowSlackAlertException e) {
            missingIdThrown = true;
        }
        System.assert(missingIdThrown, 'Missing incident id should throw a controlled exception.');

        Boolean missingIncidentThrown = false;
        try {
            SentinelFlowSlackAlertService.formatAlert(
                SentinelFlowSlackAlertService.AlertType.CRITICAL_INCIDENT,
                new Incident__c()
            );
        } catch (SentinelFlowSlackAlertService.SentinelFlowSlackAlertException e) {
            missingIncidentThrown = true;
        }
        System.assert(missingIncidentThrown, 'Missing incident record id should throw a controlled exception.');
    }

    private static Incident__c createIncident(String severity, String status, String autoHealStatus) {
        Incident__c incident = new Incident__c(
            Severity__c = severity,
            Status__c = status,
            Description__c = 'Slack formatter test incident',
            Root_Cause__c = 'OAuth token expired',
            Recommended_Action__c = 'Restart service after operator approval',
            Revenue_at_Risk__c = 5000,
            Users_Affected__c = 50,
            Auto_Heal_Status__c = autoHealStatus
        );
        insert incident;
        return incident;
    }

    private static void assertNoUnsafeActionText(String value) {
        String lowerValue = value.toLowerCase();
        System.assert(!lowerValue.contains('approve in slack'), 'Slack message must not approve in Slack.');
        System.assert(!lowerValue.contains('reject in slack'), 'Slack message must not reject in Slack.');
        System.assert(!lowerValue.contains('execute in slack'), 'Slack message must not execute in Slack.');
        System.assert(!lowerValue.contains('remediate in slack'), 'Slack message must not remediate in Slack.');
    }

    private static void assertNoSecretText(String value) {
        System.assert(!value.contains('xoxb-'), 'Slack bot token pattern must not appear.');
        System.assert(!value.contains('hooks.slack.com/services'), 'Slack webhook URL must not appear.');
        System.assert(!value.contains('sid='), 'Salesforce session id pattern must not appear.');
        System.assert(!value.contains('SLACK_WEBHOOK_URL'), 'Secret environment variable name must not appear in message.');
    }
}
