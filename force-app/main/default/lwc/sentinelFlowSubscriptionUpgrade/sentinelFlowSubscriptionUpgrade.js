import { LightningElement, track } from 'lwc';
import getCurrentSubscription from '@salesforce/apex/SubscriptionService.getCurrentSubscription';

export default class SentinelFlowSubscriptionUpgrade extends LightningElement {
    @track subscription;
    @track loading = true;
    @track error;

    connectedCallback() {
        this.refresh();
    }

    async refresh() {
        this.loading = true;
        this.error = null;
        try {
            this.subscription = await getCurrentSubscription();
        } catch (e) {
            this.error = e?.body?.message || 'Unable to load subscription.';
        } finally {
            this.loading = false;
        }
    }

    handleUpgrade() {
        if (this.subscription?.upgradeUrl) {
            window.location.assign(this.subscription.upgradeUrl);
        }
    }

    get plan() {
        return this.subscription?.plan || 'Starter';
    }

    get status() {
        return this.subscription?.status || 'Trial';
    }

    get orgId() {
        return this.subscription?.orgId || '';
    }

    get expiryText() {
        if (!this.subscription?.expiryDate) {
            return 'No expiry';
        }
        return this.subscription.expiryDate;
    }

    get incidentUsage() {
        if (!this.subscription) {
            return '--';
        }
        if (this.subscription.professional || this.subscription.enterprise) {
            return `${this.subscription.currentIncidentCount} / Unlimited`;
        }
        return `${this.subscription.currentIncidentCount} / ${this.subscription.starterIncidentLimit}`;
    }

    get statusText() {
        if (!this.subscription) {
            return '';
        }
        if (this.subscription.active && this.subscription.daysRemaining !== null) {
            return `${this.subscription.daysRemaining} days remaining`;
        }
        if (this.subscription.active) {
            return 'Active entitlement';
        }
        return 'Subscription required';
    }

    get statusClass() {
        const active = this.subscription?.active;
        return `status-pill ${active ? 'active' : 'blocked'}`;
    }

    get upgradeLabel() {
        return this.subscription?.professional ? 'Manage Billing' : 'Upgrade';
    }

    get upgradeDisabled() {
        return !this.subscription?.upgradeUrl;
    }
}
