@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

powershell -NoProfile -Command "$t = Get-ScheduledTask -TaskName 'MeteoCarnetMali' -ErrorAction SilentlyContinue; if (-not $t) { Write-Host 'Tache planifiee introuvable - executez install-service.bat.'; exit }; $i = Get-ScheduledTaskInfo -TaskName 'MeteoCarnetMali'; Write-Host ('Etat                : ' + $t.State); Write-Host ('Derniere execution  : ' + $i.LastRunTime); Write-Host ('Dernier resultat    : ' + $i.LastTaskResult)"

echo.
echo (RUNNING = en fonctionnement. Si l'etat semble bon mais que le site ne
echo  repond pas, regardez logs\watchdog.log et logs\err.log.)
pause
