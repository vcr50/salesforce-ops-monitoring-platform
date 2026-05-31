Id incId = SentinelFlowPortalController.createSimulatedIncident(
    'Payment API Timeout — Stripe gateway latency spike detected across EU region',
    'Critical',
    'Stripe Payment Gateway',
    8420,
    312000
);
System.debug('Incident created: ' + incId);
