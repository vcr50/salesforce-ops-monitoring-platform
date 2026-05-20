/**
 * UniversalEventWebhookApi
 * Dedicated Webhook Ingestion API for Phase 1 of CTO Blueprint.
 * Directly catches standard webhooks from external systems (Stripe, Shopify, HubSpot)
 * and drops them into the Universal Event timeline.
 *
 * Endpoints:
 * - POST /services/apexrest/sentinelflow/webhook/stripe
 * - POST /services/apexrest/sentinelflow/webhook/shopify
 * - POST /services/apexrest/sentinelflow/webhook/hubspot
 *
 * @author SentinelFlow
 * @version 1.0
 */
@RestResource(urlMapping='/sentinelflow/webhook/*')
@SuppressWarnings('PMD.ApexCRUDViolation')
global without sharing class UniversalEventWebhookApi {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        
        try {
            // Extract the provider from the URI (e.g. /stripe, /shopify)
            String provider = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1).toLowerCase();
            String requestBody = req.requestBody.toString();
            
            // Note: In production, we'd verify the HMAC signature of the webhook here
            
            List<Universal_Event__c> events = new List<Universal_Event__c>();
            
            if (provider == 'stripe') {
                events.addAll(parseStripeWebhook(requestBody));
            } else if (provider == 'shopify') {
                events.addAll(parseShopifyWebhook(requestBody));
            } else if (provider == 'hubspot') {
                events.addAll(parseHubspotWebhook(requestBody));
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Unknown webhook provider: ' + provider + '"}');
                return;
            }
            
            if (!events.isEmpty()) {
                // Determine tenant context if passed in headers, else default or null
                Id tenantId = TenantContext.getCurrentTenantId();
                for (Universal_Event__c ev : events) {
                    if (tenantId != null && hasTenantField()) {
                        ev.put('Tenant__c', tenantId);
                    }
                }
                upsert events Universal_Event__c.Event_Key__c;
            }
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"success","eventsCreated":' + events.size() + '}');
            
        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + ex.getMessage() + '"}');
            SystemLogger.logMessage('UniversalEventWebhookApi', 'doPost', 'ERROR', ex.getMessage());
        }
    }
    
    private static List<Universal_Event__c> parseStripeWebhook(String jsonBody) {
        List<Universal_Event__c> results = new List<Universal_Event__c>();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        
        String type = (String) payload.get('type');
        String eventId = (String) payload.get('id');
        
        // We only care about failure/risk events for the universal event timeline
        if (type == 'invoice.payment_failed' || type == 'charge.failed' || type == 'customer.subscription.deleted') {
            Map<String, Object> data = (Map<String, Object>) payload.get('data');
            Map<String, Object> obj = (Map<String, Object>) data.get('object');
            
            Decimal amount = 0;
            if (obj.containsKey('amount_due')) {
                amount = ((Decimal) obj.get('amount_due')) / 100;
            } else if (obj.containsKey('amount')) {
                amount = ((Decimal) obj.get('amount')) / 100;
            }
            
            Universal_Event__c ev = new Universal_Event__c();
            ev.Event_Key__c = 'Stripe:' + eventId;
            ev.Source__c = 'Stripe';
            ev.Source_Object__c = 'Webhook';
            ev.Source_Record_Id__c = eventId;
            ev.Event_Type__c = 'API_FAILURE';
            ev.Severity__c = amount > 1000 ? 'Critical' : 'High';
            ev.Workflow_Stage__c = 'Payment';
            ev.Revenue_Risk__c = amount;
            ev.Users_Affected__c = 1;
            ev.Recovery_Possible__c = true;
            ev.Status__c = 'New';
            ev.Business_Impact__c = 'Stripe Webhook: ' + type + '. Amount at risk: $' + amount;
            
            results.add(ev);
        }
        
        return results;
    }
    
    private static List<Universal_Event__c> parseShopifyWebhook(String jsonBody) {
        List<Universal_Event__c> results = new List<Universal_Event__c>();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        
        // Very simplified parsing for Shopify fulfillment or payment failures
        String type = 'shopify_event'; // Normally from headers X-Shopify-Topic
        String eventId = String.valueOf(payload.get('id'));
        
        Universal_Event__c ev = new Universal_Event__c();
        ev.Event_Key__c = 'Shopify:' + eventId;
        ev.Source__c = 'Shopify';
        ev.Source_Object__c = 'Webhook';
        ev.Source_Record_Id__c = eventId;
        ev.Event_Type__c = 'API_FAILURE';
        ev.Severity__c = 'Medium';
        ev.Workflow_Stage__c = 'Fulfillment';
        ev.Revenue_Risk__c = payload.containsKey('total_price') ? Decimal.valueOf((String)payload.get('total_price')) : 0;
        ev.Users_Affected__c = 1;
        ev.Recovery_Possible__c = true;
        ev.Status__c = 'New';
        ev.Business_Impact__c = 'Shopify Webhook event received. Review payload for details.';
        
        results.add(ev);
        return results;
    }
    
    private static List<Universal_Event__c> parseHubspotWebhook(String jsonBody) {
        List<Universal_Event__c> results = new List<Universal_Event__c>();
        // Hubspot sends arrays of events
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(jsonBody);
        
        for (Object item : payload) {
            Map<String, Object> evt = (Map<String, Object>) item;
            String type = (String) evt.get('subscriptionType');
            String eventId = String.valueOf(evt.get('eventId'));
            
            if (type == 'contact.deletion' || type == 'company.deletion') {
                Universal_Event__c ev = new Universal_Event__c();
                ev.Event_Key__c = 'HubSpot:' + eventId;
                ev.Source__c = 'HubSpot';
                ev.Source_Object__c = 'Webhook';
                ev.Source_Record_Id__c = eventId;
                ev.Event_Type__c = 'API_FAILURE';
                ev.Severity__c = 'High';
                ev.Workflow_Stage__c = 'Lead Capture';
                ev.Revenue_Risk__c = 500; // Estimated
                ev.Users_Affected__c = 1;
                ev.Recovery_Possible__c = false;
                ev.Status__c = 'New';
                ev.Business_Impact__c = 'HubSpot Webhook: ' + type;
                
                results.add(ev);
            }
        }
        
        return results;
    }
    
    private static Boolean hasTenantField() {
        return Schema.getGlobalDescribe().get('Universal_Event__c').getDescribe().fields.getMap().containsKey('Tenant__c');
    }
}

