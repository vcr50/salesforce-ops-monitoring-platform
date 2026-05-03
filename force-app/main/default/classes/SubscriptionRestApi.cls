/**
 * REST endpoint used by the external billing backend to synchronize Stripe state.
 *
 * Endpoint: POST /services/apexrest/subscription/update
 */
@RestResource(urlMapping='/subscription/update/*')
global with sharing class SubscriptionRestApi {
    global class UpdateRequest {
        public String orgId;
        public String plan;
        public String status;
        public Date expiryDate;
        public String stripeCustomerId;
        public String stripeSubscriptionId;
        public String eventName;
        public String billingEmail;
    }

    global class UpdateResponse {
        public Boolean success;
        public String message;
        public Id subscriptionId;

        public UpdateResponse(Boolean success, String message, Id subscriptionId) {
            this.success = success;
            this.message = message;
            this.subscriptionId = subscriptionId;
        }
    }

    @HttpPost
    global static void doPost() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');

        try {
            UpdateRequest payload = (UpdateRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                UpdateRequest.class
            );

            if (payload == null || String.isBlank(payload.orgId)) {
                response.statusCode = 400;
                response.responseBody = Blob.valueOf(JSON.serialize(new UpdateResponse(false, 'orgId is required.', null)));
                return;
            }

            Subscription__c subscription = SubscriptionService.upsertFromBilling(
                payload.orgId,
                String.isBlank(payload.plan) ? SubscriptionService.PLAN_PROFESSIONAL : payload.plan,
                String.isBlank(payload.status) ? SubscriptionService.STATUS_ACTIVE : payload.status,
                payload.expiryDate,
                payload.stripeCustomerId,
                payload.stripeSubscriptionId,
                payload.eventName,
                payload.billingEmail
            );

            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serialize(
                new UpdateResponse(true, 'Subscription synchronized.', subscription.Id)
            ));
        } catch (Exception ex) {
            response.statusCode = 500;
            response.responseBody = Blob.valueOf(JSON.serialize(new UpdateResponse(false, ex.getMessage(), null)));
        }
    }
}
