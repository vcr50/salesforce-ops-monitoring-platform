import { LightningElement, api } from 'lwc';

const STORAGE_KEY = 'tomcodex-service-theme';

export default class TomcodexServicePage extends LightningElement {
    @api companyName = 'Tomcodex';
    @api primaryActionUrl = '#';
    @api secondaryActionUrl = '#';
    theme = 'dark';
    observer;
    hasSetupObserver = false;

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

    renderedCallback() {
        if (this.hasSetupObserver) {
            return;
        }

        this.hasSetupObserver = true;

        if (typeof IntersectionObserver === 'undefined') {
            this.template.querySelectorAll('[data-reveal]').forEach((element) => {
                element.classList.add('is-visible');
            });
            return;
        }

        this.observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-visible');
                        this.observer.unobserve(entry.target);
                    }
                });
            },
            {
                threshold: 0.18
            }
        );

        this.template.querySelectorAll('[data-reveal]').forEach((element) => {
            this.observer.observe(element);
        });
    }

    disconnectedCallback() {
        if (this.observer) {
            this.observer.disconnect();
            this.observer = undefined;
        }
    }

    get shellClass() {
        return `shell ${this.theme}`;
    }

    get themeButtonLabel() {
        return this.theme === 'dark' ? 'Day mode' : 'Dark mode';
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
