@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "NSSM=%~dp0tools\nssm.exe"
if not exist "%NSSM%" (
  echo NSSM introuvable - installez d'abord le service avec install-service.bat
  pause
  exit /b 1
)
echo Arret du service MeteoCarnetMali...
"%NSSM%" stop MeteoCarnetMali
echo Fait. (Pour le redemarrer : restart-service.bat, ou services.msc)
pause
