@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0server"

echo ============================================================
echo   MeteoCarnet Mali - demarrage
echo ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo ERREUR : Node.js est introuvable sur ce serveur.
  echo Installez-le depuis https://nodejs.org puis relancez ce script.
  echo.
  pause
  exit /b 1
)

if not exist ".env" (
  echo ERREUR : le fichier .env est introuvable dans le dossier "server".
  echo Copiez ".env.example" en ".env" et remplissez vos identifiants PostgreSQL.
  echo.
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo Installation des dependances Node - premiere fois seulement, patientez...
  call npm install
  if errorlevel 1 (
    echo ERREUR pendant "npm install" - voir le message ci-dessus.
    echo.
    pause
    exit /b 1
  )
  echo Installation terminee.
  echo.
)

rem --- Lit le port choisi dans .env (par defaut 2000 si absent) ---
set "PORT_VALUE=2000"
for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
  if /I "%%A"=="PORT" if not "%%B"=="" set "PORT_VALUE=%%B"
)

rem --- Ouvre le port dans le pare-feu Windows si ce script tourne en Administrateur ---
net session >nul 2>nul
if %errorlevel%==0 (
  netsh advfirewall firewall show rule name="MeteoCarnetMali-%PORT_VALUE%" >nul 2>nul
  if errorlevel 1 (
    echo Ouverture du port %PORT_VALUE% dans le pare-feu Windows...
    netsh advfirewall firewall add rule name="MeteoCarnetMali-%PORT_VALUE%" dir=in action=allow protocol=TCP localport=%PORT_VALUE% >nul
  )
) else (
  echo ATTENTION : ce script n'est pas lance en Administrateur, le port %PORT_VALUE%
  echo n'a donc pas pu etre ouvert automatiquement dans le pare-feu Windows.
  echo Relancez-le une fois via clic-droit -^> "Executer en tant qu'administrateur"
  echo pour que ce soit fait automatiquement ^(ou ouvrez-le manuellement^).
)
echo.

echo Demarrage du serveur...
echo   -^> Depuis ce serveur               : http://localhost:%PORT_VALUE%
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /R /C:"IPv4"') do (
  set "IP=%%I"
  set "IP=!IP: =!"
  echo   -^> Depuis un autre poste du reseau : http://!IP!:%PORT_VALUE%
)
echo.

node server.js

echo.
echo Le serveur s'est arrete. Si un message d'erreur est affiche ci-dessus,
echo copiez-le tel quel pour le faire corriger.
echo.
echo ------------------------------------------------------------
echo IMPORTANT : cette fenetre doit rester ouverte pour que le site
echo reste accessible. Si vous fermez la fenetre ou redemarrez le
echo serveur, le site s'arrete.
echo.
echo Pour que l'application demarre TOUTE SEULE au demarrage de
echo Windows et se relance automatiquement en cas de plantage,
echo executez UNE SEULE FOIS "install-service.bat" en tant
echo qu'administrateur (installation en service Windows).
echo ------------------------------------------------------------
pause
