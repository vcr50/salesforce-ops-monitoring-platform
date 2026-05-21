from app.models.schemas import ContextPacket, RiskScore

def evaluate_risk(incident_id: str, context: ContextPacket) -> RiskScore:
    """
    Quantifies the danger of an action based on four dimensions.
    Mirrors ZentomRiskEngine.cls
    """
    # Technical Severity: Error class and depth in the stack
    technical_severity = 20.0
    
    # Business Impact: Account ARR and tier from Salesforce
    business_impact = 35.0 if context.accountARR > 100000 else 10.0
    
    # Blast Radius: Estimation of potential systemic damage
    blast_radius = 15.0
    
    # Operational Context: Environmental signals
    operational_context = 10.0
    
    total_score = technical_severity + business_impact + blast_radius + operational_context
    
    return RiskScore(
        totalScore=total_score,
        technicalSeverity=technical_severity,
        businessImpact=business_impact,
        blastRadius=blast_radius,
        operationalContext=operational_context
    )
