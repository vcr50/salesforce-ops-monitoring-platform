Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();

// 1. AI Classification
Metadata.CustomMetadata record1 = new Metadata.CustomMetadata();
record1.fullName = 'Feature_Flag.AI_Classification';
record1.label = 'AI Classification';
Metadata.CustomMetadataValue isEnabled1 = new Metadata.CustomMetadataValue();
isEnabled1.field = 'Is_Enabled__c';
isEnabled1.value = true;
Metadata.CustomMetadataValue plan1 = new Metadata.CustomMetadataValue();
plan1.field = 'Plan__c';
plan1.value = 'Professional';
Metadata.CustomMetadataValue desc1 = new Metadata.CustomMetadataValue();
desc1.field = 'Description__c';
desc1.value = 'AI-powered incident classification and severity prediction. Requires Professional plan or higher.';
record1.values.add(isEnabled1);
record1.values.add(plan1);
record1.values.add(desc1);
mdContainer.addMetadata(record1);

// 2. Adaptive Auto Heal
Metadata.CustomMetadata record2 = new Metadata.CustomMetadata();
record2.fullName = 'Feature_Flag.Adaptive_Auto_Heal';
record2.label = 'Adaptive Auto Heal';
Metadata.CustomMetadataValue isEnabled2 = new Metadata.CustomMetadataValue();
isEnabled2.field = 'Is_Enabled__c';
isEnabled2.value = true;
Metadata.CustomMetadataValue plan2 = new Metadata.CustomMetadataValue();
plan2.field = 'Plan__c';
plan2.value = 'Enterprise';
Metadata.CustomMetadataValue desc2 = new Metadata.CustomMetadataValue();
desc2.field = 'Description__c';
desc2.value = 'Adaptive auto-healing capabilities based on historical incident data. Enterprise only.';
record2.values.add(isEnabled2);
record2.values.add(plan2);
record2.values.add(desc2);
mdContainer.addMetadata(record2);

// 3. Cross Org Intelligence
Metadata.CustomMetadata record3 = new Metadata.CustomMetadata();
record3.fullName = 'Feature_Flag.Cross_Org_Intelligence';
record3.label = 'Cross-Org Intelligence';
Metadata.CustomMetadataValue isEnabled3 = new Metadata.CustomMetadataValue();
isEnabled3.field = 'Is_Enabled__c';
isEnabled3.value = true;
Metadata.CustomMetadataValue plan3 = new Metadata.CustomMetadataValue();
plan3.field = 'Plan__c';
plan3.value = 'Enterprise';
Metadata.CustomMetadataValue desc3 = new Metadata.CustomMetadataValue();
desc3.field = 'Description__c';
desc3.value = 'Cross-org intelligence sharing and aggregated incident patterns. Enterprise only.';
record3.values.add(isEnabled3);
record3.values.add(plan3);
record3.values.add(desc3);
mdContainer.addMetadata(record3);

// 4. Executive Dashboard V2
Metadata.CustomMetadata record4 = new Metadata.CustomMetadata();
record4.fullName = 'Feature_Flag.Executive_Dashboard_V2';
record4.label = 'Executive Dashboard V2';
Metadata.CustomMetadataValue isEnabled4 = new Metadata.CustomMetadataValue();
isEnabled4.field = 'Is_Enabled__c';
isEnabled4.value = true;
Metadata.CustomMetadataValue plan4 = new Metadata.CustomMetadataValue();
plan4.field = 'Plan__c';
plan4.value = 'Professional';
Metadata.CustomMetadataValue desc4 = new Metadata.CustomMetadataValue();
desc4.field = 'Description__c';
desc4.value = 'Advanced executive reporting dashboard with real-time analytics. Professional and above.';
record4.values.add(isEnabled4);
record4.values.add(plan4);
record4.values.add(desc4);
mdContainer.addMetadata(record4);

// 5. Incident Memory
Metadata.CustomMetadata record5 = new Metadata.CustomMetadata();
record5.fullName = 'Feature_Flag.Incident_Memory';
record5.label = 'Incident Memory';
Metadata.CustomMetadataValue isEnabled5 = new Metadata.CustomMetadataValue();
isEnabled5.field = 'Is_Enabled__c';
isEnabled5.value = true;
Metadata.CustomMetadataValue plan5 = new Metadata.CustomMetadataValue();
plan5.field = 'Plan__c';
plan5.value = 'Starter';
Metadata.CustomMetadataValue desc5 = new Metadata.CustomMetadataValue();
desc5.field = 'Description__c';
desc5.value = 'Basic incident memory and historical context retention. Available on Starter plan and higher.';
record5.values.add(isEnabled5);
record5.values.add(plan5);
record5.values.add(desc5);
mdContainer.addMetadata(record5);

// 6. Prediction Engine
Metadata.CustomMetadata record6 = new Metadata.CustomMetadata();
record6.fullName = 'Feature_Flag.Prediction_Engine';
record6.label = 'Prediction Engine';
Metadata.CustomMetadataValue isEnabled6 = new Metadata.CustomMetadataValue();
isEnabled6.field = 'Is_Enabled__c';
isEnabled6.value = true;
Metadata.CustomMetadataValue plan6 = new Metadata.CustomMetadataValue();
plan6.field = 'Plan__c';
plan6.value = 'Enterprise';
Metadata.CustomMetadataValue desc6 = new Metadata.CustomMetadataValue();
desc6.field = 'Description__c';
desc6.value = 'Proactive anomaly detection and failure prediction engine. Enterprise plan required.';
record6.values.add(isEnabled6);
record6.values.add(plan6);
record6.values.add(desc6);
mdContainer.addMetadata(record6);

// 7. Reliability Simulator
Metadata.CustomMetadata record7 = new Metadata.CustomMetadata();
record7.fullName = 'Feature_Flag.Reliability_Simulator';
record7.label = 'Reliability Simulator';
Metadata.CustomMetadataValue isEnabled7 = new Metadata.CustomMetadataValue();
isEnabled7.field = 'Is_Enabled__c';
isEnabled7.value = true;
Metadata.CustomMetadataValue plan7 = new Metadata.CustomMetadataValue();
plan7.field = 'Plan__c';
plan7.value = 'Professional';
Metadata.CustomMetadataValue desc7 = new Metadata.CustomMetadataValue();
desc7.field = 'Description__c';
desc7.value = 'Chaos engineering and reliability simulation tool. Requires Professional plan or higher.';
record7.values.add(isEnabled7);
record7.values.add(plan7);
record7.values.add(desc7);
mdContainer.addMetadata(record7);


Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
System.debug('Enqueued job id: ' + jobId);
