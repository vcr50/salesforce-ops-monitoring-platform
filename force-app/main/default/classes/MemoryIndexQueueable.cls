/**
 * MemoryIndexQueueable
 * Queues an incident memory indexing callout to the SentinelFlow backend API.
 * Called after a heal action completes (success or failure) so that the
 * operational memory store is kept up to date with every recovery outcome.
 *
 * Uses the SentinelFlow_Backend Named Credential for all callouts so that
 * no endpoint URLs or credentials appear in Apex source code.
 *
 * @author  Tomcodex
 * @version 2.6
 */
public with sharing class MemoryIndexQueueable implements Queueable, Database.AllowsCallouts {

    private String incidentId;
    private String outcome;       // 'success' | 'failed' | 'escalated'
    private String healAction;    // 'oauth_refresh' | 'retry' | 'pause_batch' | 'requeue_job'
    private String rootCause;
    private Integer durationMs;

    /**
     * Backward-compatible constructor for AutoHealOrchestrator:
     * new MemoryIndexQueueable(incidentId, success)
     *
     * @param incidentId  Salesforce record Id of the incident
     * @param success     Whether the heal action succeeded
     */
    public MemoryIndexQueueable(Id incidentId, Boolean success) {
        this.incidentId = String.valueOf(incidentId);
        this.outcome    = success == true ? 'success' : 'failed';
        this.healAction = 'auto_heal';
        this.rootCause  = 'Triggered by AutoHealOrchestrator';
        this.durationMs = 0;
    }

    /**
     * @param incidentId  Salesforce Id of the SF_Incident__c / Incident__c record
     * @param outcome     Result of the heal attempt
     * @param healAction  Action that was executed
     * @param rootCause   Root cause description for memory enrichment
     * @param durationMs  Time taken for the heal action in milliseconds
     */
    public MemoryIndexQueueable(
        String incidentId,
        String outcome,
        String healAction,
        String rootCause,
        Integer durationMs
    ) {
        this.incidentId = incidentId;
        this.outcome    = outcome;
        this.healAction = healAction;
        this.rootCause  = rootCause;
        this.durationMs = durationMs;
    }

    public void execute(QueueableContext context) {
        try {
            String requestBody = buildPayload();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SentinelFlow_Backend/api/memory/index');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-request-id', context.getJobId());
            req.setBody(requestBody);
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                SystemLogger.logError(
                    new CalloutException('Memory index returned HTTP ' + res.getStatusCode() + ': ' + res.getBody()),
                    'MemoryIndexQueueable',
                    'execute',
                    SystemLogger.ErrorType.TRANSIENT_ERROR,
                    0,
                    null
                );
            }
        } catch (Exception ex) {
            SystemLogger.logError(
                ex,
                'MemoryIndexQueueable',
                'execute',
                SystemLogger.ErrorType.TRANSIENT_ERROR,
                0,
                null
            );
        }
    }

    private String buildPayload() {
        Map<String, Object> payload = new Map<String, Object>{
            'incidentId'  => incidentId,
            'outcome'     => outcome,
            'healAction'  => healAction,
            'rootCause'   => rootCause,
            'durationMs'  => durationMs,
            'indexedAt'   => String.valueOf(Datetime.now())
        };
        return JSON.serialize(payload);
    }
}
