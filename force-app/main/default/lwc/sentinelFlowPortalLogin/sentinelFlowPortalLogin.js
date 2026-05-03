import { LightningElement, track } from 'lwc';
import sentinelFlowLogo from '@salesforce/resourceUrl/sentinelFlowLogo';
import loginUser from '@salesforce/apex/SentinelFlowLoginController.loginUser';
import forgotPassword from '@salesforce/apex/SentinelFlowLoginController.forgotPassword';
import getSsoUrls from '@salesforce/apex/SentinelFlowLoginController.getSsoUrls';

export default class SentinelFlowPortalLogin extends LightningElement {
    logoUrl = sentinelFlowLogo;

    @track username = '';
    @track password = '';
    @track forgotEmail = '';
    @track errorMessage = '';
    @track successMessage = '';
    @track isLoading = false;
    @track showForgotPassword = false;
    @track rememberMe = false;
    @track salesforceSsoUrl;
    @track googleSsoUrl;

    connectedCallback() {
        this.fetchSsoUrls();
    }

    async fetchSsoUrls() {
        try {
            const urls = await getSsoUrls();
            if (urls) {
                this.salesforceSsoUrl = urls.Salesforce;
                this.googleSsoUrl = urls.Google;
            }
        } catch (error) {
            console.error('Error fetching SSO URLs', error);
        }
    }

    get loginBtnLabel() {
        return this.isLoading ? 'Authenticating...' : 'Log In';
    }

    get resetBtnLabel() {
        return this.isLoading ? 'Sending...' : 'Send Reset Link';
    }

    get isLoginDisabled() {
        return this.isLoading;
    }

    handleUsernameChange(event) {
        this.username = event.target.value;
        this.errorMessage = '';
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
        this.errorMessage = '';
    }

    handleForgotEmailChange(event) {
        this.forgotEmail = event.target.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleRememberChange(event) {
        this.rememberMe = event.target.checked;
    }

    async handleLogin() {
        this.errorMessage = '';
        const username = this.username.trim();

        if (!username || !this.password) {
            this.errorMessage = 'Please enter both username/email and password.';
            return;
        }

        this.isLoading = true;

        try {
            const redirectUrl = await loginUser({
                username,
                password: this.password,
                startUrl: this.getStartUrl()
            });

            if (redirectUrl) {
                window.location.assign(redirectUrl);
            } else {
                this.errorMessage = 'Invalid username or password. Please try again.';
            }
        } catch (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : 'Login failed. Please check your credentials.';
        } finally {
            this.isLoading = false;
        }
    }

    getStartUrl() {
        const params = new URLSearchParams(window.location.search);
        const startUrl = params.get('startURL') || params.get('startUrl');

        if (startUrl && startUrl.startsWith('/')) {
            return this.stripSitePrefix(startUrl);
        }

        return '/';
    }

    stripSitePrefix(startUrl) {
        const currentPath = window.location.pathname || '/';
        const loginSuffix = '/login';
        const loginIndex = currentPath.toLowerCase().lastIndexOf(loginSuffix);

        if (loginIndex > 0) {
            const sitePrefix = currentPath.substring(0, loginIndex);
            if (startUrl === sitePrefix || startUrl === `${sitePrefix}/`) {
                return '/';
            }
            if (startUrl.startsWith(`${sitePrefix}/`)) {
                return startUrl.substring(sitePrefix.length) || '/';
            }
        }

        return startUrl;
    }

    handleSalesforceLogin(event) {
        event.preventDefault();
        if (this.salesforceSsoUrl) {
            window.location.href = this.salesforceSsoUrl;
        }
    }

    handleGoogleLogin(event) {
        event.preventDefault();
        if (this.googleSsoUrl) {
            window.location.href = this.googleSsoUrl;
        }
    }

    handleShowForgot(event) {
        event.preventDefault();
        this.showForgotPassword = true;
        this.errorMessage = '';
        this.successMessage = '';
        this.forgotEmail = this.username || '';
    }

    handleBackToLogin(event) {
        event.preventDefault();
        this.showForgotPassword = false;
        this.errorMessage = '';
        this.successMessage = '';
    }

    async handleForgotPassword() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.forgotEmail) {
            this.errorMessage = 'Please enter your email address.';
            return;
        }

        this.isLoading = true;

        try {
            const result = await forgotPassword({ username: this.forgotEmail });
            if (result) {
                this.successMessage =
                    'Password reset link sent! Check your inbox for instructions.';
            } else {
                this.errorMessage =
                    'Unable to reset password. Please verify your email.';
            }
        } catch (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : 'Something went wrong. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            if (this.showForgotPassword) {
                this.handleForgotPassword();
            } else {
                this.handleLogin();
            }
        }
    }
}
