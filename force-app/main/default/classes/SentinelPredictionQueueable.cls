public with sharing class SentinelPredictionQueueable implements Queueable {
    private List<Sentinel_Anomaly_Signal__c> signals;
    
    public SentinelPredictionQueueable(List<Sentinel_Anomaly_Signal__c> signals) {
        this.signals = signals;
    }
    
    public void execute(QueueableContext context) {
        try {
            SentinelPredictionEngine.processSignals(this.signals);
        } catch (Exception e) {
            System.debug('Prediction Engine Error: ' + e.getMessage());
            // Safe fallback: Do not crash asynchronous thread
        }
    }
}
