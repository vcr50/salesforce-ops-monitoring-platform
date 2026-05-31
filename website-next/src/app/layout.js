import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "SentinelFlow — AI-Powered Incident Intelligence Platform",
  description: "SentinelFlow is an enterprise-grade AI incident intelligence platform. Detect, analyze, and auto-heal production incidents in real-time.",
  icons: {
    icon: '/assets/logo.svg',
  },
};

import { ThemeProvider } from "@/components/ThemeProvider";
import ZentomMascot from "@/components/ZentomMascot";

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false}>
          {children}
          <ZentomMascot />
        </ThemeProvider>
      </body>
    </html>
  );
}
