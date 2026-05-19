'use client';
import { useState, useEffect } from 'react';
import styles from './page.module.css';

export default function ZentomReplayDashboard() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  // In a real application, this would fetch from a Next.js API route that connects to Salesforce.
  // For the prototype, we simulate the data payload.
  useEffect(() => {
    const mockLogs = [
      {
        id: 'ZRL-0000001',
        incidentId: 'INC-2093',
        policyMode: 'AUTONOMOUS_EXECUTION',
        confidenceScore: 92,
        riskScore: 25.5,
        contextArr: 15000,
        proposedAction: 'Restart Service',
        timestamp: new Date(Date.now() - 1000 * 60 * 5).toISOString()
      },
      {
        id: 'ZRL-0000002',
        incidentId: 'INC-2094',
        policyMode: 'HUMAN_APPROVAL_REQUIRED',
        confidenceScore: 65,
        riskScore: 82.0,
        contextArr: 250000,
        proposedAction: 'Escalate',
        timestamp: new Date(Date.now() - 1000 * 60 * 45).toISOString()
      },
      {
        id: 'ZRL-0000003',
        incidentId: 'INC-2095',
        policyMode: 'AUTONOMOUS_EXECUTION',
        confidenceScore: 88,
        riskScore: 40.0,
        contextArr: 45000,
        proposedAction: 'Retry Integration',
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString()
      },
      {
        id: 'ZRL-0000004',
        incidentId: 'INC-2096',
        policyMode: 'BLOCKED_BY_POLICY',
        confidenceScore: 95,
        riskScore: 95.0,
        contextArr: 500000,
        proposedAction: 'Drop Metadata Table',
        timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString()
      }
    ];

    setTimeout(() => {
      setLogs(mockLogs);
      setLoading(false);
    }, 800);
  }, []);

  const getBadgeClass = (mode) => {
    switch(mode) {
      case 'AUTONOMOUS_EXECUTION': return styles.badgeAutonomous;
      case 'HUMAN_APPROVAL_REQUIRED': return styles.badgeHuman;
      case 'BLOCKED_BY_POLICY': return styles.badgeBlocked;
      default: return '';
    }
  };

  const getBadgeText = (mode) => {
    switch(mode) {
      case 'AUTONOMOUS_EXECUTION': return 'Auto Executed';
      case 'HUMAN_APPROVAL_REQUIRED': return 'Guardian Gate: Blocked';
      case 'BLOCKED_BY_POLICY': return 'Policy Violation';
      default: return mode;
    }
  };

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      maximumFractionDigits: 0
    }).format(value);
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <div className={styles.header}>
          <h1 className={styles.title}>Zentom Orchestration Logs</h1>
          <p className={styles.subtitle}>Loading secure audit trail...</p>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h1 className={styles.title}>Zentom Orchestration Logs</h1>
        <p className={styles.subtitle}>Immutable audit trace of all AI decisions, governance gates, and risk scores.</p>
      </div>

      {logs.length === 0 ? (
        <div className={styles.emptyState}>
          <p>No replay logs found.</p>
        </div>
      ) : (
        <div className={styles.logGrid}>
          {logs.map((log) => (
            <div key={log.id} className={styles.logCard}>
              <div className={styles.cardHeader}>
                <div>
                  <span className={styles.incidentId}>{log.id} • {log.incidentId}</span>
                  <div style={{fontSize: '0.8rem', color: '#6b7280', marginTop: '0.25rem'}}>
                    {new Date(log.timestamp).toLocaleString()}
                  </div>
                </div>
                <div className={`${styles.badge} ${getBadgeClass(log.policyMode)}`}>
                  {getBadgeText(log.policyMode)}
                </div>
              </div>
              
              <div className={styles.metricsGrid}>
                <div className={styles.metric}>
                  <span className={styles.metricLabel}>Model Confidence</span>
                  <span className={`${styles.metricValue} ${log.confidenceScore >= 80 ? styles.confidenceHigh : styles.confidenceLow}`}>
                    {log.confidenceScore}%
                  </span>
                </div>
                <div className={styles.metric}>
                  <span className={styles.metricLabel}>Risk Score</span>
                  <span className={styles.metricValue}>{log.riskScore.toFixed(1)}</span>
                </div>
                <div className={styles.metric}>
                  <span className={styles.metricLabel}>Context ARR</span>
                  <span className={styles.metricValue}>{formatCurrency(log.contextArr)}</span>
                </div>
              </div>

              <div className={styles.actionSection}>
                <div className={styles.actionLabel}>Proposed Action</div>
                <div className={styles.actionValue}>{log.proposedAction}</div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
