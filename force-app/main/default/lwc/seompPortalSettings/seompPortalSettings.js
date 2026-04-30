import { LightningElement } from 'lwc';

export default class SeompPortalSettings extends LightningElement {
    saveSettings() {
        // Mock save logic
        const btn = this.template.querySelector('.btn-primary');
        if (btn) {
            btn.textContent = '✓ Saved';
            btn.style.background = '#10b981';
            setTimeout(() => {
                btn.textContent = 'Save Changes';
                btn.style.background = '';
            }, 2000);
        }
    }
}