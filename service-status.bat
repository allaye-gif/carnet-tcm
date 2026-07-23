@echo off
chcp 65001 >nul
setlocal
sc query MeteoCarnetMali
echo.
echo (RUNNING = en fonctionnement. STOPPED = arrete. Si le service
echo  n'existe pas, executez d'abord install-service.bat.)
pause
