css_path = r"d:\TomCodeX Inc\SentinelFlow\force-app\main\default\lwc\zentomCopilotMascot\zentomCopilotMascot.css"

with open(css_path, "a", encoding="utf-8") as f:
    f.write("""
/* GIF Popup Modal */
.gif-popup {
    position: absolute;
    bottom: calc(100% + 20px);
    right: 0;
    width: 280px;
    background: var(--bg-surface, #ffffff);
    border: 1px solid var(--border-light, #d9e2ef);
    border-radius: 12px;
    box-shadow: 0 12px 32px rgba(0,0,0,0.15);
    z-index: 101;
    overflow: hidden;
    pointer-events: auto;
}

.popup-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 12px;
    background: var(--bg-alt, #f8fafc);
    border-bottom: 1px solid var(--border-light, #d9e2ef);
    color: var(--text-primary, #172033);
    font-size: 0.85rem;
}

.popup-header button {
    background: transparent;
    border: none;
    font-size: 1.2rem;
    cursor: pointer;
    color: var(--text-muted, #60708a);
    display: flex;
    align-items: center;
    justify-content: center;
}

.popup-body {
    padding: 12px;
    text-align: center;
}

.ai-gif {
    width: 100%;
    border-radius: 8px;
    margin-bottom: 10px;
}

.popup-body p {
    margin: 0;
    font-size: 0.85rem;
    color: var(--text-secondary, #40516b);
    line-height: 1.4;
}

.popup-tail {
    position: absolute;
    bottom: -8px;
    right: 30px;
    width: 16px;
    height: 16px;
    background: var(--bg-surface, #ffffff);
    border-right: 1px solid var(--border-light, #d9e2ef);
    border-bottom: 1px solid var(--border-light, #d9e2ef);
    transform: rotate(45deg);
    z-index: -1;
}

.mascot-container {
    pointer-events: auto;
}
""")

print("Mascot CSS appended.")
