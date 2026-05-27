import { LightningElement, track, api } from 'lwc';
import handleChatMessage from '@salesforce/apex/SentinelFlowCopilotController.handleChatMessage';

export default class SentinelFlowPortalCopilot extends LightningElement {
    @api theme = 'dark';

    @track messages = [
        {
            id: 'msg-1',
            isUser: false,
            msgClass: 'msg-row ai',
            content: 'Hello, I am Zentom Hybrid AI for SentinelFlow. Zentom Gen AI handles reasoning and governance, while Agentforce executes trusted Salesforce actions. How can I help you resolve incidents today?'
        }
    ];

    @track isTyping = false;
    @track activeView = 'mission';
    currentInput = '';

    quickActions = [
        "What's the status of the ERP Sync?",
        "Heal Critical Incidents",
        "Show revenue at risk",
        "Summarize recent failures"
    ];

    // View switching
    get isMissionView() { return this.activeView === 'mission'; }
    get isChatView() { return this.activeView === 'chat'; }
    get isArchView() { return this.activeView === 'arch'; }
    
    get missionTabClass() { return this.activeView === 'mission' ? 'view-tab active' : 'view-tab'; }
    get chatTabClass() { return this.activeView === 'chat' ? 'view-tab active' : 'view-tab'; }
    get archTabClass() { return this.activeView === 'arch' ? 'view-tab active' : 'view-tab'; }

    showMission() { this.activeView = 'mission'; }
    showChat() { this.activeView = 'chat'; }
    showArch() { this.activeView = 'arch'; }

    handleInputChange(event) {
        this.currentInput = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            this.sendMessage();
        }
    }

    handleQuickAction(event) {
        this.currentInput = event.target.innerText;
        this.sendMessage();
    }

    sendMessage() {
        if (!this.currentInput.trim()) return;

        const userText = this.currentInput;
        this.messages = [...this.messages, { id: 'msg-' + Date.now(), isUser: true, msgClass: 'msg-row user', content: userText }];
        this.currentInput = '';
        this.isTyping = true;
        this._scrollToBottom();

        // Call the real SentinelFlow Apex AI Engine
        handleChatMessage({ userMessage: userText })
            .then(result => {
                this.isTyping = false;
                this.messages = [...this.messages, { id: 'msg-' + Date.now(), isUser: false, msgClass: 'msg-row ai', content: result }];
                this._scrollToBottom();
            })
            .catch(error => {
                this.isTyping = false;
                let errMsg = 'Unknown error';
                if (error && error.body && error.body.message) errMsg = error.body.message;
                this.messages = [...this.messages, { id: 'msg-' + Date.now(), isUser: false, msgClass: 'msg-row ai', content: 'System Error: ' + errMsg }];
                this._scrollToBottom();
            });
    }

    _scrollToBottom() {
        setTimeout(() => {
            const chatBox = this.template.querySelector('.copilot-chat');
            if (chatBox) {
                chatBox.scrollTop = chatBox.scrollHeight;
            }
        }, 50);
    }
}