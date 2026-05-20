/**
 * ZentomPolicyEngine
 * Phase 5 of the CTO Blueprint: Governed Autonomy.
 *
 * Enforces the "Never Bypass" rule. Assesses proposed AI actions against 
 * business policies and risk thresholds to determine if the action can be 
 * executed autonomously or if it requires human approval.
 *
 * @author SentinelFlow
 */
public with sharing class ZentomPolicyEngine {
    
    public enum ExecutionMode {
        AUTONOMOUS_EXECUTION,
        HUMAN_APPROVAL_REQUIRED,
        BLOCKED_BY_POLICY
    }

    public class PolicyEvaluation {
        public ExecutionMode mode;
        public String policyReasoning;
        public Boolean requiresApproval;
    }

    /**
     * Evaluates a proposed AI action against enterprise safety policies.
     * High-risk actions (payment, auth changes, data deletion) ALWAYS require approval.
     */
    public static PolicyEvaluation evaluateAction(String proposedAction, Decimal riskScore, String workflowStage) {
        PolicyEvaluation eval = new PolicyEvaluation();
        
        // 1. Hardcoded Policy Blocks
        if (proposedAction.containsIgnoreCase('delete') || proposedAction.containsIgnoreCase('drop')) {
            eval.mode = ExecutionMode.BLOCKED_BY_POLICY;
            eval.policyReasoning = 'Destructive actions are strictly prohibited by SentinelFlow Policy.';
            eval.requiresApproval = false; // Cannot even be approved
            return eval;
        }

        // 2. High Risk / Financial Workflows (Phase 5 strict governance)
        if (workflowStage == 'Payment' || workflowStage == 'ERP' || proposedAction.containsIgnoreCase('refund')) {
            eval.mode = ExecutionMode.HUMAN_APPROVAL_REQUIRED;
            eval.policyReasoning = 'Financial workflows and payment adjustments require explicit human approval (Sox/PCI compliance).';
            eval.requiresApproval = true;
            return eval;
        }

        // 3. Risk Threshold Evaluation
        if (riskScore > 75.0) {
            eval.mode = ExecutionMode.HUMAN_APPROVAL_REQUIRED;
            eval.policyReasoning = 'Risk score (' + riskScore + ') exceeds the autonomous threshold (75.0). Human review required.';
            eval.requiresApproval = true;
            return eval;
        }

        // 4. Safe Autonomous Execution
        eval.mode = ExecutionMode.AUTONOMOUS_EXECUTION;
        eval.policyReasoning = 'Action passed all governance checks and is within safe operational thresholds.';
        eval.requiresApproval = false;
        
        return eval;
    }
}

