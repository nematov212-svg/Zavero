#!/bin/bash
cd "$(dirname "$0")"

echo "=========================================="
echo "      ZAVERO POS - PRINT AGENT            "
echo "=========================================="

if [ ! -d "node_modules" ]; then
  echo "📦 Kerakli kutubxonalar o'rnatilmoqda (npm install)..."
  npm install --production
fi

echo "🚀 Print Agent ishga tushirilmoqda (http://localhost:9101)..."
node src/server.js
