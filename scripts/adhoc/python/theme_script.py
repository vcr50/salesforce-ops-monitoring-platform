import re

css_path = r"d:\TomCodeX Inc\SentinelFlow\force-app\main\default\lwc\sentinelFlowBetaAppShell\sentinelFlowBetaAppShell.css"

with open(css_path, "r", encoding="utf-8") as f:
    css = f.read()

# Define color mappings (Hex to Variable)
color_map = {
    r"#ffffff": "var(--bg-surface)",
    r"#f5f7fb": "var(--bg-main)",
    r"#f8fafc": "var(--bg-alt)",
    r"#d9e2ef": "var(--border-light)",
    r"#d9e7ff": "var(--border-blue)",
    r"#e5edf7": "var(--border-alt)",
    r"#172033": "var(--text-primary)",
    r"#111827": "var(--text-dark)",
    r"#60708a": "var(--text-secondary)",
    r"#40516b": "var(--text-muted)",
    r"#3d4d66": "var(--text-alt)",
    r"#27364f": "var(--text-nav)",
    r"#0b63ce": "var(--text-link)",
    r"#66758c": "var(--icon-color)",
    r"#eef5ff": "var(--brand-bg-light)",
    r"#dbeafe": "var(--brand-bg-alt)",
    r"#eaf2ff": "var(--nav-hover-bg)",
    r"#1d4ed8": "var(--brand-primary)",
    r"#155eef": "var(--brand-secondary)",
    r"#0ea5e9": "var(--brand-teal)",
    r"#047857": "var(--color-success-text)",
    r"#16a34a": "var(--color-success)",
    r"#dcfce7": "var(--color-success-bg)",
    r"#dc2626": "var(--color-danger)",
    r"#b91c1c": "var(--color-danger-text)",
    r"#fee2e2": "var(--color-danger-bg)",
    r"#ef4444": "var(--color-danger-light)",
    r"#f59e0b": "var(--color-warning)",
    r"#d97706": "var(--color-warning-text)",
    r"#ffedd5": "var(--color-warning-bg)",
    r"rgba\(23, 32, 51, 0.04\)": "var(--shadow-light)",
    r"rgba\(23, 32, 51, 0.06\)": "var(--shadow-medium)",
    r"rgba\(23, 32, 51, 0.08\)": "var(--shadow-heavy)",
}

# Add host variables
host_vars = """
:host {
    --bg-surface: #ffffff;
    --bg-main: #f5f7fb;
    --bg-alt: #f8fafc;
    --border-light: #d9e2ef;
    --border-blue: #d9e7ff;
    --border-alt: #e5edf7;
    --text-primary: #172033;
    --text-dark: #111827;
    --text-secondary: #60708a;
    --text-muted: #40516b;
    --text-alt: #3d4d66;
    --text-nav: #27364f;
    --text-link: #0b63ce;
    --icon-color: #66758c;
    --brand-bg-light: #eef5ff;
    --brand-bg-alt: #dbeafe;
    --nav-hover-bg: #eaf2ff;
    --brand-primary: #1d4ed8;
    --brand-secondary: #155eef;
    --brand-teal: #0ea5e9;
    
    --color-success: #16a34a;
    --color-success-text: #047857;
    --color-success-bg: #dcfce7;
    --color-danger: #dc2626;
    --color-danger-text: #b91c1c;
    --color-danger-bg: #fee2e2;
    --color-danger-light: #ef4444;
    --color-warning: #f59e0b;
    --color-warning-text: #d97706;
    --color-warning-bg: #ffedd5;
    
    --shadow-light: rgba(23, 32, 51, 0.04);
    --shadow-medium: rgba(23, 32, 51, 0.06);
    --shadow-heavy: rgba(23, 32, 51, 0.08);
}

:host(.dark-theme) {
    --bg-surface: #1e293b;
    --bg-main: #0f172a;
    --bg-alt: #334155;
    --border-light: #334155;
    --border-blue: #1e3a8a;
    --border-alt: #475569;
    --text-primary: #f8fafc;
    --text-dark: #ffffff;
    --text-secondary: #cbd5e1;
    --text-muted: #94a3b8;
    --text-alt: #e2e8f0;
    --text-nav: #e2e8f0;
    --text-link: #60a5fa;
    --icon-color: #94a3b8;
    --brand-bg-light: #1e3a8a;
    --brand-bg-alt: #1e40af;
    --nav-hover-bg: #1e293b;
    --brand-primary: #3b82f6;
    --brand-secondary: #60a5fa;
    --brand-teal: #38bdf8;
    
    --color-success: #22c55e;
    --color-success-text: #86efac;
    --color-success-bg: rgba(22, 163, 74, 0.2);
    --color-danger: #ef4444;
    --color-danger-text: #fca5a5;
    --color-danger-bg: rgba(220, 38, 38, 0.2);
    --color-danger-light: #f87171;
    --color-warning: #f59e0b;
    --color-warning-text: #fcd34d;
    --color-warning-bg: rgba(217, 119, 6, 0.2);
    
    --shadow-light: rgba(0, 0, 0, 0.4);
    --shadow-medium: rgba(0, 0, 0, 0.5);
    --shadow-heavy: rgba(0, 0, 0, 0.6);
}
"""

# Apply mappings
for hex_code, var_name in color_map.items():
    # Case insensitive replacement for hex codes
    css = re.sub(hex_code, var_name, css, flags=re.IGNORECASE)

# Insert host variables at the top (replace existing :host if it exists, otherwise prepend)
if ":host {" in css:
    css = re.sub(r":host\s*{[^}]*}", host_vars.strip(), css, count=1)
else:
    css = host_vars + "\n" + css

# Fix standard icon alignment
css += """
/* Tab Icon Vertical Alignment Fixes */
.nav-item {
    align-items: center;
}
.nav-item lightning-icon {
    display: flex;
    align-items: center;
    justify-content: center;
}

/* RWD Media Queries */
@media (max-width: 1024px) {
    .health-hero {
        grid-template-columns: 1fr;
    }
    .kpi-grid {
        grid-template-columns: repeat(3, 1fr);
    }
    .main-grid, .lower-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 768px) {
    .workspace {
        flex-direction: column;
    }
    
    /* Mobile Sidebar Hidden by Default */
    .sidebar {
        width: 100%;
        flex: none;
        display: none;
        border-right: none;
        border-bottom: 1px solid var(--border-light);
    }
    
    .sidebar.mobile-open {
        display: flex;
    }
    
    .kpi-grid {
        grid-template-columns: 1fr 1fr;
    }
    
    .global-search {
        display: none; /* Hide global search on mobile to save space */
    }
    
    .topbar-actions .user-chip,
    .topbar-actions .health-chip {
        display: none;
    }
}
"""

with open(css_path, "w", encoding="utf-8") as f:
    f.write(css)

print("CSS Transformed successfully.")
