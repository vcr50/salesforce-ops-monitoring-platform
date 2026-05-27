ALLOWED_ACTIONS = {
    "Restart Service",
    "Escalate",
    "Retry Operation",
    "Rollback",
    "Update Record",
    "Patch Configuration",
}

ACTION_ALIASES = {
    "Refresh Token": "Patch Configuration",
    "Create Jira Ticket": "Escalate",
    "Open Ticket": "Escalate",
}


def normalize_action(action: str) -> str:
    """Map model-specific action labels into the execution vocabulary."""
    if not action:
        return "Escalate"
    action = ACTION_ALIASES.get(action, action)
    return action if action in ALLOWED_ACTIONS else "Escalate"
