/**
 * SettingsController
 * Apex controller for sentinelFlowPortalSettings LWC.
 * Persists Retry Rules and Alert Configuration to
 * SentinelFlow_Settings__c (Hierarchy Custom Setting).
 *
 * @author  Tomcodex
 * @version 1.0
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class SettingsController {

    // ── Inner wrapper ─────────────────────────────────────────────────────────

    public class SettingsData {
        @AuraEnabled public Boolean autonomousHealing;
        @AuraEnabled public Integer confidenceThreshold;
        @AuraEnabled public Integer circuitBreakerThreshold;
        @AuraEnabled public Integer silentFailureMinutes;
        @AuraEnabled public Boolean autoEscalate;
        @AuraEnabled public Boolean emailAlertsEnabled;
        @AuraEnabled public String  slackWebhookPath;
        @AuraEnabled public String  alertSeverity;
        @AuraEnabled public Boolean notifyOnHeal;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrencyConfig() {
        Map<String, Object> config = new Map<String, Object>();
        String currencyCode = 'USD';
        String currencySymbol = '$';
        Decimal conversionRate = 1.0;

        try {
            // 1. Detect standard multi-currency setting or user default currency
            String userCurrency = UserInfo.getDefaultCurrency();
            if (String.isNotBlank(userCurrency)) {
                currencyCode = userCurrency;
            }

            // 2. Query conversion rate if multi-currency is enabled (dynamic query)
            if (Schema.getGlobalDescribe().containsKey('CurrencyType')) {
                String query = 'SELECT ConversionRate FROM CurrencyType WHERE IsoCode = :currencyCode AND IsActive = true LIMIT 1';
                List<SObject> rates = Database.query(query);
                if (!rates.isEmpty()) {
                    conversionRate = (Decimal) rates[0].get('ConversionRate');
                }
            } else {
                // Fallback: If currency is INR but conversion rate is 1.0 (since multi-currency is disabled),
                // we can fall back to standard USD -> INR rate (e.g. 83.0) for demonstration
                if (currencyCode == 'INR') {
                    conversionRate = 83.0;
                }
            }

            // 3. Determine currency symbol
            if (currencyCode == 'INR') {
                currencySymbol = '₹';
            } else if (currencyCode == 'EUR') {
                currencySymbol = '€';
            } else if (currencyCode == 'GBP') {
                currencySymbol = '£';
            } else if (currencyCode == 'JPY') {
                currencySymbol = '¥';
            } else {
                currencySymbol = '$';
            }
        } catch (Exception e) {
            System.debug('Error in getCurrencyConfig: ' + e.getMessage());
        }

        config.put('code', currencyCode);
        config.put('symbol', currencySymbol);
        config.put('rate', conversionRate);
        return config;
    }

    // ── READ ─────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static SettingsData loadSettings() {
        SentinelFlow_Settings__c s = SentinelFlow_Settings__c.getOrgDefaults();

        SettingsData data         = new SettingsData();
        data.autonomousHealing    = s.Autonomous_Healing__c    != null ? s.Autonomous_Healing__c    : true;
        data.confidenceThreshold  = s.Confidence_Threshold__c  != null ? Integer.valueOf(s.Confidence_Threshold__c)  : 85;
        data.circuitBreakerThreshold = s.Circuit_Breaker_Threshold__c != null
                                     ? Integer.valueOf(s.Circuit_Breaker_Threshold__c) : 5;
        // Silent_Failure_Minutes__c read safely
        Object sfm = s.get('Silent_Failure_Minutes__c');
        data.silentFailureMinutes = sfm != null ? Integer.valueOf((Decimal) sfm) : 30;
        data.autoEscalate         = s.Auto_Escalate__c         != null ? s.Auto_Escalate__c         : true;
        data.emailAlertsEnabled   = s.Enable_Alerts__c         != null ? s.Enable_Alerts__c         : true;
        data.slackWebhookPath     = s.Slack_Webhook_Path__c    != null ? s.Slack_Webhook_Path__c    : '';
        data.alertSeverity        = s.Alert_Severity__c        != null ? s.Alert_Severity__c        : 'High';
        data.notifyOnHeal         = s.Notify_On_Heal__c        != null ? s.Notify_On_Heal__c        : true;
        return data;
    }

    // ── SAVE RETRY RULES ─────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveRetryRules(
        Boolean autonomousHealing,
        Integer confidenceThreshold,
        Integer circuitBreakerThreshold,
        Integer silentFailureMinutes,
        Boolean autoEscalate
    ) {
        SentinelFlow_Settings__c s = SentinelFlow_Settings__c.getOrgDefaults();
        s.Autonomous_Healing__c       = autonomousHealing;
        s.Confidence_Threshold__c     = confidenceThreshold;
        s.Circuit_Breaker_Threshold__c = circuitBreakerThreshold;
        s.put('Silent_Failure_Minutes__c', (Decimal) silentFailureMinutes);
        s.Auto_Escalate__c            = autoEscalate;
        upsert s;

        AuditTrailService.log(null, 'SentinelFlow_Settings__c', 'Retry Rules Saved', null,
            'Updated by: ' + UserInfo.getUserName());
    }

    // ── SAVE ALERT CONFIG ────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveAlertConfig(
        Boolean emailAlertsEnabled,
        String  slackWebhookPath,
        String  alertSeverity,
        Boolean notifyOnHeal
    ) {
        SentinelFlow_Settings__c s = SentinelFlow_Settings__c.getOrgDefaults();
        s.Enable_Alerts__c      = emailAlertsEnabled;
        s.Slack_Webhook_Path__c = slackWebhookPath;
        s.Alert_Severity__c     = alertSeverity;
        s.Notify_On_Heal__c     = notifyOnHeal;
        upsert s;

        AuditTrailService.log(null, 'SentinelFlow_Settings__c', 'Alert Config Saved', null,
            'Updated by: ' + UserInfo.getUserName());
    }

    // ── SLACK TEST (callout — must be @future) ───────────────────────────────

    @AuraEnabled
    public static String testSlackWebhook(String webhookPath) {
        if (String.isBlank(webhookPath) || !webhookPath.startsWith('/services/')) {
            return 'ERROR: Invalid webhook path. Must start with /services/';
        }

        // Build minimal Slack test payload
        Map<String, Object> textBlock = new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*✅ SentinelFlow Test* — Slack alerts are configured correctly.'
        };
        Map<String, Object> section = new Map<String, Object>{
            'type' => 'section',
            'text' => textBlock
        };
        Map<String, Object> payload = new Map<String, Object>{
            'blocks' => new List<Object>{ section }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Webhook' + webhookPath);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(10000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                return 'SUCCESS';
            }
            return 'ERROR: HTTP ' + res.getStatusCode() + ' — ' + res.getBody();
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }
}

