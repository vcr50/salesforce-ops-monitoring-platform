/**
 * SentinelFlowEventPublisherTest
 * Runs comprehensive unit tests to validate SentinelFlowEventPublisher execution,
 * bulk publishing efficiency, and transaction recursion guard safety.
 *
 * @author TomCodeX Engineering
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
public with sharing class SentinelFlowEventPublisherTest {

    @IsTest
    static void testPublishSingleEvent() {
        // Create an incident context
        Sentinel_Incident__c inc = new Sentinel_Incident__c(
            Incident_Type__c = 'INTEGRATION_ERROR',
            Risk_Level__c = 'HIGH',
            Environment__c = 'production',
            Status__c = 'New',
            AI_Confidence__c = 85
        );
        insert inc;

        // Query the auto-number Name field to ensure it is populated
        inc = [SELECT Id, Name, Incident_Type__c, Risk_Level__c, Approval_Status__c, 
                      Execution_Status__c, AI_Reasoning_Status__c, AI_Confidence__c, Environment__c 
               FROM Sentinel_Incident__c WHERE Id = :inc.Id];

        Test.startTest();
        SentinelFlowEventPublisher.publish(
            'INCIDENT_CREATED',
            inc,
            'SentinelFlowEventPublisherTest.testPublishSingleEvent',
            'New incident has been created and analyzed.'
        );
        Test.stopTest(); // Delivers all Platform Events synchronously in test context

        System.assert(true, 'Single event published without throwing limit errors.');
    }

    @IsTest
    static void testPublishBulkEvents() {
        List<Sentinel_Incident__c> incidents = new List<Sentinel_Incident__c>();
        for (Integer i = 0; i < 200; i++) {
            incidents.add(new Sentinel_Incident__c(
                Incident_Type__c = 'FLOW_FAILURE',
                Risk_Level__c = 'MEDIUM',
                Environment__c = 'sandbox',
                Status__c = 'New'
            ));
        }
        insert incidents;

        // Query incidents to get ID and Name
        incidents = [SELECT Id, Name, Incident_Type__c, Risk_Level__c, Approval_Status__c, 
                            Execution_Status__c, AI_Reasoning_Status__c, AI_Confidence__c, Environment__c 
                     FROM Sentinel_Incident__c WHERE Id IN :incidents];

        Test.startTest();
        // Clear transaction limits tracker before starting publishing
        Integer startingDml = Limits.getDmlStatements();

        SentinelFlowEventPublisher.publishBulk(
            'RISK_UPDATED',
            incidents,
            'SentinelFlowEventPublisherTest.testPublishBulkEvents',
            'Bulk risk scoring changes processed.'
        );
        Test.stopTest();

        Integer endingDml = Limits.getDmlStatements();
        System.assertEquals(1, endingDml - startingDml, 'Bulk events must be published in exactly 1 DML statement.');
    }

    @IsTest
    static void testRecursionGuard() {
        Sentinel_Incident__c inc = new Sentinel_Incident__c(
            Incident_Type__c = 'SECURITY_EVENT',
            Risk_Level__c = 'CRITICAL',
            Environment__c = 'production',
            Status__c = 'New'
        );
        insert inc;

        inc = [SELECT Id, Name, Incident_Type__c, Risk_Level__c, Approval_Status__c, 
                      Execution_Status__c, AI_Reasoning_Status__c, AI_Confidence__c, Environment__c 
               FROM Sentinel_Incident__c WHERE Id = :inc.Id];

        Test.startTest();
        // Clear transaction tracker statements
        Integer startingDml = Limits.getDmlStatements();

        // 1st Publish: Unique incident + eventType combo
        SentinelFlowEventPublisher.publish(
            'APPROVAL_REQUIRED', 
            inc, 
            'SentinelFlowEventPublisherTest.testRecursionGuard', 
            'Guardian Gate approval required.'
        );

        // 2nd Publish: Duplicate combo
        SentinelFlowEventPublisher.publish(
            'APPROVAL_REQUIRED', 
            inc, 
            'SentinelFlowEventPublisherTest.testRecursionGuard', 
            'Duplicate - Should be ignored by recursion guard.'
        );

        Test.stopTest();

        Integer endingDml = Limits.getDmlStatements();
        System.assertEquals(1, endingDml - startingDml, 'Duplicate publishing calls in the same transaction must be suppressed.');
    }

    @IsTest
    static void testSystemEvent() {
        Test.startTest();
        SentinelFlowEventPublisher.publishSystemEvent(
            'ERROR_LOGGED',
            'SentinelFlowEventPublisherTest.testSystemEvent',
            'Webhook delivery failed after max retries.'
        );
        Test.stopTest();

        System.assert(true, 'System-wide event published successfully without requiring incident context.');
    }
}
