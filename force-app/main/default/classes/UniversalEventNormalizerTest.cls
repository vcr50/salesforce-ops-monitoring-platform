/**
 * UniversalEventNormalizerTest
 * Full test coverage for the CTO Universal Event Layer normalizer.
 *
 * Covers:
 *  - Integration_Log__c → Universal_Event__c normalization
 *  - Incident__c → Universal_Event__c normalization
 *  - Flow_Health__c → Universal_Event__c normalization
 *  - Idempotent upsert via Event_Key__c
 *  - Revenue risk aggregation from linked incidents
 *  - Severity / source / workflow-stage inference helpers
 *  - Null-safety & empty-list guards
 *
 * @author  SentinelFlow
 * @version 1.0
 */
@IsTest
private class UniversalEventNormalizerTest {

    // ── helpers ──────────────────────────────────────────────────────────────

    private static Boolean universalEventObjectExists() {
        return Schema.getGlobalDescribe().containsKey('Universal_Event__c');
    }

    private static Integration_Log__c createFailedLog(String apiName, String errorMessage) {
        Integration_Log__c log = new Integration_Log__c();
        log.API_Name__c      = apiName;
        log.Status__c        = 'Failed';
        log.Error_Message__c = errorMessage;
        return log;
    }

    private static Incident__c createIncident(String severity, String description, Id logId) {
        Incident__c inc = new Incident__c();
        inc.Severity__c       = severity;
        inc.Status__c         = 'New';
        inc.Description__c    = description;
        inc.Integration_Log__c = logId;
        return inc;
    }

    // ── Integration Log Normalization ────────────────────────────────────────

    @IsTest
    static void normalizeIntegrationLogs_createsEventsForFailedLogs() {
        if (!universalEventObjectExists()) return;

        Integration_Log__c log = createFailedLog('Stripe_Payments_API', 'Connection timeout');
        insert log;

        // The trigger already calls the normalizer, so events should exist
        List<Universal_Event__c> events = [
            SELECT Id, Source__c, Event_Type__c, Severity__c, Workflow_Stage__c,
                   Business_Impact__c, Revenue_Risk__c, Recovery_Possible__c,
                   Status__c, Source_Object__c, Source_Record_Id__c, Event_Key__c,
                   Integration_Log__c
            FROM Universal_Event__c
            WHERE Integration_Log__c = :log.Id
        ];

        System.assertEquals(1, events.size(), 'Should create one universal event per log');
        Universal_Event__c ev = events[0];
        System.assertEquals('Stripe', ev.Source__c, 'Source should be inferred from API name');
        System.assertEquals('API_FAILURE', ev.Event_Type__c, 'Failed log → API_FAILURE event type');
        System.assertEquals('Payment', ev.Workflow_Stage__c, 'Stripe keyword → Payment workflow');
        System.assertEquals(true, ev.Recovery_Possible__c, 'Failed logs are recoverable');
        System.assertEquals('New', ev.Status__c, 'Failed log → New status');
        System.assertEquals('Integration_Log__c', ev.Source_Object__c);
        System.assertEquals(String.valueOf(log.Id), ev.Source_Record_Id__c);
        System.assertEquals('Integration_Log__c:' + log.Id, ev.Event_Key__c);
    }

    @IsTest
    static void normalizeIntegrationLogs_createsRecoveryEventOnSuccess() {
        if (!universalEventObjectExists()) return;

        Integration_Log__c log = new Integration_Log__c();
        log.API_Name__c = 'HubSpot_Contacts_Sync';
        log.Status__c   = 'Success';
        insert log;

        List<Universal_Event__c> events = [
            SELECT Id, Event_Type__c, Source__c, Status__c, Recovery_Possible__c
            FROM Universal_Event__c
            WHERE Integration_Log__c = :log.Id
        ];

        System.assertEquals(1, events.size(), 'Should create event for success logs too');
        System.assertEquals('RECOVERY', events[0].Event_Type__c, 'Success log → RECOVERY');
        System.assertEquals('HubSpot', events[0].Source__c);
        System.assertEquals('Resolved', events[0].Status__c);
        System.assertEquals(false, events[0].Recovery_Possible__c);
    }

