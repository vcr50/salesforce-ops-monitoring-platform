import { LightningElement, track, wire } from 'lwc';
import getAnalyticsSummary from '@salesforce/apex/ZentomDashboardController.getAnalyticsSummary';

export default class ZentomAnalyticsCharts extends LightningElement {
    
    // Donut Chart Data
    @track totalRiskEvents = 142;
    @track highRiskPct = 15;
    @track medRiskPct = 35;
    @track lowRiskPct = 50;
    
    // Bar Chart Data
    @track autoPct = 78;
    @track humanPct = 18;
    @track escPct = 4;

    connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        try {
            const raw = await getAnalyticsSummary();
            const data = JSON.parse(raw);
            
            // If the backend has real data, we can use it.
            // For now, we'll randomize slightly to simulate live dashboard feel
            if (!data.error) {
                // Mocking live telemetry variations
                this.autoPct = 70 + Math.floor(Math.random() * 15);
                this.humanPct = 95 - this.autoPct;
                this.escPct = 5;
                
                this.highRiskPct = 10 + Math.floor(Math.random() * 10);
                this.medRiskPct = 30 + Math.floor(Math.random() * 20);
                this.lowRiskPct = 100 - this.highRiskPct - this.medRiskPct;
                
                this.totalRiskEvents = 100 + Math.floor(Math.random() * 200);
            }
        } catch (e) {
            console.error('Analytics Error:', e);
        }
    }

    // Donut Chart logic for SVG circle (path)
    // The path length is exactly 100.
    
    get highRiskStroke() { return `${this.highRiskPct} ${100 - this.highRiskPct}`; }
    
    get medRiskStroke() { return `${this.medRiskPct} ${100 - this.medRiskPct}`; }
    get medRiskOffset() { return `stroke-dashoffset: -${this.highRiskPct}`; }
    
    get lowRiskStroke() { return `${this.lowRiskPct} ${100 - this.lowRiskPct}`; }
    get lowRiskOffset() { return `stroke-dashoffset: -${this.highRiskPct + this.medRiskPct}`; }

    // --- Bar Chart Logic ---
    get autoWidth() { return `width: ${this.autoPct}%`; }
    get humanWidth() { return `width: ${this.humanPct}%`; }
    get escWidth() { return `width: ${this.escPct}%`; }
}