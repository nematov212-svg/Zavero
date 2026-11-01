@echo off
title ZAVERO POS - PRINT AGENT
cd /d "%~dp0"

echo ==========================================
echo       ZAVERO POS - PRINT AGENT            
echo ==========================================

if not exist node_modules (
  echo [INFO] Kerakli kutubxonalar o'rnatilmoqda (npm install)...
  call npm install --production
)

echo [INFO] Print Agent ishga tushirilmoqda (http://localhost:9101)...
node src/server.js
pause
