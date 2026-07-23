@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem ============================================================
rem  MeteoCarnet Mali - installation en demarrage automatique
rem  (via le Planificateur de taches Windows - aucun outil tiers
rem  a telecharger, tout est deja integre a Windows Server)
rem
rem  A executer UNE SEULE FOIS (clic droit -> Executer en tant
rem  qu'administrateur). Peut etre relance sans risque plus tard,
rem  y compris a chaque mise a jour de l'application : il applique
rem  aussi les changements de base de donnees et redemarre tout,
rem  en un seul script (plus besoin de choisir entre plusieurs .bat).
rem ============================================================

net session >nul 2>nul
if not %errorlevel%==0 (
  echo Ce script doit etre execute EN TANT QU'ADMINISTRATEUR.
  echo Clic droit sur install-service.bat -^> "Executer en tant qu'administrateur".
  echo.
  pause
  exit /b 1
)

cd /d "%~dp0"
set "ROOT=%cd%"
set "SERVERDIR=%ROOT%\server"
set "TASK_NAME=MeteoCarnetMali"

echo ============================================================
echo   MeteoCarnet Mali - installation (demarrage automatique)
echo ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo ERREUR : Node.js est introuvable. Installez-le : https://nodejs.org
  echo puis relancez ce script.
  pause
  exit /b 1
)
set "NODE_EXE="
for /f "delims=" %%N in ('where node') do (
  if not defined NODE_EXE set "NODE_EXE=%%N"
)

if not exist "%SERVERDIR%\.env" (
  echo ERREUR : server\.env introuvable.
  echo Copiez server\.env.example en server\.env et remplissez-le d'abord
  echo ^(voir README.md, section configuration^), puis relancez ce script.
  pause
  exit /b 1
)

if not exist "%SERVERDIR%\node_modules" (
  echo Installation des dependances Node...
  pushd "%SERVERDIR%"
  call npm install
  popd
  if errorlevel 1 (
    echo ERREUR pendant "npm install".
    pause
    exit /b 1
  )
)

mkdir "%ROOT%\logs" 2>nul

