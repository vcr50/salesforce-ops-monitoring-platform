import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getOpenIncidents from '@salesforce/apex/SentinelFlowPortalController.getOpenIncidents';
import healIncident    from '@salesforce/apex/SentinelFlowPortalController.healIncident';
import analyseIncident from '@salesforce/apex/SentinelFlowPortalController.analyseIncident';
import getCurrencyConfig from '@salesforce/apex/SettingsController.getCurrencyConfig';

export default class SentinelFlowPortalIncidentTable extends NavigationMixin(LightningElement) {

    @api detailPagePath = 'incident-detail';

    @track rows          = [];
    @track activeDrawerId = null;
    @track drawerRow      = null;
    @track isHealing      = false;
    @track isAnalysing    = false;

    error;
    sortedBy      = 'severity';
    sortDirection = 'desc';
    searchTerm    = '';
    severityFilter = 'all';

    _subscription;
    rawData = [];

    @track currencySymbol = '$';
    @track currencyRate = 1.0;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._fetchData();
        subscribe('/event/Integration_Health_Event__e', -1, () => {
            this._fetchData();
        }).then(sub => { this._subscription = sub; })
          .catch(err => { console.warn('empApi subscribe failed:', err); });
        this._loadCurrency();
    }

    _loadCurrency() {
        getCurrencyConfig()
            .then(config => {
                if (config) {
                    this.currencySymbol = config.symbol || '$';
                    this.currencyRate = config.rate || 1.0;
                    if (this.rawData && this.rawData.length > 0) {
                        this.rows = this._processRows(this.rawData);
                    }
                }
            })
            .catch(err => {
                console.error('Error loading currency config:', err);
            });
    }

    disconnectedCallback() {
        if (this._subscription) unsubscribe(this._subscription, () => {});
    }

    _fetchData() {
        getOpenIncidents()
            .then(data => {
                this.rawData = data;
                this.rows  = this._processRows(data);
                this.error = undefined;
            })
            .catch(err => {
                this.rows  = [];
                this.rawData = [];
                this.error = 'Unable to load live incident data.';
                console.error('Incidents fetch error', err);
            });
    }


    // ── Computed ──────────────────────────────────────────────────────────────
    get hasRows()    { return this.filteredRows.length > 0; }
    get rowCount()   { return this.filteredRows.length; }
    get drawerOpen() { return this.activeDrawerId !== null; }

    get filteredRows() {
        let data = this.rows;
        if (this.severityFilter !== 'all') {
            data = data.filter(r => r.severity === this.severityFilter);
        }
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            data = data.filter(r =>
                (r.name        || '').toLowerCase().includes(q) ||
                (r.severity    || '').toLowerCase().includes(q) ||
                (r.status      || '').toLowerCase().includes(q) ||
                (r.rootCause   || '').toLowerCase().includes(q)
            );
        }
        return data;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleSearch(event) { this.searchTerm = event.target.value; }

    handleSeverityFilter(event) { this.severityFilter = event.target.value; }

    handleHeaderSort(event) {
        const field = event.currentTarget.dataset.field;
        this.sortDirection = this.sortedBy === field && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortedBy = field;
        this.rows = this._sortData(this.rows, this.sortedBy, this.sortDirection);
    }

    handleViewDetail(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this.rows.find(r => r.id === id);
        if (!row) return;
        this.drawerRow      = row;
        this.activeDrawerId = id;
    }

    handleCloseDrawer() {
        this.activeDrawerId = null;
        this.drawerRow      = null;
    }

    @api
    refreshData() {
        this._fetchData();
    }

    handleHeal(event) {
        const id = event.currentTarget.dataset.id || (this.drawerRow && this.drawerRow.id);
        if (!id) return;
        this.isHealing = true;
        healIncident({ incidentId: id })
            .then(result => {
                this._toast('⚡ Self-Heal Initiated', result.message, 'success');
                return this._fetchData();
            })
            .catch(err => {
                this._toast('Heal Failed', err.body?.message || 'Unknown error', 'error');
            })
            .finally(() => { this.isHealing = false; });
    }

    handleAnalyse(event) {
        const id = event.currentTarget.dataset.id || (this.drawerRow && this.drawerRow.id);
        if (!id) return;
        this.isAnalysing = true;
        analyseIncident({ incidentId: id })
            .then(result => {
                this._toast(
                    '✦ AI Analysis Complete',
                    `${result.recommendedAction} · Confidence: ${result.confidence}%`,
                    'success'
                );
                return this._fetchData();
            })
            .catch(err => {
                this._toast('Analysis Failed', err.body?.message || 'Unknown error', 'error');
            })
            .finally(() => { this.isAnalysing = false; });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _processRows(data) {
        return this._sortData(
            data.map(r => ({
                ...r,
                severityClass     : this._sevClass(r.severity),
                statusClass       : this._statusClass(r.status),
                actionClass       : this._actionClass(r.recommendedAction),
                confidenceFormatted: r.aiConfidence ? r.aiConfidence.toFixed(0) + '%' : '—',
                revenueFormatted  : r.revenueAtRisk ? this._fmtMoney(r.revenueAtRisk) : '—',
            })),
            this.sortedBy,
            this.sortDirection
        );
    }

    _sortData(data, field, dir) {
        const d = dir === 'asc' ? 1 : -1;
        return [...data].sort((a, b) => {
            const av = a[field] ?? '';
            const bv = b[field] ?? '';
            return av > bv ? d : av < bv ? -d : 0;
        });
    }

    _sevClass(s) {
        return { Critical: 'pill sev-critical', High: 'pill sev-high',
                 Medium:   'pill sev-medium',   Low:  'pill sev-low' }[s] || 'pill sev-low';
    }

    _statusClass(s) {
        return { Open: 'pill status-open', Investigating: 'pill status-investigating',
                 Healing: 'pill status-healing', Resolved: 'pill status-resolved',
                 New: 'pill status-open' }[s] || 'pill status-open';
    }

    _actionClass(a) {
        return { Retry: 'action-pill', Escalate: 'action-pill action-escalate',
                 'Restart Service': 'action-pill action-restart' }[a] || 'action-pill';
    }

    _fmtMoney(n) {
        const converted = n * this.currencyRate;
        const sym = this.currencySymbol;
        if (converted >= 1000000) return sym + (converted / 1000000).toFixed(1) + 'M';
        if (converted >= 1000)    return sym + (converted / 1000).toFixed(0) + 'K';
        return sym + converted.toFixed(0);
    }

    _toast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }

    _getCommunityBase() {
        const m = '/s/';
        const p = window.location.pathname;
        const i = p.indexOf(m);
        return i >= 0 ? p.substring(0, i + m.length) : '/';
    }
}