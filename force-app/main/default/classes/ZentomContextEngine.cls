public with sharing class ZentomContextEngine {
    public class ContextPacket {
        public List<String> similarIncidents; // from Memory Engine
        public Decimal accountARR;
        public String accountTier;
        public String runbookUrl;
        public String incidentHistory;
        public String errorSignature;
    }

    /**
     * Assembles full situational awareness before any AI reasoning.
     * Wires into ZentomMemoryEngine for historical pattern matching
     * and queries live Salesforce data for business context.
     */
    public static ContextPacket assembleContext(Id incidentId) {
        ContextPacket packet = new ContextPacket();
        packet.similarIncidents = new List<String>();

        // ── Query the Incident for real data ──────────────────────────────
        Incident__c inc = null;
        try {
            SecurityGate.requireReadAccess('Incident__c', new Set<String>{
                'Id', 'Severity__c', 'Description__c', 'Root_Cause__c',
                'Revenue_at_Risk__c', 'Integration_Log__c'
            });
            inc = [
                SELECT Id, Severity__c, Description__c, Root_Cause__c,
                       Revenue_at_Risk__c,
                       Integration_Log__r.Error_Message__c
                FROM Incident__c
                WHERE Id = :incidentId
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('ContextEngine: Failed to query incident: ' + e.getMessage());
        }

        // ── 1. Memory Engine (Similar Incidents via historical pattern match) ──
        String errorSig = '';
        if (inc != null && inc.Integration_Log__r != null && inc.Integration_Log__r.Error_Message__c != null) {
            errorSig = inc.Integration_Log__r.Error_Message__c;
        } else if (inc != null && inc.Description__c != null) {
            errorSig = inc.Description__c;
        }
        packet.errorSignature = errorSig;

        try {
            ZentomMemoryEngine.HistoricalContext memory = ZentomMemoryEngine.retrieveMemoryForIncident('Diagnosis', errorSig);
            if (memory.wasSuccessful) {
                packet.similarIncidents.add('Memory Match: ' + memory.previousResolution + ' (Confidence: ' + memory.confidenceScore + ')');
            } else {
                packet.similarIncidents.add(memory.previousResolution);
            }
        } catch (Exception e) {
            packet.similarIncidents.add('Memory Engine unavailable: ' + e.getMessage());
        }

        // ── 2. Salesforce Business Context (Live Data) ────────────────────
        if (inc != null && inc.Revenue_at_Risk__c != null) {
            packet.accountARR = inc.Revenue_at_Risk__c;
        } else {
            packet.accountARR = 150000.00; // Default for prototype
        }

        // Determine tier from ARR
        if (packet.accountARR >= 500000) {
            packet.accountTier = 'Strategic';
        } else if (packet.accountARR >= 100000) {
            packet.accountTier = 'Enterprise';
        } else if (packet.accountARR >= 25000) {
            packet.accountTier = 'Growth';
        } else {
            packet.accountTier = 'Standard';
        }

        // ── 3. Knowledge Base ─────────────────────────────────────────────
        packet.runbookUrl = 'https://docs.sentinelflow.com/runbooks/auto-generated';

        // ── 4. Incident History ───────────────────────────────────────────
        try {
            Integer priorCount = [
                SELECT COUNT()
                FROM Incident__c
                WHERE CreatedDate = LAST_N_DAYS:30
                AND Id != :incidentId
            ];
            packet.incidentHistory = priorCount + ' incidents in the last 30 days.';
        } catch (Exception e) {
            packet.incidentHistory = 'Incident history unavailable.';
        }

        return packet;
    }
}

