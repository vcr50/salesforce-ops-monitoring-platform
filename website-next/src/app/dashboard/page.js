'use client';

import React from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { ShieldAlert, Zap } from 'lucide-react';
import styles from './page.module.css';

const chartData = [
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

const topIntegrations = [
  { name: 'Salesforce', count: 5, color: '#00a1e0' },
  { name: 'Stripe', count: 3, color: '#635bff' },
  { name: 'SAP', count: 2, color: '#008fd3' },
  { name: 'Zendesk', count: 2, color: '#03363d' },
];

const recentIncidents = [
  { status: 'Resolved', integration: 'Salesforce', color: '#00a1e0', issue: 'API Timeout', time: '2m ago' },
  { status: 'Resolved', integration: 'Stripe', color: '#635bff', issue: 'Rate Limit Exceeded', time: '10m ago' },
  { status: 'Open', integration: 'SAP', color: '#008fd3', issue: 'Authentication Failed', time: '15m ago' },
];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    const data = payload[0].payload;
    const isPeak = data.incidents >= 18;
    
    if (data.isAutoHeal) {
      return (
        <div className={styles.customTooltip}>
          <div className={styles.tooltipHeader} style={{ color: '#10b981' }}>
            <Zap size={14} /> Auto-Heal
          </div>
          <div className={styles.tooltipBody}>
            Incident Resolved
          </div>
        </div>
      );
    }
    
    if (isPeak) {
      return (
        <div className={styles.customTooltip}>
          <div className={styles.tooltipHeader} style={{ color: '#ef4444' }}>
            <ShieldAlert size={14} /> High Volume
          </div>
          <div className={styles.tooltipBody}>
            {label}: {payload[0].value} incidents
          </div>
        </div>
      );
    }

    return (
      <div className={styles.customTooltip}>
        <div className={styles.tooltipBody}>
          {label}: {payload[0].value} incidents
        </div>
      </div>
    );
  }
  return null;
};

export default function DashboardOverview() {
  const [liveIncidents, setLiveIncidents] = React.useState([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    async function fetchIncidents() {
      try {
        const res = await fetch('/api/sf/incidents');
        if (res.ok) {
          const data = await res.json();
          if (data.records) {
            setLiveIncidents(data.records);
          }
        }
      } catch (err) {
        console.error('Failed to fetch incidents', err);
      } finally {
        setLoading(false);
      }
    }
    fetchIncidents();
  }, []);

  return (
    <div className={styles.pageContainer}>
      <h1 className={styles.pageTitle}>Overview</h1>
      
      {/* KPI Cards */}
      <div className={styles.kpiGrid}>
        <div className={styles.card}>
          <h3 className={styles.cardTitle}>Total Integrations</h3>
          <div className={styles.kpiValue}>128</div>
        </div>
        <div className={styles.card}>
          <h3 className={styles.cardTitle}>Open Incidents</h3>
          <div className={styles.kpiValue}>{loading ? '...' : liveIncidents.filter(i => i.Status__c !== 'Closed' && i.Status__c !== 'Resolved').length}</div>
        </div>
        <div className={styles.card}>
          <h3 className={styles.cardTitle}>Resolved Today</h3>
          <div className={styles.kpiValue}>32</div>
        </div>
        <div className={styles.card}>
          <h3 className={styles.cardTitle}>MTTR</h3>
          <div className={styles.kpiValue}>18m</div>
        </div>
      </div>

      {/* Middle Section */}
      <div className={styles.middleSection}>
        {/* Chart */}
        <div className={`${styles.card} ${styles.chartCard}`}>
          <h3 className={styles.cardTitle}>Incidents Over Time</h3>
          <div className={styles.chartContainer}>
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorIncidents" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#7b52ff" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#7b52ff" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis 
                  dataKey="time" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fill: '#a0aec0', fontSize: 12 }} 
                  dy={10}
                />
                <YAxis 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fill: '#a0aec0', fontSize: 12 }} 
                />
                <Tooltip 
                  content={<CustomTooltip />} 
                  cursor={{ stroke: 'rgba(255,255,255,0.1)', strokeWidth: 1, strokeDasharray: '3 3' }} 
                />
                <Area 
                  type="monotone" 
                  dataKey="incidents" 
                  stroke="#7b52ff" 
                  strokeWidth={2}
                  fillOpacity={1} 
                  fill="url(#colorIncidents)" 
                  activeDot={(props) => {
                    const { cx, cy, payload } = props;
                    const isPeak = payload.incidents >= 18;
                    const isHeal = payload.isAutoHeal;
                    const dotColor = isHeal ? '#10b981' : (isPeak ? '#ef4444' : '#00d2ff');
                    
                    return (
                      <g>
                        <circle cx={cx} cy={cy} r={8} fill={dotColor} fillOpacity={0.2} />
                        <circle cx={cx} cy={cy} r={4} fill={dotColor} stroke="#fff" strokeWidth={2} />
                      </g>
                    );
                  }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top Integrations */}
        <div className={styles.card}>
          <h3 className={styles.cardTitle}>Top Integrations by Incidents</h3>
          <div className={styles.integrationsList}>
            {topIntegrations.map((item) => (
              <div key={item.name} className={styles.integrationItem}>
                <div className={styles.integrationLeft}>
                  <div className={styles.integrationIcon} style={{ background: 'transparent' }}>
                    <svg viewBox="0 0 24 24" width="20" height="20" fill={item.color}>
                      <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                    </svg>
                  </div>
                  <span className={styles.integrationName}>{item.name}</span>
                </div>
                <div className={styles.integrationRight}>
                  <svg className={styles.statusIndicator} viewBox="0 0 12 12" fill="none" stroke="#ef4444" strokeWidth="2">
                    <circle cx="6" cy="6" r="4" />
                  </svg>
                  <span className={styles.incidentCount}>{item.count}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent Incidents Table */}
      <div className={styles.card}>
        <h3 className={styles.cardTitle}>Recent Incidents (Live from Salesforce)</h3>
        <div className={styles.tableContainer}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Status</th>
                <th>Incident ID</th>
                <th>Issue</th>
                <th>Revenue Risk</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '20px' }}>Loading real-time data...</td>
                </tr>
              ) : liveIncidents.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '20px' }}>No incidents found.</td>
                </tr>
              ) : liveIncidents.map((incident) => {
                const isResolved = incident.Status__c === 'Closed' || incident.Status__c === 'Resolved';
                const timeString = new Date(incident.CreatedDate).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                
                return (
                  <tr key={incident.Id}>
                    <td>
                      <div className={`${styles.statusBadge} ${isResolved ? styles.statusResolved : styles.statusOpen}`}>
                        <div className={`${styles.statusDot} ${isResolved ? styles.dotResolved : styles.dotOpen}`}></div>
                        {incident.Status__c || 'Open'}
                      </div>
                    </td>
                    <td>
                      <div className={styles.tableIntegration}>
                        <svg viewBox="0 0 24 24" width="16" height="16" fill={incident.Severity__c === 'Critical' ? '#ef4444' : '#f59e0b'}>
                          <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                        </svg>
                        {incident.Name}
                      </div>
                    </td>
                    <td>{incident.Description__c ? incident.Description__c.substring(0, 40) + '...' : 'Unknown Issue'}</td>
                    <td style={{ color: incident.Revenue_at_Risk__c > 50000 ? '#ef4444' : '#a0aec0' }}>
                      ${incident.Revenue_at_Risk__c ? incident.Revenue_at_Risk__c.toLocaleString() : '0'}
                    </td>
                    <td className={styles.tableTime}>{timeString}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
