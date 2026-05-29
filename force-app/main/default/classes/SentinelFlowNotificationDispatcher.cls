@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class SentinelFlowNotificationDispatcher {
    private static final String PENDING_APPROVAL = 'Pending Approval';
    private static final String SLACK_NAMED_CREDENTIAL = 'callout:Slack_Webhook';
    private static final String TEAMS_NAMED_CREDENTIAL = 'callout:Teams_Webhook';
    @TestVisible public static Boolean enableTriggerDispatchForTests = false;

    @future(callout=true)
    public static void dispatchPendingApprovalAlerts(List<Id> incidentIds) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        SecurityGate.requireReadAccess('Sentinel_Incident__c', new Set<String>{
            'Id', 'Name', 'Approval_Status__c', 'Risk_Score__c', 'Risk_Level__c',
            'Root_Cause__c', 'Recommended_Action__c', 'Execution_Action__c',
            'Next_Action__c', 'Policy_Decision__c', 'Runbook_Title__c',
            'Runbook_Description__c', 'CreatedDate'
        });

        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Approval_Status__c, Risk_Score__c, Risk_Level__c,
                Root_Cause__c, Recommended_Action__c, Execution_Action__c,
                Next_Action__c, Policy_Decision__c, Runbook_Title__c,
                Runbook_Description__c, CreatedDate
            FROM Sentinel_Incident__c
            WHERE Id IN :incidentIds
            AND Approval_Status__c = :PENDING_APPROVAL
            ORDER BY CreatedDate ASC
        ];

        WebhookConfig config = loadWebhookConfig();
        List<Sentinel_Audit_Log__c> logs = new List<Sentinel_Audit_Log__c>();

        for (Sentinel_Incident__c incident : incidents) {
            Boolean needsEmailFallback = false;
            Boolean hasWebhookFailure = false;
            String recordUrl = buildRecordUrl(incident.Id);

            if (String.isBlank(config.slackPath)) {
                needsEmailFallback = true;
                logs.add(buildAuditLog(
                    incident.Id,
                    'SLACK_ALERT_NOT_CONFIGURED',
                    'FALLBACK_EMAIL',
                    'No Slack webhook path is configured.',
                    null
                ));
            } else {
                DeliveryResult slackResult = postJson(
                    SLACK_NAMED_CREDENTIAL + normalizePath(config.slackPath),
                    buildSlackPayload(incident, recordUrl)
                );
                logs.add(buildAuditLog(
                    incident.Id,
                    slackResult.success ? 'SLACK_ALERT_SENT' : 'SLACK_ALERT_FAILED',
                    slackResult.success ? 'DELIVERED' : 'FALLBACK_EMAIL',
                    'Slack pending approval alert',
                    slackResult.message
                ));
                needsEmailFallback = needsEmailFallback || !slackResult.success;
                if (!slackResult.success) {
                    hasWebhookFailure = true;
                }
            }

            if (String.isBlank(config.teamsPath)) {
                needsEmailFallback = true;
                logs.add(buildAuditLog(
                    incident.Id,
                    'TEAMS_ALERT_NOT_CONFIGURED',
                    'FALLBACK_EMAIL',
                    'No Teams webhook path is configured.',
                    null
                ));
            } else {
                DeliveryResult teamsResult = postJson(
                    TEAMS_NAMED_CREDENTIAL + normalizePath(config.teamsPath),
                    buildTeamsPayload(incident, recordUrl)
                );
                logs.add(buildAuditLog(
                    incident.Id,
                    teamsResult.success ? 'TEAMS_ALERT_SENT' : 'TEAMS_ALERT_FAILED',
                    teamsResult.success ? 'DELIVERED' : 'FALLBACK_EMAIL',
                    'Teams pending approval alert',
                    teamsResult.message
                ));
                needsEmailFallback = needsEmailFallback || !teamsResult.success;
                if (!teamsResult.success) {
                    hasWebhookFailure = true;
                }
            }

            if (needsEmailFallback) {
                sendFallbackEmail(incident, recordUrl);
                logs.add(buildAuditLog(
                    incident.Id,
                    'APPROVAL_ALERT_EMAIL_FALLBACK_SENT',
                    'DELIVERED',
                    'Email fallback sent to ' + UserInfo.getUserEmail(),
                    null
                ));
            }
            // Streaming telemetry — emit ERROR_LOGGED when a configured webhook actually failed delivery
            if (hasWebhookFailure) {
                SentinelFlowEventPublisher.publishSystemEvent(
                    'ERROR_LOGGED',
                    'SentinelFlowNotificationDispatcher',
                    'Webhook delivery failed for incident ' + incident.Name + '. Email fallback triggered.'
                );
            }
        }

        if (!logs.isEmpty() && SecurityGate.isCreateable('Sentinel_Audit_Log__c')) {
            insert logs;
        }
    }

    @TestVisible
    private static Map<String, Object> buildSlackPayload(Sentinel_Incident__c incident, String recordUrl) {
        String riskLevel = safe(incident.Risk_Level__c);
        Map<String, Object> header = new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => riskSignal(riskLevel) + ' Guardian Gate approval required',
                'emoji' => true
            }
        };

        List<Object> fields = new List<Object>{
            slackField('Incident', incident.Name),
            slackField('Risk score', incident.Risk_Score__c == null ? 'Not reported' : String.valueOf(incident.Risk_Score__c.setScale(0))),
            slackField('Risk level', riskLevel),
            slackField('Policy decision', incident.Policy_Decision__c),
            slackField('Root cause', incident.Root_Cause__c),
            slackField('Recommendation', incident.Recommended_Action__c),
            slackField('Proposed action', firstNonBlank(incident.Execution_Action__c, incident.Next_Action__c)),
            slackField('ARR impact', 'Not reported')
        };

        Map<String, Object> details = new Map<String, Object>{
            'type' => 'section',
            'fields' => fields
        };

        Map<String, Object> action = new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => 'Review in Salesforce'
                    },
                    'url' => recordUrl
                }
            }
        };

        return new Map<String, Object>{
            'text' => 'Guardian Gate approval required for ' + safe(incident.Name),
            'blocks' => new List<Object>{ header, details, action }
        };
    }

    @TestVisible
    private static Map<String, Object> buildTeamsPayload(Sentinel_Incident__c incident, String recordUrl) {
        String riskLevel = safe(incident.Risk_Level__c);
        String facts = '**Incident:** ' + safe(incident.Name) + '\n\n' +
            '**Risk score:** ' + (incident.Risk_Score__c == null ? 'Not reported' : String.valueOf(incident.Risk_Score__c.setScale(0))) + '\n\n' +
            '**Risk level:** ' + riskLevel + '\n\n' +
            '**Root cause:** ' + safe(incident.Root_Cause__c) + '\n\n' +
            '**Recommendation:** ' + safe(incident.Recommended_Action__c) + '\n\n' +
            '**Proposed action:** ' + safe(firstNonBlank(incident.Execution_Action__c, incident.Next_Action__c)) + '\n\n' +
            '**ARR impact:** Not reported';

        return new Map<String, Object>{
            '@type' => 'MessageCard',
            '@context' => 'https://schema.org/extensions',
            'themeColor' => teamsColor(riskLevel),
            'summary' => 'Guardian Gate approval required for ' + safe(incident.Name),
            'title' => 'Guardian Gate approval required',
            'sections' => new List<Object>{
                new Map<String, Object>{
                    'activityTitle' => safe(incident.Runbook_Title__c),
                    'activitySubtitle' => safe(incident.Runbook_Description__c),
                    'markdown' => true,
                    'text' => facts
                }
            },
            'potentialAction' => new List<Object>{
                new Map<String, Object>{
                    '@type' => 'OpenUri',
                    'name' => 'Review in Salesforce',
                    'targets' => new List<Object>{
                        new Map<String, Object>{
                            'os' => 'default',
                            'uri' => recordUrl
                        }
                    }
                }
            }
        };
    }

    private static DeliveryResult postJson(String endpoint, Map<String, Object> payload) {
        DeliveryResult result = new DeliveryResult();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(10000);
        request.setBody(JSON.serialize(payload));

        try {
            HttpResponse response = new Http().send(request);
            Integer statusCode = response.getStatusCode();
            result.success = statusCode >= 200 && statusCode < 300;
            result.message = 'HTTP ' + statusCode + ': ' + abbreviate(response.getBody(), 1000);
        } catch (Exception ex) {
            result.success = false;
            result.message = ex.getMessage();
        }
        return result;
    }

    private static WebhookConfig loadWebhookConfig() {
        WebhookConfig config = new WebhookConfig();
        SentinelFlow_Settings__c settings = SentinelFlow_Settings__c.getOrgDefaults();
        if (settings != null) {
            config.slackPath = settings.Slack_Webhook_Path__c;
            config.teamsPath = settings.Teams_Webhook_Path__c;
        }

        Id tenantId = TenantContext.getCurrentTenantId();
        if (tenantId != null) {
            SecurityGate.requireReadAccess('Tenant__c', new Set<String>{
                'Id', 'Slack_Webhook_Path__c', 'Teams_Webhook_Path__c'
            });
            List<Tenant__c> tenants = [
                SELECT Slack_Webhook_Path__c, Teams_Webhook_Path__c
                FROM Tenant__c
                WHERE Id = :tenantId
                LIMIT 1
            ];
            if (!tenants.isEmpty()) {
                if (String.isBlank(config.slackPath)) {
                    config.slackPath = tenants[0].Slack_Webhook_Path__c;
                }
                if (String.isBlank(config.teamsPath)) {
                    config.teamsPath = tenants[0].Teams_Webhook_Path__c;
                }
            }
        }

        return config;
    }

    private static void sendFallbackEmail(Sentinel_Incident__c incident, String recordUrl) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        mail.setSubject('SentinelFlow Guardian Gate approval required: ' + safe(incident.Name));
        mail.setPlainTextBody(
            'A SentinelFlow incident is waiting for Guardian Gate approval.' + '\n\n' +
            'Incident: ' + safe(incident.Name) + '\n' +
            'Risk level: ' + safe(incident.Risk_Level__c) + '\n' +
            'Risk score: ' + (incident.Risk_Score__c == null ? 'Not reported' : String.valueOf(incident.Risk_Score__c.setScale(0))) + '\n' +
            'Recommendation: ' + safe(incident.Recommended_Action__c) + '\n' +
            'Proposed action: ' + safe(firstNonBlank(incident.Execution_Action__c, incident.Next_Action__c)) + '\n\n' +
            'Review in Salesforce: ' + recordUrl
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    private static Sentinel_Audit_Log__c buildAuditLog(
        Id incidentId,
        String eventType,
        String decision,
        String requestPayload,
        String responsePayload
    ) {
        return new Sentinel_Audit_Log__c(
            Incident__c = incidentId,
            Event_Type__c = eventType,
            Decision__c = decision,
            Request_Payload__c = abbreviate(requestPayload, 32768),
            Response_Payload__c = abbreviate(responsePayload, 32768),
            Created_By_System__c = true,
            Trace_Id__c = String.valueOf(incidentId)
        );
    }

    private static Map<String, Object> slackField(String label, Object value) {
        return new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*' + label + ':*\n' + safe(value)
        };
    }

    private static String buildRecordUrl(Id recordId) {
        return URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/' + String.valueOf(recordId) + '/view';
    }

    private static String normalizePath(String path) {
        if (String.isBlank(path)) {
            return '';
        }
        return path.startsWith('/') ? path : '/' + path;
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return String.isBlank(firstValue) ? secondValue : firstValue;
    }

    private static String riskSignal(String riskLevel) {
        String normalized = String.isBlank(riskLevel) ? '' : riskLevel.toUpperCase();
        if (normalized == 'CRITICAL' || normalized == 'HIGH') {
            return ':red_circle:';
        }
        if (normalized == 'MEDIUM') {
            return ':large_orange_circle:';
        }
        if (normalized == 'LOW') {
            return ':large_green_circle:';
        }
        return ':white_circle:';
    }

    private static String teamsColor(String riskLevel) {
        String normalized = String.isBlank(riskLevel) ? '' : riskLevel.toUpperCase();
        if (normalized == 'CRITICAL' || normalized == 'HIGH') {
            return 'D92D20';
        }
        if (normalized == 'MEDIUM') {
            return 'F79009';
        }
        if (normalized == 'LOW') {
            return '12B76A';
        }
        return '667085';
    }

    private static String safe(Object value) {
        return value == null || String.isBlank(String.valueOf(value)) ? 'Not reported' : String.valueOf(value);
    }

    private static String abbreviate(String value, Integer maxLength) {
        if (value == null || maxLength == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private class DeliveryResult {
        Boolean success = false;
        String message;
    }

    private class WebhookConfig {
        String slackPath;
        String teamsPath;
    }
}
