import { LightningElement, track } from 'lwc';
import handleChatMessage from '@salesforce/apex/SentinelFlowCopilotController.handleChatMessage';

export default class SentinelFlowPortalCopilot extends LightningElement {
    @track messages = [
        {
            id: 'msg-1',
            isUser: false,
            msgClass: 'msg-row ai',
            content: 'Hello, I am SentinelFlow Copilot, powered by Agentforce. How can I help you resolve incidents today?'
        }
    ];

    @track isTyping = false;
    currentInput = '';

    quickActions = [
        "What's the status of the ERP Sync?",
        "Heal Critical Incidents",
        "Show revenue at risk",
        "Summarize recent failures"
    ];

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
