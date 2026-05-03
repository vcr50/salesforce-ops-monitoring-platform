/**
 * Org-level subscription service for SentinelFlow AppExchange packaging.
 */
public with sharing class SubscriptionService {
    public static final String PLAN_STARTER = 'Starter';
    public static final String PLAN_PROFESSIONAL = 'Professional';
    public static final String PLAN_ENTERPRISE = 'Enterprise';
    public static final String STATUS_TRIAL = 'Trial';
    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_PAST_DUE = 'Past Due';
    public static final String STATUS_EXPIRED = 'Expired';
    public static final Integer TRIAL_DAYS = 14;
    public static final Integer STARTER_INCIDENT_LIMIT = 100;

    public class SubscriptionView {
        @AuraEnabled public Id id;
        @AuraEnabled public String orgId;
        @AuraEnabled public String plan;
        @AuraEnabled public String status;
        @AuraEnabled public Date expiryDate;
        @AuraEnabled public Integer daysRemaining;
        @AuraEnabled public Integer starterIncidentLimit;
        @AuraEnabled public Integer currentIncidentCount;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Boolean professional;
        @AuraEnabled public Boolean enterprise;
        @AuraEnabled public String upgradeUrl;
    }

    public class EntitlementException extends Exception {}

    @AuraEnabled
    public static SubscriptionView getCurrentSubscription() {
        return toView(ensureCurrentOrgSubscription());
    }

    public static Subscription__c ensureCurrentOrgSubscription() {
        String orgId = UserInfo.getOrganizationId();
        List<Subscription__c> existing = [
            SELECT Id, Org_Id__c, Plan__c, Status__c, Expiry_Date__c,
                   Stripe_Customer_Id__c, Stripe_Subscription_Id__c,
                   Last_Event__c, Last_Sync__c
            FROM Subscription__c
            WHERE Org_Id__c = :orgId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            Subscription__c current = existing[0];
            if (isExpiredTrial(current)) {
                current.Status__c = STATUS_EXPIRED;
                update current;
            }
            return current;
        }

        Subscription__c trial = new Subscription__c(
            Org_Id__c = orgId,
            Plan__c = PLAN_STARTER,
            Status__c = STATUS_TRIAL,
            Expiry_Date__c = Date.today().addDays(TRIAL_DAYS),
            Last_Event__c = 'trial.created',
            Last_Sync__c = System.now()
        );
        insert trial;
        return trial;
    }

    public static Boolean isActive() {
        return isActive(ensureCurrentOrgSubscription());
    }

    public static Boolean hasPlan(String requiredPlan) {
        return hasPlan(ensureCurrentOrgSubscription(), requiredPlan);
    }

    public static void requireProfessional(String featureName) {
        Subscription__c subscription = ensureCurrentOrgSubscription();
        if (!hasPlan(subscription, PLAN_PROFESSIONAL)) {
            throw new EntitlementException(featureName + ' requires a Professional or Enterprise subscription.');
        }
    }

    public static void requireIncidentCapacity() {
        Subscription__c subscription = ensureCurrentOrgSubscription();
        if (!isActive(subscription)) {
            throw new EntitlementException('SentinelFlow subscription is not active.');
        }

        if (subscription.Plan__c == PLAN_STARTER) {
            Integer incidentCount = [
                SELECT COUNT()
                FROM Incident__c
                WHERE CreatedDate = THIS_MONTH
            ];
            if (incidentCount >= STARTER_INCIDENT_LIMIT) {
                throw new EntitlementException('Starter plan incident limit reached.');
            }
        }
    }

    public static Subscription__c upsertFromBilling(
        String orgId,
        String plan,
        String status,
        Date expiryDate,
        String stripeCustomerId,
        String stripeSubscriptionId,
        String eventName
    ) {
        return upsertFromBilling(
            orgId,
            plan,
            status,
            expiryDate,
            stripeCustomerId,
            stripeSubscriptionId,
            eventName,
            null
        );
    }

    public static Subscription__c upsertFromBilling(
        String orgId,
        String plan,
        String status,
        Date expiryDate,
        String stripeCustomerId,
        String stripeSubscriptionId,
        String eventName,
        String billingEmail
    ) {
        validatePlan(plan);
        validateStatus(status);

        List<Subscription__c> existingSubscriptions = [
            SELECT Id, Status__c
            FROM Subscription__c
            WHERE Org_Id__c = :orgId
            LIMIT 1
        ];
        Boolean wasAlreadyActive = !existingSubscriptions.isEmpty()
            && existingSubscriptions[0].Status__c == STATUS_ACTIVE;

        Subscription__c subscription = new Subscription__c(
            Org_Id__c = orgId,
            Plan__c = plan,
            Status__c = status,
            Expiry_Date__c = expiryDate,
            Stripe_Customer_Id__c = stripeCustomerId,
            Stripe_Subscription_Id__c = stripeSubscriptionId,
            Last_Event__c = eventName,
            Last_Sync__c = System.now()
        );
        upsert subscription Org_Id__c;

        SubscriptionEmailService.sendInstallationEmailForPaidSubscription(
            orgId,
            billingEmail,
            plan,
            status,
            eventName,
            wasAlreadyActive
        );

        return [
            SELECT Id, Org_Id__c, Plan__c, Status__c, Expiry_Date__c,
                   Stripe_Customer_Id__c, Stripe_Subscription_Id__c,
                   Last_Event__c, Last_Sync__c
            FROM Subscription__c
            WHERE Org_Id__c = :orgId
            LIMIT 1
        ];
    }

    public static Integer expireTrials() {
        List<Subscription__c> expiredTrials = [
            SELECT Id, Status__c
            FROM Subscription__c
            WHERE Status__c = :STATUS_TRIAL
            AND Expiry_Date__c < :Date.today()
        ];
        for (Subscription__c subscription : expiredTrials) {
            subscription.Status__c = STATUS_EXPIRED;
            subscription.Last_Event__c = 'trial.expired';
            subscription.Last_Sync__c = System.now();
        }
        if (!expiredTrials.isEmpty()) {
            update expiredTrials;
        }
        return expiredTrials.size();
    }

    private static SubscriptionView toView(Subscription__c subscription) {
        SubscriptionView view = new SubscriptionView();
        view.id = subscription.Id;
        view.orgId = subscription.Org_Id__c;
        view.plan = subscription.Plan__c;
        view.status = subscription.Status__c;
        view.expiryDate = subscription.Expiry_Date__c;
        view.daysRemaining = subscription.Expiry_Date__c == null
            ? null
            : Date.today().daysBetween(subscription.Expiry_Date__c);
        view.starterIncidentLimit = STARTER_INCIDENT_LIMIT;
        view.currentIncidentCount = [
            SELECT COUNT()
            FROM Incident__c
            WHERE CreatedDate = THIS_MONTH
        ];
        view.active = isActive(subscription);
        view.professional = hasPlan(subscription, PLAN_PROFESSIONAL);
        view.enterprise = subscription.Plan__c == PLAN_ENTERPRISE;
        view.upgradeUrl = getUpgradeUrl(subscription.Org_Id__c);
        return view;
    }

    private static String getUpgradeUrl(String orgId) {
        String baseUrl = System.Label.SentinelFlow_Billing_Upgrade_Url;
        return baseUrl + '?orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8');
    }

    private static Boolean isActive(Subscription__c subscription) {
        if (subscription == null) {
            return false;
        }
        if (subscription.Status__c == STATUS_EXPIRED || subscription.Status__c == 'Canceled') {
            return false;
        }
        if (subscription.Expiry_Date__c != null && subscription.Expiry_Date__c < Date.today()) {
            return false;
        }
        return subscription.Status__c == STATUS_TRIAL
            || subscription.Status__c == STATUS_ACTIVE
            || subscription.Status__c == STATUS_PAST_DUE;
    }

    private static Boolean hasPlan(Subscription__c subscription, String requiredPlan) {
        if (!isActive(subscription)) {
            return false;
        }
        if (requiredPlan == PLAN_STARTER) {
            return true;
        }
        if (requiredPlan == PLAN_PROFESSIONAL) {
            return subscription.Plan__c == PLAN_PROFESSIONAL || subscription.Plan__c == PLAN_ENTERPRISE;
        }
        if (requiredPlan == PLAN_ENTERPRISE) {
            return subscription.Plan__c == PLAN_ENTERPRISE;
        }
        return false;
    }

    private static Boolean isExpiredTrial(Subscription__c subscription) {
        return subscription.Status__c == STATUS_TRIAL
            && subscription.Expiry_Date__c != null
            && subscription.Expiry_Date__c < Date.today();
    }

    private static void validatePlan(String plan) {
        if (String.isBlank(plan) || !new Set<String>{PLAN_STARTER, PLAN_PROFESSIONAL, PLAN_ENTERPRISE}.contains(plan)) {
            throw new EntitlementException('Unsupported subscription plan: ' + plan);
        }
    }

    private static void validateStatus(String status) {
        Set<String> validStatuses = new Set<String>{STATUS_TRIAL, STATUS_ACTIVE, STATUS_PAST_DUE, STATUS_EXPIRED, 'Canceled'};
        if (String.isBlank(status) || !validStatuses.contains(status)) {
            throw new EntitlementException('Unsupported subscription status: ' + status);
        }
    }
}
