import { LightningElement, api } from 'lwc';

export default class SeompPortalSummary extends LightningElement {
    @api criticalIncidents = 0;
    @api openIncidents = 0;
    @api failedIntegrations = 0;
    @api warningIntegrations = 0;
}
