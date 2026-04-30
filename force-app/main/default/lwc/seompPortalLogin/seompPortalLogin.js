import { LightningElement } from 'lwc';
import seompLogo from '@salesforce/resourceUrl/seompLogo';

export default class SeompPortalLogin extends LightningElement {
    logoUrl = seompLogo;

    handleLogin() {
        const btn = this.template.querySelector('.btn-primary');
        if (btn) {
            btn.textContent = 'Authenticating...';
            setTimeout(() => {
                window.location.href = '/s/';
            }, 800);
        }
    }
}