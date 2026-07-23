@echo off
chcp 65001 >nul
setlocal

net session >nul 2>nul
if not %errorlevel%==0 (
  echo Ce script doit etre execute EN TANT QU'ADMINISTRATEUR.
  echo Clic droit sur uninstall-service.bat -^> "Executer en tant qu'administrateur".
  pause
  exit /b 1
)

cd /d "%~dp0"

echo Arret et suppression des taches planifiees "MeteoCarnetMali"...
powershell -NoProfile -Command "Stop-ScheduledTask -TaskName 'MeteoCarnetMali' -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'MeteoCarnetMali' -Confirm:$false -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'MeteoCarnetMali-Watchdog' -Confirm:$false -ErrorAction SilentlyContinue; Get-Process node -ErrorAction SilentlyContinue | Where-Object { (Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $_.Id)).CommandLine -like '*server.js*' } | Stop-Process -Force -ErrorAction SilentlyContinue"

echo.
echo (Les regles de pare-feu ne sont pas supprimees automatiquement. Pour les
echo  retirer si besoin : Pare-feu Windows Defender avec fonctions avancees de
echo  securite -^> Regles de trafic entrant -^> supprimez celles nommees
echo  "MeteoCarnetMali-...")
echo.
echo Taches planifiees supprimees.
pause
