"""
Zentom Predictive Intelligence Engine

Analyzes historical operational data to surface:
1. Recurring incident patterns (same error signature appearing multiple times)
2. Risk trend scoring (is the org's risk profile increasing?)
3. Remediation effectiveness (which actions work best for which error types?)
4. Predicted next incidents based on pattern frequency
"""
import logging
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from app.models.database import SessionLocal, ReplayLog, EvaluationLog, RecoveryWorkflow

logger = logging.getLogger("zentom.predictive")


def generate_predictions(org_id: str = "default") -> dict:
    """
    Generates predictive operational intelligence from historical data.
    Scoped to the requesting org_id for tenant isolation.
    """
    db = SessionLocal()
    try:
        # ── Gather data ──
        replays = db.query(ReplayLog).filter(ReplayLog.org_id == org_id).all()
        evaluations = db.query(EvaluationLog).filter(EvaluationLog.org_id == org_id).all()
        workflows = db.query(RecoveryWorkflow).filter(RecoveryWorkflow.org_id == org_id).all()

        result = {
            "recurringPatterns": _detect_recurring_patterns(replays),
            "riskTrend": _compute_risk_trend(replays),
            "remediationEffectiveness": _analyze_remediation(evaluations),
            "predictedActions": _predict_next_actions(replays, evaluations),
            "orgHealth": _compute_org_health(workflows, evaluations),
        }

        return result

    except Exception as e:
        logger.error(f"[Predictive] Error generating predictions for {org_id}: {e}")
        return {"error": str(e)}
    finally:
        db.close()


def _detect_recurring_patterns(replays: list) -> list:
    """Find error signatures that recur frequently."""
    if not replays:
        return []

    # Count how often each final_action appears for each error context
    error_counter = Counter()
    for r in replays:
        ctx = r.context_snapshot or {}
        sig = ctx.get("errorSignature", "unknown")
        error_counter[sig] += 1

    # Return patterns with 2+ occurrences, sorted by frequency
    patterns = []
    for sig, count in error_counter.most_common(10):
        if count >= 2:
            patterns.append({
                "errorSignature": sig,
                "occurrences": count,
                "severity": "HIGH" if count >= 5 else "MEDIUM" if count >= 3 else "LOW",
                "recommendation": f"Investigate root cause. This error has occurred {count} times."
            })

    return patterns


def _compute_risk_trend(replays: list) -> dict:
    """Compute whether the org's overall risk is trending up or down."""
    if len(replays) < 2:
        return {"trend": "INSUFFICIENT_DATA", "delta": 0.0}

    # Split into first half and second half
    sorted_replays = sorted(replays, key=lambda r: r.timestamp or "")
    mid = len(sorted_replays) // 2
    first_half = sorted_replays[:mid]
    second_half = sorted_replays[mid:]

    def avg_risk(subset):
        scores = []
        for r in subset:
            risk = r.risk_score_snapshot or {}
            if "totalScore" in risk:
                scores.append(risk["totalScore"])
        return sum(scores) / len(scores) if scores else 0

    first_avg = avg_risk(first_half)
    second_avg = avg_risk(second_half)
    delta = second_avg - first_avg

    if delta > 5:
        trend = "INCREASING"
    elif delta < -5:
        trend = "DECREASING"
    else:
        trend = "STABLE"

    return {
        "trend": trend,
        "previousAvgRisk": round(first_avg, 1),
        "currentAvgRisk": round(second_avg, 1),
        "delta": round(delta, 1),
    }


def _analyze_remediation(evaluations: list) -> list:
    """Score each action type by historical success rate."""
    if not evaluations:
        return []

    action_stats = defaultdict(lambda: {"total": 0, "successes": 0})

    for ev in evaluations:
        key = ev.executed_action
        action_stats[key]["total"] += 1
        if ev.success:
            action_stats[key]["successes"] += 1

    results = []
    for action, stats in action_stats.items():
        rate = (stats["successes"] / stats["total"] * 100) if stats["total"] > 0 else 0
        results.append({
            "action": action,
            "totalExecutions": stats["total"],
            "successRate": round(rate, 1),
            "reliability": "HIGH" if rate >= 80 else "MEDIUM" if rate >= 50 else "LOW",
        })

    # Sort by success rate descending
    results.sort(key=lambda x: x["successRate"], reverse=True)
    return results


def _predict_next_actions(replays: list, evaluations: list) -> list:
    """
    Based on pattern frequency and remediation success rates,
    predict which actions will likely be needed next.
    """
    if not replays:
        return []

    # Find the most common actions taken
    action_counter = Counter()
    for r in replays:
        if r.final_action:
            action_counter[r.final_action] += 1

    # Build success rate lookup
    eval_stats = defaultdict(lambda: {"total": 0, "successes": 0})
    for ev in evaluations:
        eval_stats[ev.executed_action]["total"] += 1
        if ev.success:
            eval_stats[ev.executed_action]["successes"] += 1

    predictions = []
    for action, count in action_counter.most_common(5):
        stats = eval_stats[action]
        success_rate = (stats["successes"] / stats["total"] * 100) if stats["total"] > 0 else 0
        predictions.append({
            "action": action,
            "frequency": count,
            "historicalSuccessRate": round(success_rate, 1),
            "confidence": "HIGH" if count >= 3 and success_rate >= 70 else "MEDIUM" if count >= 2 else "LOW",
        })

    return predictions


def _compute_org_health(workflows: list, evaluations: list) -> dict:
    """Compute an overall organization health score (0-100)."""
    if not workflows and not evaluations:
        return {"score": 100, "grade": "A", "factors": []}

    factors = []
    score = 100

    # Factor 1: Workflow resolution rate
    if workflows:
        resolved = sum(1 for w in workflows if w.status == "RESOLVED")
        failed = sum(1 for w in workflows if w.status == "FAILED")
        total = len(workflows)
        resolution_rate = (resolved / total * 100) if total > 0 else 0
        if resolution_rate < 80:
            penalty = int((80 - resolution_rate) * 0.5)
            score -= penalty
            factors.append(f"Resolution rate is {resolution_rate:.0f}% (-{penalty})")

    # Factor 2: Drift alerts
    if evaluations:
        drift_count = sum(1 for e in evaluations if e.drift_detected)
        if drift_count > 0:
            penalty = min(drift_count * 10, 30)
            score -= penalty
            factors.append(f"{drift_count} drift alert(s) detected (-{penalty})")

    # Factor 3: Expired approvals
    if workflows:
        expired = sum(1 for w in workflows if w.status == "EXPIRED")
        if expired > 0:
            penalty = min(expired * 5, 15)
            score -= penalty
            factors.append(f"{expired} workflow(s) expired without approval (-{penalty})")

    score = max(0, min(100, score))

    if score >= 90:
        grade = "A"
    elif score >= 75:
        grade = "B"
    elif score >= 60:
        grade = "C"
    elif score >= 40:
        grade = "D"
    else:
        grade = "F"

    return {"score": score, "grade": grade, "factors": factors}
