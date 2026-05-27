'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { 
  Activity, 
  Bell, 
  ChevronDown, 
  FileText, 
  LayoutDashboard, 
  Link as LinkIcon, 
  Settings, 
  Zap 
} from 'lucide-react';
import ThemeToggle from '@/components/ThemeToggle';
import ZentomMascot from '@/components/ZentomMascot';
import styles from './layout.module.css';

const navItems = [
  { name: 'Overview', path: '/dashboard', icon: LayoutDashboard },
  { name: 'Incidents', path: '/dashboard/incidents', icon: Bell },
  { name: 'Zentom Logs', path: '/dashboard/zentom', icon: Zap },
  { name: 'Integrations', path: '/dashboard/integrations', icon: LinkIcon },
  { name: 'Reports', path: '/dashboard/reports', icon: FileText },
  { name: 'Settings', path: '/dashboard/settings', icon: Settings },
];

export default function DashboardLayout({ children }) {
  const pathname = usePathname();

  return (
    <div className={styles.container}>
      {/* Sidebar */}
      <aside className={styles.sidebar}>
        <div className={styles.brand}>
          <Activity className={styles.logoIcon} size={28} />
          <span>SentinelFlow</span>
        </div>
        
        <nav className={styles.nav}>
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.path;
            
            return (
              <Link 
                key={item.name} 
                href={item.path} 
                className={`${styles.navItem} ${isActive ? styles.active : ''}`}
              >
                <Icon className={styles.navIcon} />
                {item.name}
              </Link>
            );
          })}
        </nav>
      </aside>

      {/* Main Content Area */}
      <main className={styles.main}>
        {/* Topbar */}
        <header className={styles.topbar}>
          <button className={styles.timeFilter}>
            Last 24 hours
            <ChevronDown size={14} />
          </button>
          
          <button className={styles.notificationBtn}>
            <Bell size={20} />
          </button>
          
          <ThemeToggle />
          
          <div className={styles.avatar}>
            A
          </div>
        </header>

        {/* Content */}
        <div className={styles.contentWrapper}>
          <div className={styles.glowTop}></div>
          <div className={styles.glowBottom}></div>
          {children}
        </div>
      </main>
      
      {/* Global Zentom Mascot */}
      <ZentomMascot />
    </div>
  );
}
