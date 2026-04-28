import { LightningElement, api } from 'lwc';

const STORAGE_KEY = 'tomcodex-service-theme';

export default class TomcodexServicePage extends LightningElement {
    @api companyName = 'Tomcodex';
    @api primaryActionUrl = '#';
    @api secondaryActionUrl = '#';
    theme = 'light';

    connectedCallback() {
        try {
            const savedTheme = window.localStorage.getItem(STORAGE_KEY);
            if (savedTheme === 'dark' || savedTheme === 'light') {
                this.theme = savedTheme;
            }
        } catch (error) {
            // Ignore storage restrictions in preview contexts.
        }
    }

    get shellClass() {
        return `shell ${this.theme}`;
    }

    get themeButtonLabel() {
        return this.theme === 'dark' ? 'Switch to day mode' : 'Switch to dark mode';
    }

    toggleTheme() {
        this.theme = this.theme === 'dark' ? 'light' : 'dark';
        try {
            window.localStorage.setItem(STORAGE_KEY, this.theme);
        } catch (error) {
            // Ignore storage restrictions in preview contexts.
        }
    }
}
