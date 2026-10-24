[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Start','Stop','Restart','Status')][string]$Action,
 [Alias('SansNavigateur')][switch]$NoBrowser,
 [switch]$NoPause,
 [switch]$Reseau
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$BackendRoot=Join-Path $ProjectRoot 'backend'
$FrontendRoot=Join-Path $ProjectRoot 'frontend'
$RuntimeRoot=Join-Path $ProjectRoot '.runtime'
$StatePath=Join-Path $RuntimeRoot 'services.json'
$ServiceScript=Join-Path $PSScriptRoot 'sauverndeko-service.ps1'
$PythonExecutable=Join-Path $BackendRoot '.venv\Scripts\python.exe'
$ManagePath=Join-Path $BackendRoot 'manage.py'
$VitePath=Join-Path $FrontendRoot 'node_modules\vite\bin\vite.js'

function Step([string]$Text) { Write-Host ('[SauverNdeko] '+$Text) }
function Read-State {
 if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
 $State=Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
 if ($State.version -ne 1 -or $State.project_root -ne $ProjectRoot) { throw 'Etat de lancement etranger ou ancien : aucun processus ne sera arrete.' }
 return $State
}
function Save-State($State) {
 $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}
function Process-Info([int]$ProcessId) {
 return Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
}
function Expected-Process($Record) {
 if ($null -eq $Record) { return $false }
 $Info=Process-Info ([int]$Record.pid)
 if ($null -eq $Info) { return $false }
 $Command=[string]$Info.CommandLine
 return ($Command.IndexOf($ServiceScript,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and
         $Command.Contains([string]$Record.instance) -and
         $Info.CreationDate.ToUniversalTime().ToString('o') -eq [string]$Record.created)
}
function Stop-ServiceRecord($Record) {
 if (-not (Expected-Process $Record)) { Step ('Processus '+$Record.name+' deja absent ou identite non correspondante ; aucun arret force.'); return }
 function Stop-Children([int]$ParentProcessId) {
  $Children=@(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentProcessId" -ErrorAction SilentlyContinue)
  foreach ($Child in $Children) {
   Stop-Children ([int]$Child.ProcessId)
   # Verifier la date avant l'arret pour ne pas prendre un PID recycle.
   $Current=Process-Info ([int]$Child.ProcessId)
   if ($null -ne $Current -and $Current.CreationDate -eq $Child.CreationDate) { Stop-Process -Id ([int]$Child.ProcessId) -Force -ErrorAction SilentlyContinue }
  }
 }
 Stop-Children ([int]$Record.pid)
 if (Expected-Process $Record) { Stop-Process -Id ([int]$Record.pid) -Force -ErrorAction SilentlyContinue }
 Step ($Record.name+' arrete.')
}
function Port-InUse([int]$Port) {
 return @([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object {$_.Port -eq $Port}).Count -gt 0
}
function Free-Port([int]$Preferred) {
 for ($Candidate=$Preferred;$Candidate -lt $Preferred+30;$Candidate++) { if (-not (Port-InUse $Candidate)) { return $Candidate } }
 throw "Aucun port disponible a partir de $Preferred. Les programmes existants sont conserves."
}
function Http-Ready([string]$Url) {
 try { return (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { return $false }
}
function Wait-Service([string]$Url,$Record) {
 $Deadline=[DateTime]::UtcNow.AddSeconds(25)
 do {
  if (Http-Ready $Url) { return }
  if (-not (Expected-Process $Record)) { throw ('Le service '+$Record.name+' s''est arrete. Consulter .runtime\'+$Record.name+'-'+$Record.port+'.err.log.') }
  Start-Sleep -Milliseconds 250
 } while ([DateTime]::UtcNow -lt $Deadline)
 throw ('Le service ne repond pas : '+$Url+'. Consulter les journaux .runtime.')
}
function Network-Option([string]$Name,[string]$Default) {
 $Value=[Environment]::GetEnvironmentVariable($Name,'Process')
 if ($null -ne $Value) { return $Value.Trim() }
 $EnvPath=Join-Path $BackendRoot '.env'
 if (Test-Path -LiteralPath $EnvPath) {
  foreach ($Line in Get-Content -LiteralPath $EnvPath -Encoding UTF8) {
   if ($Line -match ('^\s*'+[regex]::Escape($Name)+'\s*=\s*(.*?)\s*$')) { $Value=$Matches[1].Trim().Trim('"').Trim("'") }
  }
 }
 if ($null -eq $Value) { return $Default }; return $Value
}
function Network-Settings {
 $Mode=if ($Reseau) {'lan'} else {(Network-Option 'SAUVERNDEKO_NETWORK_MODE' 'local').ToLowerInvariant()}
 if ($Mode -notin @('local','lan')) { throw 'SAUVERNDEKO_NETWORK_MODE doit valoir local ou lan.' }
 $Hosts=@([Net.Dns]::GetHostName().ToLowerInvariant())
 $Domain=[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
 if ($Domain) { $Hosts+=($Hosts[0]+'.'+$Domain).ToLowerInvariant() }
 $Alias=Network-Option 'SAUVERNDEKO_NETWORK_ALIAS' ''
 if ($Alias) {
  if ($Alias -notmatch '^[a-zA-Z0-9](?:[a-zA-Z0-9.-]{0,251}[a-zA-Z0-9])?$' -or $Alias.Contains('..')) { throw 'Alias reseau invalide : nom DNS exact attendu.' }
  $Hosts+=$Alias.ToLowerInvariant()
 }
 return [pscustomobject]@{mode=$Mode;bind=if($Mode -eq 'lan'){'0.0.0.0'}else{'127.0.0.1'};hosts=($Hosts | Sort-Object -Unique) -join ','}
}
function Show-Addresses($State) {
 $Port=if ($null -ne $State) {[int]$State.frontend_port} else {5173}
 $Lines=@('SauverNdeko',('Sur ce PC : http://localhost:'+ $Port +'/'))
 $Active=$null -ne $State -and @($State.services | Where-Object {Expected-Process $_}).Count -gt 0
 if ($Active -and $State.network_mode -eq 'lan') {
  $Lines+='Acces sur le meme reseau :'
  foreach ($Adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
   if ($Adapter.OperationalStatus -ne 'Up' -or $Adapter.NetworkInterfaceType -eq 'Loopback') { continue }
   foreach ($Entry in $Adapter.GetIPProperties().UnicastAddresses) {
    if ($Entry.Address.AddressFamily -ne 'InterNetwork') { continue }
    $Bytes=$Entry.Address.GetAddressBytes()
    if ($Bytes[0] -eq 10 -or ($Bytes[0] -eq 172 -and $Bytes[1] -ge 16 -and $Bytes[1] -le 31) -or ($Bytes[0] -eq 192 -and $Bytes[1] -eq 168)) { $Lines+='  http://'+$Entry.Address.IPAddressToString+':'+$Port+'/' }
   }
  }
  foreach ($Name in ([string]$State.network_hosts).Split(',')) { $Lines+='Nom du PC ou alias DNS : http://'+$Name+':'+$Port+'/' }
 } elseif ($Active) { $Lines+='Acces local. Pour le reseau : redemarrer.bat -Reseau' }
 else { $Lines+='Application arretee. Lancer demarrer.bat ; ajouter -Reseau pour le reseau local.' }
 $Lines | ForEach-Object {Write-Host $_}
 New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
 $Lines | Set-Content -LiteralPath (Join-Path $RuntimeRoot 'acces-reseau.txt') -Encoding UTF8
}
function Initialize-Python {
 if (-not (Test-Path -LiteralPath $PythonExecutable)) {
  $Py=Get-Command py.exe -ErrorAction SilentlyContinue
  if ($null -eq $Py) { throw 'Installer Python 3.12 puis relancer demarrer.bat.' }
  Step 'Creation de backend/.venv...'
  & $Py.Source -3.12 -m venv (Join-Path $BackendRoot '.venv')
  if ($LASTEXITCODE -ne 0) { throw 'Creation Python impossible.' }
  & $PythonExecutable -m pip install -r (Join-Path $BackendRoot 'requirements.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Installation Python incomplete ; consulter backend/README.md.' }
 }
 $Check=@(& $PythonExecutable $ManagePath check --verbosity 0 2>&1)
 if ($LASTEXITCODE -ne 0) { throw ('Verification Django impossible : '+($Check -join [Environment]::NewLine)) }
}
function Start-ServiceRecord([string]$Name,[int]$Port,[int]$BackendPort,[int]$FrontendPort,$Network,[string]$NodePath) {
 $Instance=[Guid]::NewGuid().ToString('N')
 $Arguments=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$ServiceScript+'"'),'-Service',$Name,'-ProjectRoot',('"'+$ProjectRoot+'"'),'-Instance',$Instance,'-BackendPort',$BackendPort,'-FrontendPort',$FrontendPort,'-BindHost',$Network.bind,'-NodePath',('"'+$NodePath+'"'),'-NetworkHosts',('"'+$Network.hosts+'"'))
 $Process=Start-Process -FilePath 'powershell.exe' -ArgumentList $Arguments -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru
 $Info=Process-Info ([int]$Process.Id)
 if ($null -eq $Info) { throw ('Echec de lancement '+$Name) }
 return [pscustomobject]@{name=$Name;pid=[int]$Process.Id;instance=$Instance;created=$Info.CreationDate.ToUniversalTime().ToString('o');port=$Port}
}
function Stop-Project {
 $State=Read-State
 if ($null -eq $State) { Step 'Aucun service lance par ces fichiers.'; return }
 foreach ($Record in @($State.services | Sort-Object name -Descending)) { Stop-ServiceRecord $Record }
 $State.services=@();Save-State $State
}
function Start-Project {
 $State=Read-State;$Network=Network-Settings
 if ($null -ne $State) {
  $Alive=@($State.services | Where-Object {Expected-Process $_})
  if ($Alive.Count -eq 2 -and $State.network_mode -eq $Network.mode -and $State.network_hosts -eq $Network.hosts) {
   if ((Http-Ready ('http://127.0.0.1:'+$State.frontend_port+'/health')) -and (Http-Ready ('http://127.0.0.1:'+$State.backend_port+'/health'))) { Step 'Application deja demarree.';Show-Addresses $State;return }
  }
  if ($Alive.Count) { Stop-Project }
 }
 if (-not (Test-Path -LiteralPath $ManagePath)) { throw 'backend/manage.py introuvable.' }
 if (-not (Test-Path -LiteralPath $VitePath)) { throw 'Installer le frontend avec npm ci dans frontend, puis relancer.' }
 $Node=Get-Command node.exe -ErrorAction SilentlyContinue
 if ($null -eq $Node) { throw 'Node.js est necessaire au frontend. Installer Node.js puis relancer.' }
 Initialize-Python
 $BackendPort=Free-Port 5000;$FrontendPort=Free-Port 5173
 $State=[pscustomobject]@{version=1;project_root=$ProjectRoot;backend_port=$BackendPort;frontend_port=$FrontendPort;network_mode=$Network.mode;network_hosts=$Network.hosts;services=@()}
 $Launched=@()
 try {
  Step "Demarrage Django sur 127.0.0.1:$BackendPort..."
  $Record=Start-ServiceRecord 'backend' $BackendPort $BackendPort $FrontendPort $Network $Node.Source
  $Launched+=$Record;$State.services=@($Launched);Save-State $State
  Wait-Service "http://127.0.0.1:$BackendPort/health" $Record
  Wait-Service "http://127.0.0.1:$BackendPort/api/public/articles?take=1" $Record
  Step "Demarrage React/Vite sur le port $FrontendPort..."
  $Record=Start-ServiceRecord 'frontend' $FrontendPort $BackendPort $FrontendPort $Network $Node.Source
  $Launched+=$Record;$State.services=@($Launched);Save-State $State
  Wait-Service "http://127.0.0.1:$FrontendPort/" $Record
  Wait-Service "http://127.0.0.1:$FrontendPort/health" $Record
  Show-Addresses $State
  Step ('Journaux : '+$RuntimeRoot)
  if (-not $NoBrowser) { Start-Process ('http://localhost:'+$FrontendPort+'/') | Out-Null }
 } catch {
  foreach ($Record in $Launched) {Stop-ServiceRecord $Record}
  $State.services=@();Save-State $State
  throw
 }
}
try {
 if ($Action -eq 'Status') {
  $State=Read-State
  if ($null -ne $State) {foreach ($Record in $State.services) {Step ($Record.name+' : '+$(if(Expected-Process $Record){'actif'}else{'arrete'})+' (port '+$Record.port+')')}}
  Show-Addresses $State
 } else {
  New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
  $Lock=$null
  try {
   $Lock=[IO.File]::Open((Join-Path $RuntimeRoot 'launcher.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
   switch ($Action) { 'Start' {Start-Project} 'Stop' {Stop-Project} 'Restart' {Stop-Project;Start-Project} }
  } finally {if ($null -ne $Lock) {$Lock.Dispose()}}
 }
 exit 0
} catch {Write-Host ('ERREUR : '+$_.Exception.Message) -ForegroundColor Red;exit 1}
