/**
 * NotificationService
 * Handles alerting for SentinelFlow — email notifications,
 * in-app custom notifications, and webhook dispatching.
 *
 * @author  Tomcodex
 * @version 1.0
 */
public with sharing class NotificationService {

    /**
     * Send an email alert when a Critical incident is created.
     * Targets the tenant's admin users.
     */
    public static void sendIncidentAlert(Id incidentId) {
        if (incidentId == null) { return; }

        Incident__c inc = [
            SELECT Id, Name, Severity__c, Description__c,
                   Revenue_at_Risk__c, Users_Affected__c,
                   Tenant__r.Name
            FROM   Incident__c
            WHERE  Id = :incidentId
            LIMIT 1
        ];

        // Build the email body
        String subject = '🚨 SentinelFlow Alert — ' + inc.Severity__c + ' Incident: ' + inc.Name;

        String body = 'A ' + inc.Severity__c + ' incident has been detected.\n\n'
            + '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
            + 'Incident:       ' + inc.Name + '\n'
            + 'Tenant:         ' + (inc.Tenant__r != null ? inc.Tenant__r.Name : 'Default') + '\n'
            + 'Severity:       ' + inc.Severity__c + '\n'
            + 'Description:    ' + inc.Description__c + '\n'
            + 'Users Affected: ' + (inc.Users_Affected__c != null ? String.valueOf(inc.Users_Affected__c.intValue()) : '0') + '\n'
            + 'Revenue Risk:   $' + (inc.Revenue_at_Risk__c != null ? String.valueOf(inc.Revenue_at_Risk__c.setScale(0)) : '0') + '\n'
            + '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'
            + 'AI analysis has been queued. Log in to SentinelFlow to view details and take action.\n\n'
            + '— SentinelFlow Incident Intelligence Platform';

        // Send to the current user (in production, query tenant admin users)
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            AuditTrailService.log(
                incidentId,
                'Incident__c',
                'Alert Sent',
                null,
                'Email alert sent to: ' + UserInfo.getUserEmail()
            );
        } catch (Exception ex) {
            // Non-fatal — log but don't crash
            AuditTrailService.log(
                incidentId,
                'Incident__c',
                'Alert Failed',
                null,
                'Email alert failed: ' + ex.getMessage()
            );
        }
    }

    /**
     * Send a Slack alert via Named Credential (callout-safe, async).
     * The webhook path is automatically retrieved from the Tenant__c record.
     */
    @future(callout=true)
    public static void sendSlackAlert(Id incidentId) {
        if (incidentId == null) { return; }

        Incident__c inc = [
            SELECT Id, Name, Severity__c, Description__c,
                   Revenue_at_Risk__c, Users_Affected__c,
                   Tenant__r.Name, Tenant__r.Slack_Webhook_Path__c, Status__c
            FROM   Incident__c
            WHERE  Id = :incidentId
            LIMIT 1
        ];

        String webhookPath = inc.Tenant__r?.Slack_Webhook_Path__c;
        if (String.isBlank(webhookPath)) {
            return; // No Slack integration configured for this tenant
        }

        String severityEmoji = inc.Severity__c == 'Critical' ? '🔴'
                             : inc.Severity__c == 'High'     ? '🟠'
                             : inc.Severity__c == 'Medium'   ? '🟡' : '🟢';

        // Build Slack Block Kit payload
        Map<String, Object> headerText = new Map<String, Object>{
            'type' => 'plain_text',
            'text' => severityEmoji + ' SentinelFlow — ' + inc.Severity__c + ' Incident Detected',
            'emoji' => true
        };
        Map<String, Object> headerBlock = new Map<String, Object>{
            'type' => 'header',
            'text' => headerText
        };

        String detailText = '*Incident:* ' + inc.Name + '\n'
            + '*Tenant:* ' + (inc.Tenant__r != null ? inc.Tenant__r.Name : 'Default') + '\n'
            + '*Severity:* ' + inc.Severity__c + '\n'
            + '*Status:* ' + inc.Status__c + '\n'
            + '*Users Affected:* ' + (inc.Users_Affected__c != null ? String.valueOf(inc.Users_Affected__c.intValue()) : '0') + '\n'
            + '*Revenue at Risk:* $' + (inc.Revenue_at_Risk__c != null ? String.valueOf(inc.Revenue_at_Risk__c.setScale(0)) : '0');

        Map<String, Object> sectionText = new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => detailText
        };
        Map<String, Object> sectionBlock = new Map<String, Object>{
            'type' => 'section',
            'text' => sectionText
        };

        Map<String, Object> dividerBlock = new Map<String, Object>{
            'type' => 'divider'
        };

        Map<String, Object> contextElement = new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '_Automated alert from SentinelFlow Reliability Platform_'
        };
        Map<String, Object> contextBlock = new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{ contextElement }
        };

        Map<String, Object> payload = new Map<String, Object>{
            'blocks' => new List<Object>{ headerBlock, sectionBlock, dividerBlock, contextBlock }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Webhook' + webhookPath);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(10000);

        try {
            // Respect alert toggle
            SentinelFlow_Settings__c settings = SentinelFlow_Settings__c.getOrgDefaults();
            if (settings != null && !settings.Enable_Alerts__c) {
                return; // Alerts disabled by admin
            }

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200) {
                // Non-200 → fallback to email (never silent failure)
                AuditTrailService.log(incidentId, 'Incident__c', 'Slack Alert Failed', null, 'HTTP ' + res.getStatusCode() + ' — falling back to email.');
                sendIncidentAlert(incidentId);
            } else {
                String logMsg = 'Slack response: HTTP ' + res.getStatusCode() + ' — ' + res.getBody();
                AuditTrailService.log(incidentId, 'Incident__c', 'Slack Alert Sent', null, logMsg);
            }
        } catch (Exception ex) {
            // Exception → fallback to email (never silent failure)
            AuditTrailService.log(incidentId, 'Incident__c', 'Slack Alert Failed', null, ex.getMessage());
            sendIncidentAlert(incidentId);
        }
    }


}
