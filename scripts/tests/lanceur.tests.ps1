# Verification sans demarrer/arreter de processus ni acceder a PostgreSQL.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ServiceScript=Join-Path $ProjectRoot 'scripts\sauverndeko-service.ps1'
$Launcher=Join-Path $ProjectRoot 'scripts\sauverndeko-local.ps1'
$BackendRoot=Join-Path $ProjectRoot '.runtime\configuration-fictive-absente'
$Tokens=$null;$ErrorsFound=$null
$Ast=[System.Management.Automation.Language.Parser]::ParseFile($Launcher,[ref]$Tokens,[ref]$ErrorsFound)
if ($ErrorsFound.Count) {throw 'Syntaxe du lanceur invalide.'}
$RequiredFrontendPort=5174
$Names=@('Network-Option','Network-Settings','Expected-Process','Free-Port','Frontend-Port')
foreach ($Definition in $Ast.FindAll({param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)) {
 if ($Definition.Name -in $Names) {Invoke-Expression $Definition.Extent.Text}
}
$OldMode=[Environment]::GetEnvironmentVariable('SAUVERNDEKO_NETWORK_MODE','Process')
$OldAlias=[Environment]::GetEnvironmentVariable('SAUVERNDEKO_NETWORK_ALIAS','Process')
try {
 $env:SAUVERNDEKO_NETWORK_MODE='local';$env:SAUVERNDEKO_NETWORK_ALIAS='';$Reseau=$false
 $Network=Network-Settings
 if ($Network.mode -ne 'local' -or $Network.bind -ne '127.0.0.1') {throw 'Mode local incorrect.'}
 $Reseau=$true;$Network=Network-Settings
 if ($Network.mode -ne 'lan' -or $Network.bind -ne '0.0.0.0' -or $Network.hosts.Contains('*')) {throw 'Mode reseau incorrect.'}
 $env:SAUVERNDEKO_NETWORK_ALIAS='*.example.invalid';$Rejected=$false
 try {Network-Settings | Out-Null} catch {$Rejected=$true}
 if (-not $Rejected) {throw 'Alias dangereux accepte.'}
 function Port-InUse([int]$Port) {return $Port -in @(5000,5001)}
 if ((Free-Port 5000) -ne 5002) {throw 'Un port occupe a ete choisi.'}
 if ((Frontend-Port) -ne 5174) {throw 'Port frontend incorrect.'}
 function Port-InUse([int]$Port) {return $Port -eq 5174}
 $Rejected=$false
 try {Frontend-Port | Out-Null} catch {$Rejected=$_.Exception.Message -like '*5174*'}
 if (-not $Rejected) {throw 'Port frontend occupe non refuse.'}
 $Created=[DateTime]::UtcNow
 $FixtureProcess=[pscustomobject]@{CommandLine=('powershell -File "'+$ServiceScript+'" -Instance instance-fictive');CreationDate=$Created}
 function Process-Info([int]$ProcessId) {return $FixtureProcess}
 $Record=[pscustomobject]@{pid=123;instance='instance-fictive';created=$Created.ToUniversalTime().ToString('o')}
 if (-not (Expected-Process $Record)) {throw 'Processus connu non reconnu.'}
 $Record.instance='autre-instance'
 if (Expected-Process $Record) {throw 'Processus etranger reconnu comme proprietaire.'}
 $Record.instance='instance-fictive';$Record.created=$Created.AddSeconds(-1).ToUniversalTime().ToString('o')
 if (Expected-Process $Record) {throw 'PID recycle reconnu comme proprietaire.'}
 Write-Output '9 controles : local, LAN, alias, ports backend, frontend fixe, frontend occupe, identite valide, instance etrangere, PID recycle : OK.'
} finally {
 [Environment]::SetEnvironmentVariable('SAUVERNDEKO_NETWORK_MODE',$OldMode,'Process')
 [Environment]::SetEnvironmentVariable('SAUVERNDEKO_NETWORK_ALIAS',$OldAlias,'Process')
}
