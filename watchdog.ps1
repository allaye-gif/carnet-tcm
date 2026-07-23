$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir 'watchdog.log'

function Write-Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logFile -Value $line
}

$port = 9555
$envFile = Join-Path $root 'server\.env'
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*PORT\s*=\s*(.+?)\s*$') { $port = $Matches[1] }
    }
}

try {
    # "/" (page de connexion, servie par express.static) ne demande pas de session,
    # contrairement a "/api/health" qui est derriere l'authentification - important
    # pour que cette verification marche pour un visiteur anonyme comme ce script.
    $resp = Invoke-WebRequest -Uri "http://localhost:$port/" -UseBasicParsing -TimeoutSec 10
    if ($resp.StatusCode -eq 200) { exit 0 }
    Write-Log "Reponse HTTP inattendue ($($resp.StatusCode)) - redemarrage."
} catch {
    Write-Log "Le site ne repond pas ($($_.Exception.Message)) - redemarrage."
}

try {
    Stop-ScheduledTask -TaskName 'MeteoCarnetMali' -ErrorAction SilentlyContinue
    Get-Process node -ErrorAction SilentlyContinue |
        Where-Object { (Get-CimInstance Win32_Process -Filter ("ProcessId = " + $_.Id)).CommandLine -like '*server.js*' } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-ScheduledTask -TaskName 'MeteoCarnetMali'
    Write-Log "Tache 'MeteoCarnetMali' redemarree."
} catch {
    Write-Log "ECHEC du redemarrage : $($_.Exception.Message)"
}
