import { LightningElement, track } from 'lwc';

export default class SentinelFlowPortalChart extends LightningElement {
    @track isHovering = false;
    @track activePoint = {};
    @track tooltipStyle = '';

    // Fixed mock data matching the Next.js prototype
    rawChartData = [
        { time: '12 AM', incidents: 20 },
        { time: '2 AM', incidents: 12 },
        { time: '4 AM', incidents: 10 },
        { time: '6 AM', incidents: 16 },
        { time: '8 AM', incidents: 11 },
        { time: '10 AM', incidents: 12 },
        { time: '12 PM', incidents: 18, isAutoHeal: true },
        { time: '2 PM', incidents: 16 },
        { time: '4 PM', incidents: 18 },
        { time: '6 PM', incidents: 17 },
        { time: '8 PM', incidents: 22 },
        { time: '10 PM', incidents: 18 },
    ];

    // Chart Configuration
    svgWidth = 800;
    svgHeight = 300;
    maxIncidents = 25; // to scale the Y axis

    get chartData() {
        // Calculate X and Y positions for the chart data
        const stepX = this.svgWidth / (this.rawChartData.length - 1);
        
        return this.rawChartData.map((item, index) => {
            const x = index * stepX;
            // Invert Y axis since SVG 0,0 is top-left
            const y = this.svgHeight - ((item.incidents / this.maxIncidents) * this.svgHeight);
            
            return {
                ...item,
                x: Math.round(x),
                y: Math.round(y),
                labelStyle: `left: ${(index / (this.rawChartData.length - 1)) * 100}%; transform: translateX(-50%);`
            };
        });
    }

    get linePath() {
        const data = this.chartData;
        if (!data || data.length === 0) return '';
        
        // Simple linear interpolation (monotone like curve is complex in basic SVG without d3, so we use linear or basic curve)
        let d = `M ${data[0].x} ${data[0].y}`;
        for (let i = 1; i < data.length; i++) {
            // Cubic bezier for smoothing
            const prev = data[i - 1];
            const curr = data[i];
            const cpX = (prev.x + curr.x) / 2;
            d += ` C ${cpX} ${prev.y}, ${cpX} ${curr.y}, ${curr.x} ${curr.y}`;
        }
        return d;
    }

    get areaPath() {
        const data = this.chartData;
        if (!data || data.length === 0) return '';
        
        let d = this.linePath;
        // Close the path for the area fill
        d += ` L ${data[data.length - 1].x} ${this.svgHeight}`;
        d += ` L ${data[0].x} ${this.svgHeight} Z`;
        return d;
    }

    handleMouseMove(event) {
        this.isHovering = true;
        const container = this.template.querySelector('.chart-container');
        if (!container) return;

        const rect = container.getBoundingClientRect();
        // Mouse X relative to container
        const mouseX = event.clientX - rect.left;
        
        // Map mouseX to closest data point
        const data = this.chartData;
        // The scale factor between rendered width and SVG viewBox width
        const scaleX = this.svgWidth / rect.width;
        const svgMouseX = mouseX * scaleX;

        // Find closest point by X coordinate
        let closest = data[0];
        let minDiff = Math.abs(svgMouseX - data[0].x);
        
        for (let i = 1; i < data.length; i++) {
            const diff = Math.abs(svgMouseX - data[i].x);
            if (diff < minDiff) {
                minDiff = diff;
                closest = data[i];
            }
        }

        const isPeak = closest.incidents >= 18;
        const isAutoHeal = closest.isAutoHeal;
        const color = isAutoHeal ? '#10b981' : (isPeak ? '#ef4444' : '#00d2ff');

        this.activePoint = {
            ...closest,
            isPeak,
            isAutoHeal,
            isSpecial: isPeak || isAutoHeal,
            color
        };

        // Calculate tooltip position (keep it inside bounds)
        let tooltipLeft = (closest.x / this.svgWidth) * rect.width;
        // offset to the right, unless it's too close to the right edge
        if (tooltipLeft > rect.width - 150) {
            tooltipLeft -= 160; 
        } else {
            tooltipLeft += 20;
        }

        const tooltipTop = (closest.y / this.svgHeight) * rect.height - 40;

        this.tooltipStyle = `left: ${tooltipLeft}px; top: ${tooltipTop}px;`;
    }

    handleMouseLeave() {
        this.isHovering = false;
    }
}