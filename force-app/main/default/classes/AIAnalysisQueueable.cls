/**
 * AIAnalysisQueueable
 * Asynchronous processor for AI incident analysis with Bulkification,
 * Intelligent Retry Classification, and Feature Flags.
 *
 * @author  Tomcodex
 * @version 4.0 (Enterprise Polish)
 */
public with sharing class AIAnalysisQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> incidentIds;
    private Integer retryCount;

    public AIAnalysisQueueable(Id incidentId) {
        this.incidentIds = new List<Id>{ incidentId };
        this.retryCount  = 0;
    }

    public AIAnalysisQueueable(List<Id> incidentIds) {
        this.incidentIds = incidentIds;
        this.retryCount  = 0;
    }
    
    public AIAnalysisQueueable(List<Id> incidentIds, Integer retryCount) {
        this.incidentIds = incidentIds;
        this.retryCount  = retryCount;
    }

    public void execute(QueueableContext ctx) {
        if (incidentIds == null || incidentIds.isEmpty()) return;

        // Feature Flag Check: Skip entire execution if AI is disabled
        if (!FeatureFlag.isEnabled('AI_ANALYSIS')) {
            return;
        }

        List<Id> autoHealIds = new List<Id>();

        try {
            // Set Status = Analyzing (ONLY this class sets this status)
            List<Incident__c> toAnalyze = new List<Incident__c>();
            for (Id incId : incidentIds) {
                toAnalyze.add(new Incident__c(Id = incId, Status__c = 'Analyzing'));
            }
            update toAnalyze;

            for (Id incidentId : incidentIds) {
                AIAnalysisService.AnalysisResult result = AIAnalysisService.analyseIncident(incidentId);

                if (result.confidence != null && result.confidence >= 90.0) {
                    autoHealIds.add(incidentId);
                }
            }

            if (!autoHealIds.isEmpty() && FeatureFlag.isEnabled('AUTO_HEAL') && !Test.isRunningTest()) {
                System.enqueueJob(new AutoHealQueueable(autoHealIds));
            }

        } catch (Exception ex) {
            handleException(ex);
        }
    }

    private void handleException(Exception ex) {
        String exType = ex.getTypeName();
        SystemLogger.ErrorType errorClassification = SystemLogger.ErrorType.PERMANENT_ERROR;
        Boolean isTransient = false;

        // Intelligent Classification
        if (exType.contains('CalloutException') || exType.contains('Timeout') || exType.contains('LockException')) {
            isTransient = true;
            errorClassification = SystemLogger.ErrorType.TRANSIENT_ERROR;
        }

        Integer maxRetries = SystemSettings.getInt('RETRY_LIMIT', 2);

        if (isTransient && retryCount < maxRetries) {
            // Transient error: Retry
            SystemLogger.logError(ex, 'AIAnalysisQueueable', 'execute', errorClassification, retryCount, null);
            if (!Test.isRunningTest()) {
                System.enqueueJob(new AIAnalysisQueueable(incidentIds, retryCount + 1));
            }
        } else {
            // Permanent error or max retries exhausted: Dead-letter
            if (!isTransient) {
                errorClassification = SystemLogger.ErrorType.PERMANENT_ERROR;
            }
            SystemLogger.logError(ex, 'AIAnalysisQueueable', 'execute', errorClassification, retryCount, null);
        }
    }
}
