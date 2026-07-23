@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

net session >nul 2>nul
if not %errorlevel%==0 (
  echo Ce script doit etre execute EN TANT QU'ADMINISTRATEUR.
  echo Clic droit sur stop-service.bat -^> "Executer en tant qu'administrateur".
  pause
  exit /b 1
)

echo Arret de MeteoCarnet Mali...
powershell -NoProfile -Command "Stop-ScheduledTask -TaskName 'MeteoCarnetMali' -ErrorAction SilentlyContinue; Get-Process node -ErrorAction SilentlyContinue | Where-Object { (Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $_.Id)).CommandLine -like '*server.js*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
echo Fait. (Pour le redemarrer : restart-service.bat, ou le Planificateur de taches)
pause
