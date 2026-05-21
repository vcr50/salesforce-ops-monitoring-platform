from app.models.schemas import ContextPacket, RiskScore, AIModel

def route(context: ContextPacket, risk: RiskScore, task_type: str) -> AIModel:
    """
    Routes the incident to the appropriate AI model.
    Mirrors ZentomModelRouter.cls
    """
    # Task Type logic
    if task_type == 'CODE_ANALYSIS':
        return AIModel.DEEPSEEK_CODER
    if task_type == 'SALESFORCE_RECORD_UPDATE':
        return AIModel.AGENTFORCE
        
    # Risk & Business Impact logic
    if risk.totalScore > 70.0 or context.accountARR >= 50000:
        # High risk or high ARR warrants deep reasoning model
        return AIModel.DEEPSEEK_R1
        
    # Default to low latency model for triage
    return AIModel.LLAMA_3
