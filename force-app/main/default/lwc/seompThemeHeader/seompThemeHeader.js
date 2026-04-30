import { LightningElement, track } from 'lwc';

export default class SeompThemeHeader extends LightningElement {
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
