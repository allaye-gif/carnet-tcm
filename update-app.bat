@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================================
echo   MeteoCarnet Mali - mise a jour
echo   (base de donnees + dependances + redemarrage, en un clic)
echo ============================================================
echo.
echo A faire AVANT de lancer ce script : remplacer les fichiers fournis
echo (server\server.js, server\schema.sql, public\index.html, etc.) par
echo les nouvelles versions. Ce script s'occupe du reste.
echo.

if not exist "server\.env" (
  echo ERREUR : server\.env introuvable. Rien a faire.
  pause
  exit /b 1
)

rem --- Lit les parametres de connexion PostgreSQL depuis server\.env ---
set "DB_HOST=localhost"
set "DB_PORT=5432"
set "DB_NAME=meteocarnet"
set "DB_USER=postgres"
set "DB_PASSWORD="
for /f "usebackq tokens=1,2 delims==" %%A in ("server\.env") do (
  if /I "%%A"=="DB_HOST" if not "%%B"=="" set "DB_HOST=%%B"
  if /I "%%A"=="DB_PORT" if not "%%B"=="" set "DB_PORT=%%B"
  if /I "%%A"=="DB_NAME" if not "%%B"=="" set "DB_NAME=%%B"
  if /I "%%A"=="DB_USER" if not "%%B"=="" set "DB_USER=%%B"
  if /I "%%A"=="DB_PASSWORD" if not "%%B"=="" set "DB_PASSWORD=%%B"
)

rem --- Cherche "psql" tout seul (PATH, puis emplacements habituels d'installation) :
rem     vous n'avez rien a configurer, ce script se debrouille seul. ---
set "PSQL_EXE="
for /f "delims=" %%W in ('where psql 2^>nul') do if not defined PSQL_EXE set "PSQL_EXE=%%W"
if not defined PSQL_EXE (
  for /f "delims=" %%D in ('dir /b /ad /o-n "C:\Program Files\PostgreSQL" 2^>nul') do (
    if not defined PSQL_EXE if exist "C:\Program Files\PostgreSQL\%%D\bin\psql.exe" set "PSQL_EXE=C:\Program Files\PostgreSQL\%%D\bin\psql.exe"
  )
)
if not defined PSQL_EXE (
  for /f "delims=" %%D in ('dir /b /ad /o-n "C:\Program Files (x86)\PostgreSQL" 2^>nul') do (
    if not defined PSQL_EXE if exist "C:\Program Files (x86)\PostgreSQL\%%D\bin\psql.exe" set "PSQL_EXE=C:\Program Files (x86)\PostgreSQL\%%D\bin\psql.exe"
  )
)

if not defined PSQL_EXE (
  echo ATTENTION : le programme "psql" de PostgreSQL n'a pas ete trouve
  echo automatiquement sur ce serveur. La mise a jour de la base de donnees
  echo est ignoree pour cette fois ^(le reste continue normalement^).
  echo Signalez-le-moi si ca se reproduit, je vous donnerai l'emplacement
  echo exact a verifier.
  echo.
  goto :restart
)

echo Application des mises a jour du schema sur la base "%DB_NAME%"...
echo ^(sans danger : chaque instruction de schema.sql verifie avant d'agir,
echo  rien n'est jamais recree ni ecrase si ca existe deja^)
set "PGPASSWORD=%DB_PASSWORD%"
"%PSQL_EXE%" -h "%DB_HOST%" -p "%DB_PORT%" -U "%DB_USER%" -d "%DB_NAME%" -f "server\schema.sql"
set "PGPASSWORD="
if errorlevel 1 (
  echo.
  echo ATTENTION : des erreurs sont survenues pendant la mise a jour du schema
  echo ^(voir le detail juste au-dessus^). Verifiez avant de continuer utiliser
  echo l'application.
  pause
) else (
  echo Schema a jour.
)
echo.

:restart
if not exist "server\node_modules" (
  echo Installation des dependances Node ^(premiere fois ou nouvelles
  echo dependances ajoutees^)...
  pushd server
  call npm install
  popd
  echo.
)

echo Redemarrage du serveur...
net session >nul 2>nul
if %errorlevel%==0 (
  powershell -NoProfile -Command "Stop-ScheduledTask -TaskName 'MeteoCarnetMali' -ErrorAction SilentlyContinue; Get-Process node -ErrorAction SilentlyContinue | Where-Object { (Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $_.Id)).CommandLine -like '*server.js*' } | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; Start-ScheduledTask -TaskName 'MeteoCarnetMali'"
  echo Fait - le service a ete redemarre avec la nouvelle version.
) else (
  echo.
  echo Ce script n'est pas lance en administrateur : impossible de redemarrer
  echo automatiquement le service Windows.
  echo -^> Relancez "update-app.bat" en tant qu'administrateur ^(clic droit^),
  echo    OU si vous utilisez encore start.bat manuellement : fermez sa
  echo    fenetre et relancez-le.
)
echo.
pause
