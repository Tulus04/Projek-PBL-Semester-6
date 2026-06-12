// app/layout.tsx
// Root layout — font loading + metadata global

import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "MyPresensi — TRPL Politani Samarinda",
    template: "%s — MyPresensi",
  },
  description:
    "Sistem presensi digital berbasis Face Recognition dan Geolokasi untuk Prodi TRPL, Politeknik Pertanian Negeri Samarinda.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
      </head>
      <body className="antialiased">{children}</body>
    </html>
  );
}
