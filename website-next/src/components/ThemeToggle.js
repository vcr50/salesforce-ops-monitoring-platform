'use client';
import { useTheme } from 'next-themes';
import { useEffect, useState } from 'react';
import { Sun, Moon } from 'lucide-react';

export default function ThemeToggle() {
  const [mounted, setMounted] = useState(false);
  const { theme, setTheme } = useTheme();

  // useEffect only runs on the client, so now we can safely show the UI
  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return <div className="w-10 h-10"></div>;
  }

  const isDark = theme === 'dark';

  return (
    <button
      onClick={() => setTheme(isDark ? 'light' : 'dark')}
      className="relative flex items-center justify-center w-10 h-10 rounded-full bg-white/5 border border-white/10 overflow-hidden transition-all duration-300 hover:bg-white/10 hover:scale-105 active:scale-95 focus:outline-none"
      aria-label="Toggle Dark Mode"
    >
      <div className={`absolute transition-all duration-500 transform ${isDark ? 'rotate-90 opacity-0 translate-y-4' : 'rotate-0 opacity-100 translate-y-0'}`}>
        <Sun size={20} className="text-amber-400" />
      </div>
      <div className={`absolute transition-all duration-500 transform ${isDark ? 'rotate-0 opacity-100 translate-y-0' : '-rotate-90 opacity-0 -translate-y-4'}`}>
        <Moon size={20} className="text-blue-400" />
      </div>
    </button>
  );
}