rem --- Applique aussi les mises a jour du schema de base de donnees (comme update-app.bat) :
rem     ainsi, relancer CE script suffit toujours a tout remettre a niveau d'un coup, sans
rem     avoir a se demander lequel des deux scripts lancer. ---
set "DB_HOST=localhost"
set "DB_PORT=5432"
set "DB_NAME=meteocarnet"
set "DB_USER=postgres"
set "DB_PASSWORD="
for /f "usebackq tokens=1,2 delims==" %%A in ("%SERVERDIR%\.env") do (
  if /I "%%A"=="DB_HOST" if not "%%B"=="" set "DB_HOST=%%B"
  if /I "%%A"=="DB_PORT" if not "%%B"=="" set "DB_PORT=%%B"
  if /I "%%A"=="DB_NAME" if not "%%B"=="" set "DB_NAME=%%B"
  if /I "%%A"=="DB_USER" if not "%%B"=="" set "DB_USER=%%B"
  if /I "%%A"=="DB_PASSWORD" if not "%%B"=="" set "DB_PASSWORD=%%B"
)
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
  echo ATTENTION : "psql" introuvable ^(pas dans le PATH, ni aux emplacements
  echo habituels d'installation^). La mise a jour du schema de base de donnees
  echo est ignoree pour cette fois ^(le reste de l'installation continue^).
  echo Ouvrez pgAdmin et executez vous-meme server\schema.sql sur la base
  echo "%DB_NAME%" si necessaire ^(sans risque de le rejouer plusieurs fois^).
) else (
  echo Application des mises a jour du schema sur la base "%DB_NAME%"...
  set "PGPASSWORD=%DB_PASSWORD%"
  "%PSQL_EXE%" -h "%DB_HOST%" -p "%DB_PORT%" -U "%DB_USER%" -d "%DB_NAME%" -f "%SERVERDIR%\schema.sql"
  set "PGPASSWORD="
  if errorlevel 1 (
    echo ATTENTION : des erreurs sont survenues pendant la mise a jour du schema
    echo ^(voir le detail ci-dessus^). Verifiez avant de continuer a utiliser
    echo l'application.
  ) else (
    echo Schema a jour.
  )
)
echo.

rem --- Cree le petit script qui lance le serveur avec le bon dossier et les logs ---
> "%ROOT%\run-service.bat" echo @echo off
>> "%ROOT%\run-service.bat" echo cd /d "%SERVERDIR%"
>> "%ROOT%\run-service.bat" echo if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"
>> "%ROOT%\run-service.bat" echo "%NODE_EXE%" server.js ^>^> "%ROOT%\logs\out.log" 2^>^> "%ROOT%\logs\err.log"

rem --- Lecture du port et du mode HTTPS dans .env (pour le pare-feu) ---
set "PORT_VALUE=2000"
set "HTTPS_PORT_VALUE=2443"
set "ENABLE_HTTPS_VALUE=false"
for /f "usebackq tokens=1,2 delims==" %%A in ("%SERVERDIR%\.env") do (
  if /I "%%A"=="PORT" if not "%%B"=="" set "PORT_VALUE=%%B"
  if /I "%%A"=="HTTPS_PORT" if not "%%B"=="" set "HTTPS_PORT_VALUE=%%B"
  if /I "%%A"=="ENABLE_HTTPS" if not "%%B"=="" set "ENABLE_HTTPS_VALUE=%%B"
)

rem --- Genere le script PowerShell qui (re)cree la tache planifiee ---
> "%ROOT%\_install-task.ps1" echo $ErrorActionPreference = 'Stop'
>> "%ROOT%\_install-task.ps1" echo Unregister-ScheduledTask -TaskName '%TASK_NAME%' -Confirm:$false -ErrorAction SilentlyContinue
>> "%ROOT%\_install-task.ps1" echo $action = New-ScheduledTaskAction -Execute '%ROOT%\run-service.bat' -WorkingDirectory '%ROOT%'
>> "%ROOT%\_install-task.ps1" echo $trig1 = New-ScheduledTaskTrigger -AtStartup
>> "%ROOT%\_install-task.ps1" echo $trig1.Delay = 'PT30S'
>> "%ROOT%\_install-task.ps1" echo $trig2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
>> "%ROOT%\_install-task.ps1" echo $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
>> "%ROOT%\_install-task.ps1" echo $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
>> "%ROOT%\_install-task.ps1" echo Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger @($trig1,$trig2) -Settings $settings -Principal $principal -Description 'MeteoCarnet Mali - serveur web Node.js (port %PORT_VALUE%)' -Force ^| Out-Null
>> "%ROOT%\_install-task.ps1" echo Start-ScheduledTask -TaskName '%TASK_NAME%'

echo Creation de la tache planifiee "%TASK_NAME%"...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\_install-task.ps1"
if errorlevel 1 (
  echo.
  echo ERREUR lors de la creation de la tache planifiee ^(voir message ci-dessus^).
  pause
  exit /b 1
)
del "%ROOT%\_install-task.ps1" >nul 2>nul

rem --- Tache de surveillance active : verifie que le site REPOND vraiment (pas juste
rem     que le processus existe) toutes les 3 minutes, et force un redemarrage sinon.
rem     C'est ce qui manquait pour detecter un serveur "vivant" mais fige. ---
> "%ROOT%\_install-watchdog.ps1" echo $ErrorActionPreference = 'Stop'
>> "%ROOT%\_install-watchdog.ps1" echo Unregister-ScheduledTask -TaskName 'MeteoCarnetMali-Watchdog' -Confirm:$false -ErrorAction SilentlyContinue
>> "%ROOT%\_install-watchdog.ps1" echo $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "%ROOT%\watchdog.ps1"' -WorkingDirectory '%ROOT%'
>> "%ROOT%\_install-watchdog.ps1" echo $trigBoot = New-ScheduledTaskTrigger -AtStartup
>> "%ROOT%\_install-watchdog.ps1" echo $trigBoot.Delay = 'PT90S'
>> "%ROOT%\_install-watchdog.ps1" echo $trig = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 3) -RepetitionDuration (New-TimeSpan -Days 3650)
>> "%ROOT%\_install-watchdog.ps1" echo $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
>> "%ROOT%\_install-watchdog.ps1" echo $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
>> "%ROOT%\_install-watchdog.ps1" echo Register-ScheduledTask -TaskName 'MeteoCarnetMali-Watchdog' -Action $action -Trigger @($trigBoot,$trig) -Settings $settings -Principal $principal -Description 'MeteoCarnet Mali - verifie que le serveur repond, le redemarre sinon' -Force ^| Out-Null

