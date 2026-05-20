/**
 * BusinessImpactCalculator
 * Computes estimated revenue loss and risk level for each open incident.
 *
 * Formula:  Revenue Loss = Users Affected × Average Revenue Per User
 * Risk bands:
 *   Critical  → loss > $50,000
 *   High      → $10,000 < loss ≤ $50,000
 *   Medium    → $1,000  < loss ≤ $10,000
 *   Low       →           loss ≤ $1,000
 *
 * @author   Tomcodex
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class BusinessImpactCalculator {

    private static final Decimal THRESHOLD_CRITICAL = 50000;
    private static final Decimal THRESHOLD_HIGH     = 10000;
    private static final Decimal THRESHOLD_MEDIUM   = 1000;

    private static final Map<String, Decimal> DEFAULT_ARPU = new Map<String, Decimal>{
        'Critical' => 40.00, 'High' => 30.00, 'Medium' => 20.00, 'Low' => 10.00
    };

    public class ImpactResult {
        @AuraEnabled public Decimal revenueAtRisk;
        @AuraEnabled public String  riskLevel;
        @AuraEnabled public String  summary;
        @AuraEnabled public Integer usersAffected;
        @AuraEnabled public Decimal arpu;
    }

    public static ImpactResult calculate(Integer usersAffected, Decimal arpu, String incidentType) {
        if (usersAffected == null || usersAffected < 0) { usersAffected = 0; }
        if (arpu == null || arpu < 0)                   { arpu = 0; }

        ImpactResult r   = new ImpactResult();
        r.usersAffected  = usersAffected;
        r.arpu           = arpu;
        r.revenueAtRisk  = usersAffected * arpu;
        r.riskLevel      = classifyRisk(r.revenueAtRisk);
        r.summary        = (usersAffected + ' users impacted across '
                           + (String.isBlank(incidentType) ? 'this incident' : incidentType)
                           + ', estimated $' + r.revenueAtRisk.setScale(0).toPlainString()
                           + ' revenue at risk — ' + r.riskLevel + ' priority.');
        return r;
    }

    @AuraEnabled
    public static ImpactResult calculateForIncident(Id incidentId, Decimal arpu) {
        if (incidentId == null) {
            throw new ImpactCalculationException('Incident Id must not be null.');
        }
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Severity__c', 'Users_Affected__c', 'Description__c'
        });
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
            'Revenue_at_Risk__c', 'AI_Impact_Level__c', 'Users_Affected__c'
        });
        Incident__c inc = [
            SELECT Id, Severity__c, Users_Affected__c, Description__c
            FROM   Incident__c WHERE Id = :incidentId LIMIT 1
        ];
        Decimal resolvedArpu = (arpu != null && arpu > 0) ? arpu
            : (DEFAULT_ARPU.containsKey(inc.Severity__c) ? DEFAULT_ARPU.get(inc.Severity__c) : 20.00);
        Integer users = inc.Users_Affected__c != null
            ? Integer.valueOf(inc.Users_Affected__c)
            : estimateUsers(inc.Severity__c);

        ImpactResult r = calculate(users, resolvedArpu, inc.Description__c);

        inc.Revenue_at_Risk__c = r.revenueAtRisk;
        inc.AI_Impact_Level__c = r.riskLevel;
        if (inc.Users_Affected__c == null) { inc.Users_Affected__c = users; }
        update inc;

        AuditTrailService.log(incidentId, 'Incident__c', 'Business Impact Calculated', null, r.summary);
        return r;
    }

    @AuraEnabled
    public static List<ImpactResult> calculateAllOpen() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Severity__c', 'Users_Affected__c', 'Description__c'
        });
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
            'Revenue_at_Risk__c', 'AI_Impact_Level__c', 'Users_Affected__c'
        });
        List<Incident__c> incidents = [
            SELECT Id, Severity__c, Users_Affected__c, Description__c
            FROM   Incident__c
            WHERE  Status__c NOT IN ('Resolved', 'Closed')
            WITH USER_MODE
            ORDER BY Severity__c ASC LIMIT 200
        ];
        List<ImpactResult> results  = new List<ImpactResult>();
        List<Incident__c>  toUpdate = new List<Incident__c>();
        for (Incident__c inc : incidents) {
            Decimal arpu  = DEFAULT_ARPU.containsKey(inc.Severity__c) ? DEFAULT_ARPU.get(inc.Severity__c) : 20.00;
            Integer users = inc.Users_Affected__c != null ? Integer.valueOf(inc.Users_Affected__c) : estimateUsers(inc.Severity__c);
            ImpactResult r = calculate(users, arpu, inc.Description__c);
            results.add(r);
            if (canUpdateIncidentImpact()) {
                inc.Revenue_at_Risk__c = r.revenueAtRisk;
                inc.AI_Impact_Level__c = r.riskLevel;
                if (inc.Users_Affected__c == null) { inc.Users_Affected__c = users; }
                toUpdate.add(inc);
            }
        }
        if (!toUpdate.isEmpty()) {
            try {
                update as user toUpdate;
            } catch (Exception ignored) {
                // Keep the dashboard read path alive even when impact persistence is blocked.
            }
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<ImpactResult> getOpenImpact() {
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Status__c', 'Severity__c', 'Users_Affected__c',
            'Description__c', 'Revenue_at_Risk__c', 'AI_Impact_Level__c'
        });

        List<ImpactResult> results = new List<ImpactResult>();
        for (Incident__c inc : [
            SELECT Id, Severity__c, Users_Affected__c, Description__c,
                   Revenue_at_Risk__c, AI_Impact_Level__c
            FROM   Incident__c
            WHERE  Status__c NOT IN ('Resolved', 'Closed')
            WITH USER_MODE
            ORDER BY Severity__c ASC, CreatedDate DESC
            LIMIT 200
        ]) {
            Decimal arpu = DEFAULT_ARPU.containsKey(inc.Severity__c)
                ? DEFAULT_ARPU.get(inc.Severity__c)
                : 20.00;
            Integer users = inc.Users_Affected__c != null
                ? Integer.valueOf(inc.Users_Affected__c)
                : estimateUsers(inc.Severity__c);
            ImpactResult result = calculate(users, arpu, inc.Description__c);
            if (inc.Revenue_at_Risk__c != null) {
                result.revenueAtRisk = inc.Revenue_at_Risk__c;
                result.riskLevel = classifyRisk(inc.Revenue_at_Risk__c);
                result.summary = users + ' users impacted across '
                    + (String.isBlank(inc.Description__c) ? 'this incident' : inc.Description__c)
                    + ', recorded $' + inc.Revenue_at_Risk__c.setScale(0).toPlainString()
                    + ' revenue at risk - ' + result.riskLevel + ' priority.';
            }
            if (!String.isBlank(inc.AI_Impact_Level__c)) {
                result.riskLevel = inc.AI_Impact_Level__c;
            }
            results.add(result);
        }
        return results;
    }

    private static String classifyRisk(Decimal loss) {
        if (loss > THRESHOLD_CRITICAL) return 'Critical';
        if (loss > THRESHOLD_HIGH)     return 'High';
        if (loss > THRESHOLD_MEDIUM)   return 'Medium';
        return 'Low';
    }

    private static Integer estimateUsers(String severity) {
        if (severity == 'Critical') return 1000;
        if (severity == 'High')     return 500;
        if (severity == 'Medium')   return 100;
        return 25;
    }

    private static Boolean canUpdateIncidentImpact() {
        return SecurityGate.isUpdateable('Incident__c')
            && fieldUpdateable('Incident__c', 'Revenue_at_Risk__c')
            && fieldUpdateable('Incident__c', 'AI_Impact_Level__c')
            && fieldUpdateable('Incident__c', 'Users_Affected__c');
    }

    private static Boolean fieldUpdateable(String objectApiName, String fieldApiName) {
        Map<String, Schema.SObjectField> fields =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        return fields.containsKey(fieldApiName)
            && fields.get(fieldApiName).getDescribe().isUpdateable();
    }

    public class ImpactCalculationException extends Exception {}
}

