public with sharing class ZentomExecutionController {
    /**
     * Final gate authorized to initiate real-world actions via Agentforce after policy clearance.
     */
    public static void executeAction(Id incidentId, String action, Decimal confidence, ZentomRiskEngine.RiskScore risk, ZentomPolicyEngine.ExecutionMode mode) {
        // 1. Pre-execution Checks & Circuit Breakers
        if (confidence < 80.0) {
            throw new AuraHandledException('Confidence too low (' + confidence + ') for autonomous execution. Blocked at final gate.');
        }

        if (mode != ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION) {
            throw new AuraHandledException('Execution blocked. Policy Mode is: ' + mode.name());
        }

        // 2. Step Verification & Sequencing
        System.debug('ZentomExecutionController: Pre-execution checks passed for ' + action);

        // 3. Dispatch to Agentforce Native Execution
        ZentomAgentforceRouter.ExecutionRequest req = new ZentomAgentforceRouter.ExecutionRequest();
        req.incidentId = incidentId;
        req.proposedAction = action;

        List<ZentomAgentforceRouter.ExecutionRequest> requests = new List<ZentomAgentforceRouter.ExecutionRequest>{req};
        ZentomAgentforceRouter.executeAction(requests);
    }
}