echo Creation de la surveillance active "MeteoCarnetMali-Watchdog"...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\_install-watchdog.ps1"
if errorlevel 1 (
  echo.
  echo ATTENTION : la surveillance active n'a pas pu etre installee ^(voir message
  echo ci-dessus^). Le redemarrage automatique en cas de plantage reste actif,
  echo mais pas la detection d'un serveur fige. Vous pouvez relancer ce script.
) else (
  del "%ROOT%\_install-watchdog.ps1" >nul 2>nul
)

rem --- Pare-feu Windows : ouvre le(s) port(s) pour un acces depuis toutes les machines du reseau ---
netsh advfirewall firewall delete rule name="MeteoCarnetMali-%PORT_VALUE%" >nul 2>nul
netsh advfirewall firewall add rule name="MeteoCarnetMali-%PORT_VALUE%" dir=in action=allow protocol=TCP localport=%PORT_VALUE% >nul
echo Port %PORT_VALUE% ouvert dans le pare-feu Windows (TCP entrant, toutes machines du reseau).
if /I "%ENABLE_HTTPS_VALUE%"=="true" (
  netsh advfirewall firewall delete rule name="MeteoCarnetMali-%HTTPS_PORT_VALUE%" >nul 2>nul
  netsh advfirewall firewall add rule name="MeteoCarnetMali-%HTTPS_PORT_VALUE%" dir=in action=allow protocol=TCP localport=%HTTPS_PORT_VALUE% >nul
  echo Port %HTTPS_PORT_VALUE% ^(HTTPS^) ouvert dans le pare-feu Windows.
)

echo.
echo ============================================================
echo   Termine !
echo ============================================================
echo La tache planifiee "%TASK_NAME%" est installee et le serveur est demarre.
echo   - Demarre automatiquement au demarrage de Windows (meme sans session ouverte).
echo   - Un controle toutes les 5 minutes relance automatiquement le serveur
echo     s'il s'est arrete ou a plante (pas besoin d'attendre un redemarrage).
echo   - Une surveillance active verifie en plus, toutes les 3 minutes, que le
echo     site REPOND vraiment (pas juste que le processus existe) et force un
echo     redemarrage si le serveur reste "fige" sans avoir plante. Journal :
echo     %ROOT%\logs\watchdog.log
echo.
echo   -^> Depuis ce serveur               : http://localhost:%PORT_VALUE%
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /R /C:"IPv4"') do (
  set "IP=%%I"
  set "IP=!IP: =!"
  echo   -^> Depuis un autre poste du reseau : http://!IP!:%PORT_VALUE%
)
echo.
echo Gestion : ouvrez "Planificateur de taches" ^(taskschd.msc^), cherchez
echo "%TASK_NAME%", ou utilisez les scripts fournis : stop-service.bat /
echo restart-service.bat / view-logs.bat / uninstall-service.bat / service-status.bat
echo Journaux : %ROOT%\logs\out.log et %ROOT%\logs\err.log
echo.
pause
