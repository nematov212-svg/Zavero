/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        zavero: {
          red: '#EF4444',
          redHover: '#DC2626',
          redDark: '#B91C1C',
          darkBg: '#090B12',
          darkSurface: '#0F1424',
          darkCard: '#151C32',
          lightBg: '#F8FAFC',
          lightSurface: '#FFFFFF',
          lightCard: '#F1F5F9',
          borderDark: 'rgba(255, 255, 255, 0.08)',
          borderLight: 'rgba(0, 0, 0, 0.08)',
        }
      },
      fontFamily: {
        sans: ['Plus Jakarta Sans', 'Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-8px)' },
        },
      }
    },
  },
  plugins: [],
}
