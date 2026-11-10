@echo off
chcp 65001 >nul
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Install it from https://nodejs.org
  pause
  exit /b 1
)

if not exist "tools\fcm_server.mjs" (
  echo tools\fcm_server.mjs was not found.
  pause
  exit /b 1
)

node "tools\fcm_server.mjs"
pause