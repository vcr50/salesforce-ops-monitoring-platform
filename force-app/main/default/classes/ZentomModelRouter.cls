public with sharing class ZentomModelRouter {
    public enum AIModel {
        DEEPSEEK_R1,     // 45% - Primary Reasoning
        AGENTFORCE,      // 20% - Salesforce Native
        LLAMA_3,         // 10% - Local Inference
        DEEPSEEK_CODER   // 10% - Code Analysis
    }

    /**
     * Routes the incident to the appropriate AI model.
     */
    public static AIModel route(ZentomContextEngine.ContextPacket context, ZentomRiskEngine.RiskScore risk, String taskType) {
        // Task Type logic
        if (taskType == 'CODE_ANALYSIS') {
            return AIModel.DEEPSEEK_CODER;
        }
        if (taskType == 'SALESFORCE_RECORD_UPDATE') {
            return AIModel.AGENTFORCE;
        }
        
        // Risk & Business Impact logic
        if (risk.totalScore > 70.0 || context.accountARR >= 50000) {
            // High risk or high ARR warrants deep reasoning model
            return AIModel.DEEPSEEK_R1;
        }
        
        // Default to low latency model for triage
        return AIModel.LLAMA_3;
    }
}

