public with sharing class SubscriptionEmailService {
    @TestVisible private static Integer installationEmailSendAttempts = 0;

    public static void sendInstallationEmailForPaidSubscription(
        String orgId,
        String billingEmail,
        String plan,
        String status,
        String eventName,
        Boolean wasAlreadyActive
    ) {
        String email = String.isBlank(billingEmail) ? getEmailFromWebLeadOrgId(orgId) : billingEmail.trim();
        if (String.isBlank(email) || status != SubscriptionService.STATUS_ACTIVE || wasAlreadyActive) {
            return;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String>{ email });
        message.setSubject('SentinelFlow ' + plan + ' payment confirmed - install your Salesforce package');
        message.setHtmlBody(buildInstallationBody(plan, eventName));
        message.setSaveAsActivity(false);
        installationEmailSendAttempts++;
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
    }

    @TestVisible
    private static String getEmailFromWebLeadOrgId(String orgId) {
        if (String.isBlank(orgId) || !orgId.startsWith('web-lead:')) {
            return null;
        }

        String email = orgId.substring('web-lead:'.length()).trim();
        return String.isBlank(email) || !email.contains('@') ? null : email;
    }

    private static String buildInstallationBody(String plan, String eventName) {
        String selectedPlan = String.isBlank(plan) ? SubscriptionService.PLAN_PROFESSIONAL : plan;
        String amountText = getPlanAmountText(selectedPlan);
        String packageInstallUrl = System.Label.SentinelFlow_Package_Install_Url;
        String contactUrl = System.Label.SentinelFlow_Contact_Url;
        String termsUrl = System.Label.SentinelFlow_Terms_Url;
        String supportEmail = System.Label.SentinelFlow_Support_Email;

        return ''
            + '<html><body style="font-family:Arial,sans-serif;color:#111827;line-height:1.6;">'
            + '<h1>Payment confirmed</h1>'
            + '<p>Thank you for subscribing to SentinelFlow ' + escapeHtml(selectedPlan) + '.</p>'
            + '<p><strong>Plan:</strong> ' + escapeHtml(selectedPlan) + '<br/>'
            + '<strong>Paid amount:</strong> ' + escapeHtml(amountText) + '<br/>'
            + '<strong>Payment event:</strong> ' + escapeHtml(eventName) + '</p>'
            + '<h2>Install the Salesforce package</h2>'
            + '<p>Use this package installation link to install SentinelFlow in your Salesforce org:</p>'
            + '<p><a href="' + escapeHtml(packageInstallUrl) + '">' + escapeHtml(packageInstallUrl) + '</a></p>'
            + '<h2>Next steps</h2>'
            + '<ol>'
            + '<li>Open the package installation link.</li>'
            + '<li>Log in to the Salesforce org where you want SentinelFlow installed.</li>'
            + '<li>Install for admins first, then assign SentinelFlow permission sets to users.</li>'
            + '<li>Open SentinelFlow and connect your billing subscription when prompted.</li>'
            + '</ol>'
            + '<p>Need help? Contact <a href="mailto:' + escapeHtml(supportEmail) + '">' + escapeHtml(supportEmail) + '</a> or visit <a href="' + escapeHtml(contactUrl) + '">Contact</a>.</p>'
            + '<p>Terms and conditions: <a href="' + escapeHtml(termsUrl) + '">' + escapeHtml(termsUrl) + '</a></p>'
            + '</body></html>';
    }

    private static String getPlanAmountText(String plan) {
        if (plan == SubscriptionService.PLAN_PROFESSIONAL) {
            return '$29/month';
        }
        if (plan == SubscriptionService.PLAN_ENTERPRISE) {
            return 'Custom enterprise amount';
        }
        return 'Free';
    }

    private static String escapeHtml(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }
}
