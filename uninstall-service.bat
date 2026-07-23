@echo off
chcp 65001 >nul
setlocal

net session >nul 2>nul
if not %errorlevel%==0 (
  echo Ce script doit etre execute EN TANT QU'ADMINISTRATEUR.
  pause
  exit /b 1
)

cd /d "%~dp0"
set "SERVICE_NAME=MeteoCarnetMali"
set "NSSM=%~dp0tools\nssm.exe"

if not exist "%NSSM%" (
  echo NSSM introuvable ^(%NSSM%^) - le service n'a peut-etre jamais ete installe.
  pause
  exit /b 1
)

echo Arret et suppression du service "%SERVICE_NAME%"...
"%NSSM%" stop %SERVICE_NAME% >nul 2>nul
"%NSSM%" remove %SERVICE_NAME% confirm

echo.
echo (Les regles de pare-feu ne sont pas supprimees automatiquement. Pour les
echo  retirer si besoin : Pare-feu Windows Defender avec fonctions avancees de
echo  securite -^> Regles de trafic entrant -^> supprimez celles nommees
echo  "MeteoCarnetMali-...")
echo.
echo Service supprime.
pause
