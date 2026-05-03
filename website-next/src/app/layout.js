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

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}
