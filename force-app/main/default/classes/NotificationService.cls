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
     * Send a webhook alert to an external URL (Slack, PagerDuty, etc.)
     * This is a placeholder — in production, use a Named Credential.
     */
    public static void sendWebhookAlert(Id incidentId, String webhookUrl) {
        if (incidentId == null || String.isBlank(webhookUrl)) { return; }

        Incident__c inc = [
            SELECT Id, Name, Severity__c, Description__c,
                   Revenue_at_Risk__c, Users_Affected__c
            FROM   Incident__c
            WHERE  Id = :incidentId
            LIMIT 1
        ];

        // Build JSON payload
        Map<String, Object> payload = new Map<String, Object>{
            'text' => '🚨 *SentinelFlow Alert* — ' + inc.Severity__c + ' Incident',
            'incident' => inc.Name,
            'description' => inc.Description__c,
            'severity' => inc.Severity__c,
            'usersAffected' => inc.Users_Affected__c,
            'revenueAtRisk' => inc.Revenue_at_Risk__c
        };

        AuditTrailService.log(
            incidentId,
            'Incident__c',
            'Webhook Alert Queued',
            null,
            'Payload prepared for: ' + webhookUrl
        );

        // In production: use HttpRequest with Named Credential
        // HttpRequest req = new HttpRequest();
        // req.setEndpoint(webhookUrl);
        // req.setMethod('POST');
        // req.setHeader('Content-Type', 'application/json');
        // req.setBody(JSON.serialize(payload));
        // new Http().send(req);
    }
}
