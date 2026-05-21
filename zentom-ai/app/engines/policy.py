from app.models.schemas import PolicyEvaluation, ExecutionMode

def evaluate_action(proposed_action: str, risk_score: float, workflow_stage: str) -> PolicyEvaluation:
    """
    Evaluates a proposed AI action against enterprise safety policies.
    High-risk actions ALWAYS require approval.
    Mirrors ZentomPolicyEngine.cls
    """
    action_lower = proposed_action.lower()
    
    # 1. Hardcoded Policy Blocks
    if "delete" in action_lower or "drop" in action_lower:
        return PolicyEvaluation(
            mode=ExecutionMode.BLOCKED_BY_POLICY,
            policyReasoning="Destructive actions are strictly prohibited by SentinelFlow Policy.",
            requiresApproval=False
        )

    # 2. High Risk / Financial Workflows
    if workflow_stage in ["Payment", "ERP"] or "refund" in action_lower:
        return PolicyEvaluation(
            mode=ExecutionMode.HUMAN_APPROVAL_REQUIRED,
            policyReasoning="Financial workflows and payment adjustments require explicit human approval.",
            requiresApproval=True
        )

    # 3. Risk Threshold Evaluation
    if risk_score > 75.0:
        return PolicyEvaluation(
            mode=ExecutionMode.HUMAN_APPROVAL_REQUIRED,
            policyReasoning=f"Risk score ({risk_score}) exceeds the autonomous threshold (75.0). Human review required.",
            requiresApproval=True
        )

    # 4. Safe Autonomous Execution
    return PolicyEvaluation(
        mode=ExecutionMode.AUTONOMOUS_EXECUTION,
        policyReasoning="Action passed all governance checks and is within safe operational thresholds.",
        requiresApproval=False
    )