    @IsTest
    static void normalizeIntegrationLogs_idempotentUpsert() {
        if (!universalEventObjectExists()) return;

        Integration_Log__c log = createFailedLog('SAP_ERP_API', 'Timeout');
        insert log;

        Integer countBefore = [SELECT COUNT() FROM Universal_Event__c WHERE Integration_Log__c = :log.Id];
        System.assertEquals(1, countBefore, 'First insert should create one event');

        // Update the log — trigger calls normalizer again
        log.Error_Message__c = 'Updated error';
        update log;

        Integer countAfter = [SELECT COUNT() FROM Universal_Event__c WHERE Integration_Log__c = :log.Id];
        System.assertEquals(1, countAfter, 'Upsert should NOT create a duplicate');
    }

    // ── Incident Normalization ──────────────────────────────────────────────

    @IsTest
    static void normalizeIncidents_createsEventsForNewIncidents() {
        if (!universalEventObjectExists()) return;

        Incident__c inc = new Incident__c();
        inc.Severity__c       = 'Critical';
        inc.Status__c         = 'New';
        inc.Description__c    = 'Payment processing failure in checkout workflow';
        inc.Users_Affected__c = 250;
        inc.Revenue_at_Risk__c = 45000;
        insert inc;

        List<Universal_Event__c> events = [
            SELECT Id, Event_Type__c, Severity__c, Revenue_Risk__c, Users_Affected__c,
                   Status__c, Source__c, Workflow_Stage__c, Business_Impact__c,
                   Recovery_Possible__c, Incident__c
            FROM Universal_Event__c
            WHERE Incident__c = :inc.Id
        ];

        System.assertEquals(1, events.size(), 'Should create one universal event per incident');
        Universal_Event__c ev = events[0];
        System.assertEquals('INCIDENT', ev.Event_Type__c);
        System.assertEquals('Critical', ev.Severity__c);
        System.assertEquals(45000, ev.Revenue_Risk__c);
        System.assertEquals(250, ev.Users_Affected__c);
        System.assertEquals('New', ev.Status__c);
        System.assertEquals('Salesforce', ev.Source__c);
        System.assert(ev.Business_Impact__c.contains('Payment'), 'Impact should contain description');
    }

    @IsTest
    static void normalizeIncidents_estimatesRevenueWhenNull() {
        if (!universalEventObjectExists()) return;

        Incident__c inc = new Incident__c();
        inc.Severity__c    = 'High';
        inc.Status__c      = 'New';
        inc.Description__c = 'Renewal workflow broken';
        // Revenue_at_Risk__c intentionally null
        // Users_Affected__c intentionally null
        insert inc;

        List<Universal_Event__c> events = [
            SELECT Revenue_Risk__c, Users_Affected__c, Workflow_Stage__c
            FROM Universal_Event__c
            WHERE Incident__c = :inc.Id
        ];

        System.assertEquals(1, events.size());
        System.assert(events[0].Revenue_Risk__c > 0, 'Should estimate revenue risk from severity');
        System.assert(events[0].Users_Affected__c > 0, 'Should estimate users from severity');
        System.assertEquals('Renewal', events[0].Workflow_Stage__c, 'Keyword "renewal" → Renewal stage');
    }

    @IsTest
    static void normalizeIncidents_updatesStatusOnResolution() {
        if (!universalEventObjectExists()) return;

        Incident__c inc = new Incident__c();
        inc.Severity__c    = 'Medium';
        inc.Status__c      = 'New';
        inc.Description__c = 'Test order fulfillment delay';
        insert inc;

        // Resolve the incident — before-update trigger calls normalizer
        inc.Status__c = 'Resolved';
        update inc;

        List<Universal_Event__c> events = [
            SELECT Status__c
            FROM Universal_Event__c
            WHERE Incident__c = :inc.Id
        ];

        System.assertEquals(1, events.size());
        System.assertEquals('Resolved', events[0].Status__c, 'Event status should sync with incident');
    }

