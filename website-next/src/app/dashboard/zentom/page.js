'use client';
import { useState, useEffect } from 'react';
import { RefreshCw, ShieldAlert, CheckCircle2, AlertTriangle, PlayCircle } from 'lucide-react';
import styles from './page.module.css';

export default function ZentomReplayDashboard() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchLogs = async () => {
    setRefreshing(true);
    try {
      const res = await fetch('/api/zentom/logs');
      if (res.ok) {
        const data = await res.json();
        // metrics returns { recent_logs: [...] }
        if (data.recent_logs) {
          setLogs(data.recent_logs);
        }
      }
    } catch (error) {
      console.error('Failed to fetch logs:', error);
    } finally {
      setLoading(false);
      setTimeout(() => setRefreshing(false), 500); // UI feedback
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const getBadgeStyle = (confidence) => {
    if (confidence >= 80) return "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20";
    if (confidence >= 60) return "bg-amber-500/10 text-amber-400 border border-amber-500/20";
    return "bg-rose-500/10 text-rose-400 border border-rose-500/20";
  };

  if (loading) {
    return (
      <div className={styles.container}>
        <div className="flex flex-col items-center justify-center h-64 space-y-4">
          <RefreshCw className="animate-spin text-purple-500" size={32} />
          <p className="text-gray-400 text-lg">Loading secure audit trail...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 animate-in fade-in duration-500">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-10 gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-white mb-2 flex items-center gap-3">
            <PlayCircle className="text-purple-500" size={32} />
            Zentom Orchestration Logs
          </h1>
          <p className="text-gray-400 text-lg max-w-2xl">
            Immutable audit trace of all AI decisions, governance gates, and risk scores.
          </p>
        </div>
        
        <button 
          onClick={fetchLogs}
          disabled={refreshing}
          className="group relative inline-flex items-center justify-center gap-2 px-6 py-3 font-semibold text-white transition-all duration-300 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 hover:border-purple-500/50 hover:shadow-[0_0_20px_rgba(123,82,255,0.2)] focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 overflow-hidden"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-purple-500/20 to-blue-500/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
          <RefreshCw size={18} className={`relative z-10 ${refreshing ? 'animate-spin text-purple-400' : 'text-gray-400 group-hover:text-white transition-colors'}`} />
          <span className="relative z-10">{refreshing ? 'Syncing...' : 'Live Refresh'}</span>
        </button>
      </div>

      {logs.length === 0 ? (
        <div className="flex flex-col items-center justify-center p-16 rounded-2xl bg-[#16161f] border border-white/5">
          <ShieldAlert className="text-gray-600 mb-4" size={48} />
          <p className="text-gray-400 text-lg font-medium">No replay logs found.</p>
          <p className="text-gray-500 text-sm mt-2">Any autonomous or human-approved actions will appear here.</p>
        </div>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {logs.map((log) => (
            <div 
              key={log.id} 
              className="flex flex-col bg-[#16161f] border border-white/5 hover:border-purple-500/30 rounded-2xl p-6 transition-all duration-300 hover:shadow-[0_8px_30px_rgba(0,0,0,0.4)] hover:-translate-y-1 group"
            >
              <div className="flex justify-between items-start mb-6">
                <div>
                  <div className="text-xs font-bold tracking-wider text-purple-400 uppercase mb-1">
                    ZRL-{String(log.id).padStart(7, '0')}
                  </div>
                  <div className="font-semibold text-gray-200">
                    {log.incident_id}
                  </div>
                  <div className="text-xs text-gray-500 mt-1">
                    {new Date(log.timestamp).toLocaleString(undefined, { 
                      month: 'short', day: 'numeric', 
                      hour: '2-digit', minute: '2-digit', second: '2-digit'
                    })}
                  </div>
                </div>
                
                <div className={`px-3 py-1 text-xs font-bold rounded-full ${log.success ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}`}>
                  {log.success ? 'Success' : 'Failed'}
                </div>
              </div>
              
              <div className="flex-grow space-y-4">
                <div className="flex justify-between items-center p-3 rounded-lg bg-black/20 border border-white/5">
                  <span className="text-sm text-gray-400">Model Confidence</span>
                  <span className={`text-sm font-bold px-2 py-0.5 rounded ${getBadgeStyle(log.confidence)}`}>
                    {log.confidence}%
                  </span>
                </div>
                
                <div className="pt-4 border-t border-white/5">
                  <div className="text-xs text-gray-500 uppercase font-semibold tracking-wider mb-2">Proposed Action</div>
                  <div className="font-medium text-gray-200 group-hover:text-purple-300 transition-colors">
                    {log.action}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
