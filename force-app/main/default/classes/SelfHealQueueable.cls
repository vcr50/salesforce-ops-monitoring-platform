/**
 * SelfHealQueueable
 * Wraps SelfHealingEngine.processFailedLogs in a Queueable so it can safely
 * perform DML and future callouts outside the trigger transaction.
 * Now bulkified.
 *
 * @author   Tomcodex
 */
public class SelfHealQueueable implements Queueable {

    private final List<Id> integrationLogIds;

    public SelfHealQueueable(Id logId) {
        this.integrationLogIds = new List<Id>{logId};
    }

    public SelfHealQueueable(List<Id> logIds) {
        this.integrationLogIds = logIds;
    }

    public void execute(QueueableContext context) {
        SelfHealingEngine.processFailedLogs(integrationLogIds);
    }
}
