import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "sans-serif"],
        heading: ["Plus Jakarta Sans", "sans-serif"],
        mono: ["JetBrains Mono", "monospace"],
      },
      colors: {
        // Warna — Politani Web (extracted dari politanisamarinda.ac.id)
        primary: {
          DEFAULT: "#2D86FF",
          hover: "#1E70E0",
          dark: "#0D2C5E",
          subtle: "rgba(45,134,255,0.10)",
        },
        // Accent — Gold pita logo Politani
        accent: {
          DEFAULT: "#F4B400",
          subtle: "rgba(244,180,0,0.12)",
        },
        surface: "#FFFFFF",
        background: "#F4F6F8",
        border: "#E2E6EA",
        "text-primary": "#1C2024",
        "text-secondary": "#636C76",
        // Naik dari #AEB4BB (2.34:1) ke #757B82 (4.55:1 vs white) — WCAG AA pass
        "text-disabled": "#757B82",
        success: {
          DEFAULT: "#1A7F37",
          subtle: "rgba(26,127,55,0.08)",
        },
        warning: {
          DEFAULT: "#9A6700",
          subtle: "rgba(154,103,0,0.08)",
        },
        danger: {
          DEFAULT: "#CF222E",
          subtle: "rgba(207,34,46,0.08)",
        },
      },
      borderRadius: {
        card: "16px",
        button: "999px",
        input: "8px",
      },
      boxShadow: {
        card: "0 2px 8px rgba(0, 0, 0, 0.06)",
        "card-hover": "0 4px 16px rgba(0, 0, 0, 0.10)",
        primary: "0 4px 12px rgba(45, 134, 255, 0.35)",
      },
    },
  },
  plugins: [],
};

export default config;
