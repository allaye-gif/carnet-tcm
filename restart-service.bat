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
echo Redemarrage du service MeteoCarnetMali...
"%NSSM%" restart MeteoCarnetMali
echo Fait.
pause
