import { LightningElement, track } from 'lwc';
import sentinelFlowPulseLogo from '@salesforce/resourceUrl/sentinelFlowPulseLogo';

export default class SentinelFlowThemeHeader extends LightningElement {
    logoUrl = sentinelFlowPulseLogo;
    @track currentTime = '';

    connectedCallback() {
        this.updateTime();
        this.timer = setInterval(() => {
            this.updateTime();
        }, 1000);
    }

    disconnectedCallback() {
        clearInterval(this.timer);
    }

    updateTime() {
        const d = new Date();
        this.currentTime = d.toLocaleTimeString('en-US', { hour12: false });
    }
}