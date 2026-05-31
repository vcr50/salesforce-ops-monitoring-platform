css_path = r"d:\TomCodeX Inc\SentinelFlow\force-app\main\default\lwc\sentinelFlowBetaAppShell\sentinelFlowBetaAppShell.css"

with open(css_path, "a", encoding="utf-8") as f:
    f.write("""
/* Mascot Wrapper */
.global-mascot-wrapper {
    position: fixed;
    bottom: 2rem;
    right: 2rem;
    z-index: 9999;
    pointer-events: none; /* Let clicks pass through empty areas */
}

/* Mobile Menu Button - Hidden on Desktop */
.mobile-menu-btn {
    display: none;
    margin-right: 0.5rem;
}

@media (max-width: 768px) {
    .mobile-menu-btn {
        display: flex;
    }
}
""")

print("Appended CSS successfully.")
