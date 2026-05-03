import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActiveIntegrations from '@salesforce/apex/SentinelFlowPortalController.getActiveIntegrations';

export default class SentinelFlowPortalIntegrationTable extends NavigationMixin(LightningElement) {
    @api detailPagePath = 'integration-detail';
    rows = [];
    error;
    sortedBy = 'status';
    sortDirection = 'desc';

    @wire(getActiveIntegrations)
    wiredIntegrations({ error, data }) {
        if (data) {
            this.rows = this.sortData(data, this.sortedBy, this.sortDirection);
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = 'Unable to load live integration data.';
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get rowCount() {
        return this.rows.length;
    }

    handleHeaderSort(event) {
        const fieldName = event.currentTarget.dataset.field;
        this.sortDirection =
            this.sortedBy === fieldName && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortedBy = fieldName;
        this.rows = this.sortData(this.rows, this.sortedBy, this.sortDirection);
    }

    handleViewDetail(event) {
        const row = this.rows.find((item) => item.id === event.currentTarget.dataset.id);
        if (!row) {
            return;
        }

        const basePath = this.getCommunityBasePath();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `${basePath}${this.detailPagePath}?c__recordId=${row.id}`
            }
        });
    }

    sortData(data, fieldName, sortDirection) {
        const direction = sortDirection === 'asc' ? 1 : -1;
        return [...data]
            .sort((left, right) => {
            const leftValue = left[fieldName] ?? '';
            const rightValue = right[fieldName] ?? '';
            return leftValue > rightValue ? direction : leftValue < rightValue ? -direction : 0;
        })
            .map((row) => ({
                ...row,
                statusClass: this.getStatusClass(row.status),
                responseTimeLabel: this.formatResponseTime(row.responseTime)
            }));
    }

    getCommunityBasePath() {
        const marker = '/s/';
        const currentPath = window.location.pathname;
        const markerIndex = currentPath.indexOf(marker);
        return markerIndex >= 0
            ? currentPath.substring(0, markerIndex + marker.length)
            : '/';
    }

    getStatusClass(status) {
        const normalized = (status || '').toLowerCase();
        if (normalized === 'failed') {
            return 'pill status-failed';
        }

        if (normalized === 'warning') {
            return 'pill status-warning';
        }

        if (normalized === 'success') {
            return 'pill status-success';
        }

        return 'pill status-default';
    }

    formatResponseTime(value) {
        return value ? `${value} ms` : 'N/A';
    }
}
