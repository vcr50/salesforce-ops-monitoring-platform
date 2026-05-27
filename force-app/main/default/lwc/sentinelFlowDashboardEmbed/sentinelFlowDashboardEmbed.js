import { LightningElement, api } from 'lwc';

export default class SentinelFlowDashboardEmbed extends LightningElement {
    @api customUrl;

    get iframeUrl() {
        return this.customUrl || '/SentinelFlow/apex/SentinelFlowDashboard';
    }
}
