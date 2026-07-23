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

rem ------------------------------------------------------------
rem  Charge la configuration existante (server\.env), si presente,
rem  sinon utilise des valeurs par defaut. Rien ici n'est fige sur
rem  une machine en particulier : mot de passe demande une seule
rem  fois si inconnu, puis retenu dans .env pour les fois suivantes.
rem ------------------------------------------------------------
set "DB_HOST_VAL=localhost"
set "DB_PORT_VAL=5432"
set "DB_USER_VAL=postgres"
set "DB_NAME_VAL=meteocarnet"
set "DB_PASSWORD_VAL="
set "PORT_VAL=9555"
set "SESSION_SECRET_VAL="
set "ENABLE_HTTPS_VAL=false"
set "HTTPS_PORT_VAL=9556"
set "ADMIN_USERNAME_VAL="
set "ADMIN_PASSWORD_VAL="
set "ANTHROPIC_API_KEY_VAL="

if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if /I "%%A"=="DB_HOST"          set "DB_HOST_VAL=%%B"
    if /I "%%A"=="DB_PORT"          set "DB_PORT_VAL=%%B"
    if /I "%%A"=="DB_USER"          set "DB_USER_VAL=%%B"
    if /I "%%A"=="DB_NAME"          set "DB_NAME_VAL=%%B"
    if /I "%%A"=="DB_PASSWORD"      set "DB_PASSWORD_VAL=%%B"
    if /I "%%A"=="PORT"             set "PORT_VAL=%%B"
    if /I "%%A"=="SESSION_SECRET"   set "SESSION_SECRET_VAL=%%B"
    if /I "%%A"=="ENABLE_HTTPS"     set "ENABLE_HTTPS_VAL=%%B"
    if /I "%%A"=="HTTPS_PORT"       set "HTTPS_PORT_VAL=%%B"
    if /I "%%A"=="ADMIN_USERNAME"   set "ADMIN_USERNAME_VAL=%%B"
    if /I "%%A"=="ADMIN_PASSWORD"   set "ADMIN_PASSWORD_VAL=%%B"
    if /I "%%A"=="ANTHROPIC_API_KEY" set "ANTHROPIC_API_KEY_VAL=%%B"
  )
)
if "!SESSION_SECRET_VAL!"=="" set "SESSION_SECRET_VAL=mc!RANDOM!!RANDOM!!RANDOM!!RANDOM!"

rem ------------------------------------------------------------
rem  Localise psql (installation PostgreSQL 14 a 18), puis s'assure
rem  que la base et les tables existent - a chaque lancement, sans
rem  jamais rien supprimer (schema.sql ne fait que CREATE ... IF NOT
rem  EXISTS / ALTER ... ADD COLUMN IF NOT EXISTS).
rem ------------------------------------------------------------
set "PSQL="
where psql >nul 2>nul && set "PSQL=psql"
if not defined PSQL (
  for %%v in (18 17 16 15 14) do (
    if not defined PSQL if exist "C:\Program Files\PostgreSQL\%%v\bin\psql.exe" set "PSQL=C:\Program Files\PostgreSQL\%%v\bin\psql.exe"
  )
)

if not defined PSQL (
  echo ATTENTION : "psql" introuvable - impossible de verifier/creer la base
  echo automatiquement. Installez PostgreSQL, ou creez la base "!DB_NAME_VAL!"
  echo et importez server\schema.sql vous-meme dans pgAdmin.
  echo.
) else (
  if not defined DB_PASSWORD_VAL (
    echo.
    set /p "DB_PASSWORD_VAL=Mot de passe PostgreSQL pour l'utilisateur !DB_USER_VAL! : "
  )
  set "PGPASSWORD=!DB_PASSWORD_VAL!"
  "%PSQL%" -h !DB_HOST_VAL! -p !DB_PORT_VAL! -U !DB_USER_VAL! -d postgres -tc "SELECT 1;" >nul 2>nul
  if errorlevel 1 (
    echo.
    echo Connexion PostgreSQL impossible avec la configuration actuelle.
    set /p "DB_PASSWORD_VAL=Mot de passe PostgreSQL pour l'utilisateur !DB_USER_VAL! : "
    set "PGPASSWORD=!DB_PASSWORD_VAL!"
    "%PSQL%" -h !DB_HOST_VAL! -p !DB_PORT_VAL! -U !DB_USER_VAL! -d postgres -tc "SELECT 1;" >nul 2>nul
    if errorlevel 1 (
      echo.
      echo [ERREUR] Connexion PostgreSQL impossible avec ce mot de passe.
      echo Verifiez DB_HOST/DB_PORT/DB_USER dans server\.env si besoin.
      echo.
      pause
      exit /b 1
    )
  )

  "%PSQL%" -h !DB_HOST_VAL! -p !DB_PORT_VAL! -U !DB_USER_VAL! -tc "SELECT 1 FROM pg_database WHERE datname='!DB_NAME_VAL!'" postgres 2>nul | findstr "1" >nul
  if errorlevel 1 (
    echo Creation de la base "!DB_NAME_VAL!"...
    "%PSQL%" -h !DB_HOST_VAL! -p !DB_PORT_VAL! -U !DB_USER_VAL! -c "CREATE DATABASE !DB_NAME_VAL! ENCODING 'UTF8' TEMPLATE=template0;" postgres
    if errorlevel 1 (
      echo [ERREUR] Impossible de creer la base "!DB_NAME_VAL!".
      pause
      exit /b 1
    )
  )

  echo Verification/mise a jour des tables sur "!DB_NAME_VAL!"...
  "%PSQL%" -h !DB_HOST_VAL! -p !DB_PORT_VAL! -U !DB_USER_VAL! -d !DB_NAME_VAL! -f "schema.sql" >nul
  set "PGPASSWORD="
  echo [OK] Base de donnees prete.
  echo.
)

rem ------------------------------------------------------------
rem  (Re)ecrit server\.env a partir des valeurs resolues ci-dessus.
rem  Jamais destructeur pour les donnees (ne touche pas a PostgreSQL),
rem  juste le fichier de configuration.
rem ------------------------------------------------------------
(
  echo PORT=!PORT_VAL!
  echo SESSION_SECRET=!SESSION_SECRET_VAL!
  echo.
  echo DB_HOST=!DB_HOST_VAL!
  echo DB_PORT=!DB_PORT_VAL!
  echo DB_USER=!DB_USER_VAL!
  echo DB_PASSWORD=!DB_PASSWORD_VAL!
  echo DB_NAME=!DB_NAME_VAL!
  echo.
  echo ENABLE_HTTPS=!ENABLE_HTTPS_VAL!
  echo HTTPS_PORT=!HTTPS_PORT_VAL!
  echo.
  echo ADMIN_USERNAME=!ADMIN_USERNAME_VAL!
  echo ADMIN_PASSWORD=!ADMIN_PASSWORD_VAL!
  echo ANTHROPIC_API_KEY=!ANTHROPIC_API_KEY_VAL!
) > .env

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

set "PORT_VALUE=!PORT_VAL!"

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
echo qu'administrateur (installation en tache planifiee Windows).
echo ------------------------------------------------------------
pause