    @IsTest
    static void normalizeIncidents_aggregatesRevenueFromLinkedIncidents() {
        if (!universalEventObjectExists()) return;

        // Create a failed log first
        Integration_Log__c log = createFailedLog('Shopify_Orders_API', 'Gateway error');
        insert log;

        // Create multiple incidents linked to the same log
        List<Incident__c> incidents = new List<Incident__c>();
        incidents.add(createIncident('High', 'Shopify order sync failed - batch 1', log.Id));
        incidents.add(createIncident('Critical', 'Shopify order sync failed - batch 2', log.Id));

        incidents[0].Revenue_at_Risk__c = 10000;
        incidents[0].Users_Affected__c  = 50;
        incidents[1].Revenue_at_Risk__c = 25000;
        incidents[1].Users_Affected__c  = 100;
        insert incidents;

        // Now re-normalize the log — it should pick up aggregated incident data
        Test.startTest();
        UniversalEventNormalizer.normalizeIntegrationLogs(new List<Integration_Log__c>{
            [SELECT Id, API_Name__c, Status__c, Error_Message__c FROM Integration_Log__c WHERE Id = :log.Id]
        });
        Test.stopTest();

        List<Universal_Event__c> logEvents = [
            SELECT Revenue_Risk__c, Users_Affected__c, Severity__c
            FROM Universal_Event__c
            WHERE Source_Object__c = 'Integration_Log__c'
            AND Integration_Log__c = :log.Id
        ];

        System.assertEquals(1, logEvents.size());
        System.assertEquals(35000, logEvents[0].Revenue_Risk__c, 'Revenue should aggregate: 10K + 25K');
        System.assertEquals(150, logEvents[0].Users_Affected__c, 'Users should aggregate: 50 + 100');
        System.assertEquals('Critical', logEvents[0].Severity__c, 'Severity should be the highest');
    }

    // ── Edge Cases & Guards ─────────────────────────────────────────────────

    @IsTest
    static void normalizeIntegrationLogs_handlesNullAndEmptyLists() {
        // These should complete without exception
        UniversalEventNormalizer.normalizeIntegrationLogs(null);
        UniversalEventNormalizer.normalizeIntegrationLogs(new List<Integration_Log__c>());
        // No assert needed — no exception = pass
        System.assert(true, 'Null/empty guard completed without error');
    }

    @IsTest
    static void normalizeIncidents_handlesNullAndEmptyLists() {
        UniversalEventNormalizer.normalizeIncidents(null);
        UniversalEventNormalizer.normalizeIncidents(new List<Incident__c>());
        System.assert(true, 'Null/empty guard completed without error');
    }

    @IsTest
    static void normalizeIntegrationLogs_handlesWarningStatus() {
        if (!universalEventObjectExists()) return;

        Integration_Log__c log = new Integration_Log__c();
        log.API_Name__c = 'Internal_Service_API';
        log.Status__c   = 'Warning';
        insert log;

        List<Universal_Event__c> events = [
            SELECT Severity__c, Event_Type__c, Recovery_Possible__c, Source__c
            FROM Universal_Event__c
            WHERE Integration_Log__c = :log.Id
        ];

        System.assertEquals(1, events.size());
        System.assertEquals('Medium', events[0].Severity__c, 'Warning → Medium severity');
        System.assertEquals('API_FAILURE', events[0].Event_Type__c, 'Warning is still a failure event');
        System.assertEquals(true, events[0].Recovery_Possible__c);
        System.assertEquals('Salesforce', events[0].Source__c, 'Unknown API → Salesforce default');
    }

    // ── Flow Health Normalization ────────────────────────────────────────────

    @IsTest
    static void normalizeFlowHealth_createsFlowFailureEvents() {
        if (!universalEventObjectExists()) return;
        if (!Schema.getGlobalDescribe().containsKey('Flow_Health__c')) return;

        Flow_Health__c fh = new Flow_Health__c();
        fh.Flow_API_Name__c    = 'Lead_Assignment_Flow';
        fh.Last_Run_Status__c  = 'Failed';
        fh.Error_Message__c    = 'LIMIT_EXCEEDED: Too many SOQL queries';
        fh.Last_Failure_Date__c = System.now();
        insert fh;

        Test.startTest();
        UniversalEventNormalizer.normalizeFlowHealth(new List<Flow_Health__c>{ fh });
        Test.stopTest();

        List<Universal_Event__c> events = [
            SELECT Event_Type__c, Source__c, Severity__c, Workflow_Stage__c,
                   Business_Impact__c, Source_Object__c
            FROM Universal_Event__c
            WHERE Source_Object__c = 'Flow_Health__c'
            AND Source_Record_Id__c = :String.valueOf(fh.Id)
        ];

        System.assertEquals(1, events.size(), 'Should create event for failed flow');
        System.assertEquals('FLOW_FAILURE', events[0].Event_Type__c);
        System.assertEquals('Salesforce', events[0].Source__c);
        System.assert(events[0].Business_Impact__c.contains('Lead_Assignment_Flow'));
    }
}

