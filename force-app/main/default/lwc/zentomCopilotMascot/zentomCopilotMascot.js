import { LightningElement, track } from 'lwc';
import getDeepHealth from '@salesforce/apex/ZentomDashboardController.getDeepHealth';
import getAuditLogs from '@salesforce/apex/ZentomDashboardController.getAuditLogs';
import ZENTOM_MASCOT_ASSETS from '@salesforce/resourceUrl/zentom_mascot_assets';

export default class ZentomCopilotMascot extends LightningElement {
    @track isMascotEnabled = false;
    @track currentState = 'idle'; // idle, angry, excited, thinking
    @track currentMessage = '';
    @track showMessage = false;
    @track showGifPopup = false;

    pollingInterval;
    lastLogId = null;

    // Use a placeholder UI avatar or static resource URL
    // We will assume the user has uploaded ZentomMascotAssets static resource
    // For now, we will use a fallback image if the static resource isn't loaded
    get currentImageUrl() {
        const base = ZENTOM_MASCOT_ASSETS + '/';
        switch (this.currentState) {
            case 'angry': return base + 'angry.png';
            case 'excited': return base + 'excited.png';
            case 'thinking': return base + 'thinking.png';
            default: return base + 'idle.png';
        }
    }

    connectedCallback() {
        // Check user preference
        const storedPref = localStorage.getItem('zentom_mascot_enabled');
        if (storedPref === 'false') {
            this.isMascotEnabled = false;
            return;
        }

        this.isMascotEnabled = true;
        this.startGuardianDuty();
    }

    disconnectedCallback() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
    }

    startGuardianDuty() {
        // Initial greeting
        this.say('Zentom AI Guardian online. Protecting the perimeter.', 4000);
        
        // Poll every 8 seconds to check for new issues or heals
        this.pollingInterval = setInterval(() => {
            this.checkEnvironment();
        }, 8000);
    }

    async checkEnvironment() {
        try {
            // First check overall health
            const healthRes = await getDeepHealth();
            const healthData = JSON.parse(healthRes);
            
            if (healthData.grade === 'F' || healthData.grade === 'D') {
                if (this.currentState !== 'angry') {
                    this.setState('angry');
                    this.say('Critical vulnerabilities detected! I am on high alert!', 5000);
                }
                return; // Prioritize angry state if things are bad
            }

            // Then check recent logs for "heals"
            const logRes = await getAuditLogs();
            const logData = JSON.parse(logRes);
            
            if (logData && logData.logs && logData.logs.length > 0) {
                const latestLog = logData.logs[0];
                
                // Only react if this is a NEW log we haven't seen
                if (this.lastLogId !== latestLog.id) {
                    this.lastLogId = latestLog.id;
                    
                    if (latestLog.action.includes('Heal') || latestLog.action.includes('Remediate') || latestLog.status === 'SUCCESS') {
                        this.setState('excited');
                        this.say('Successfully healed the issue! Great job!', 4000);
                    } else if (latestLog.status === 'FAILED' || latestLog.status === 'BLOCKED') {
                        this.setState('angry');
                        this.say(`Blocked malicious action: ${latestLog.action}`, 4000);
                    } else {
                        this.setState('thinking');
                        setTimeout(() => this.setState('idle'), 2000);
                    }
                }
            } else if (this.currentState !== 'idle' && this.currentState !== 'angry') {
                // Return to idle if everything is fine and no new events
                this.setState('idle');
            }

        } catch (e) {
            console.error('Mascot Error:', e);
        }
    }

    setState(stateName) {
        this.currentState = stateName;
    }

    say(text, duration = 3000) {
        this.currentMessage = text;
        this.showMessage = true;
        
        setTimeout(() => {
            this.showMessage = false;
        }, duration);
    }

    pokeMascot() {
        this.showGifPopup = !this.showGifPopup;
        if (this.showGifPopup) {
            this.setState('thinking');
            this.showMessage = false; // Hide regular speech bubble if popup is open
        } else {
            this.setState('idle');
        }
    }

    disableMascot() {
        this.isMascotEnabled = false;
        localStorage.setItem('zentom_mascot_enabled', 'false');
    }
}
