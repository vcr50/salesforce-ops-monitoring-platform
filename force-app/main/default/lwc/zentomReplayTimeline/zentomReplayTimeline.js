import { LightningElement, api, wire } from 'lwc';
import getReplayTimeline from '@salesforce/apex/ZentomReplayController.getReplayTimeline';

export default class ZentomReplayTimeline extends LightningElement {
    @api recordId;
    timeline = [];
    error;

    @wire(getReplayTimeline, { incidentId: '$recordId' })
    wiredTimeline({ error, data }) {
        if (data) {
            this.timeline = data.map((item, index) => ({
                ...item,
                stepNumber: index + 1,
                iconName: this.getIconName(item.eventType),
                itemClass: `timeline-item ${this.getVariant(item.eventType)}`
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.timeline = [];
        }
    }

    get isEmpty() {
        return !this.error && this.timeline.length === 0;
    }

    getIconName(eventType) {
        if (!eventType) {
            return 'utility:info';
        }
        if (eventType.includes('FAILED')) {
            return 'utility:error';
        }
        if (eventType.includes('APPROVED')) {
            return 'utility:success';
        }
        if (eventType.includes('REJECTED')) {
            return 'utility:block_visitor';
        }
        if (eventType.includes('POLICY')) {
            return 'utility:shield';
        }
        if (eventType.includes('RUNBOOK')) {
            return 'utility:knowledge_base';
        }
        if (eventType.includes('ACTION')) {
            return 'utility:flow';
        }
        if (eventType.includes('CASE')) {
            return 'standard:case';
        }
        return 'utility:info';
    }

    getVariant(eventType) {
        if (!eventType) {
            return 'base';
        }
        if (eventType.includes('FAILED') || eventType.includes('REJECTED')) {
            return 'error';
        }
        if (eventType.includes('APPROVED') || eventType.includes('EXECUTED') || eventType.includes('CASE_CREATED')) {
            return 'success';
        }
        return 'base';
    }
}