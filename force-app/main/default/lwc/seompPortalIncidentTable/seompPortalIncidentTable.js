import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOpenIncidents from '@salesforce/apex/SEOMPPortalController.getOpenIncidents';

const COLUMNS = [
    { label: 'Incident', fieldName: 'name', sortable: true },
    { label: 'Severity', fieldName: 'severity', sortable: true },
    { label: 'Status', fieldName: 'status', sortable: true },
    {
        type: 'button',
        fixedWidth: 140,
        typeAttributes: {
            label: 'View detail',
            name: 'view_detail',
            variant: 'base'
        }
    }
];

export default class SeompPortalIncidentTable extends NavigationMixin(LightningElement) {
    @api detailPagePath = 'incident-detail';
    columns = COLUMNS;
    rows = [];
    error;
    sortedBy = 'severity';
    sortDirection = 'desc';

    @wire(getOpenIncidents)
    wiredIncidents({ error, data }) {
        if (data) {
            this.rows = this.sortData(data, this.sortedBy, this.sortDirection);
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = 'Unable to load live incident data.';
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get rowCount() {
        return this.rows.length;
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.rows = this.sortData(this.rows, this.sortedBy, this.sortDirection);
    }

    handleRowAction(event) {
        const row = event.detail.row;
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
        return [...data].sort((left, right) => {
            const leftValue = left[fieldName] ?? '';
            const rightValue = right[fieldName] ?? '';
            return leftValue > rightValue ? direction : leftValue < rightValue ? -direction : 0;
        });
    }

    getCommunityBasePath() {
        const marker = '/s/';
        const currentPath = window.location.pathname;
        const markerIndex = currentPath.indexOf(marker);
        return markerIndex >= 0
            ? currentPath.substring(0, markerIndex + marker.length)
            : '/';
    }
}
