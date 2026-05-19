// Generate a high-risk dummy incident for Zentom AI to analyze and heal
Incident__c inc = new Incident__c();
inc.Description__c = 'Stripe API is returning 504 Gateway Timeout errors repeatedly. All checkout flows in US-East region are currently failing. Latency spiked to 8000ms.';
inc.Status__c = 'Open';
inc.Severity__c = 'Critical';


// Add a large random revenue risk to trigger the Gate 3 logic (> $50k requires human approval)
// or sometimes keep it low to allow auto-healing
Decimal randomRisk = Math.random();
if (randomRisk > 0.5) {
    inc.Revenue_at_Risk__c = 150000; // $150k - Should BLOCK auto-heal
} else {
    inc.Revenue_at_Risk__c = 12000;  // $12k - Should ALLOW auto-heal
}

insert inc;
System.debug('Generated Incident ID: ' + inc.Id + ' with Revenue Risk: $' + inc.Revenue_at_Risk__c);
