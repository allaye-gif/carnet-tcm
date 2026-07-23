@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
echo ===== Dernieres lignes de logs\out.log =====
if exist "logs\out.log" (powershell -NoProfile -Command "Get-Content -Path 'logs\out.log' -Tail 40") else (echo (pas encore de fichier out.log)
)
echo.
echo ===== Dernieres lignes de logs\err.log =====
if exist "logs\err.log" (powershell -NoProfile -Command "Get-Content -Path 'logs\err.log' -Tail 40") else (echo (pas encore de fichier err.log)
)
echo.
pause
