Id incId = SentinelFlowPortalController.createSimulatedIncident(
    'Auth Service 503 — Login failures spiking',
    'High',
    'Auth0 Identity Provider',
    150,
    45000 // Under 50,000! Should auto-heal!
);
System.debug('Incident created: ' + incId);
