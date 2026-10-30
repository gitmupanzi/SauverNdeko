# Recette des lectures d'identite, sans demarrer ni arreter de processus.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ServiceScript=Join-Path $ProjectRoot 'scripts\sauverndeko-service.ps1'
$Helpers=Join-Path $ProjectRoot 'scripts\sauverndeko-process.ps1'
$Launcher=Join-Path $ProjectRoot 'scripts\sauverndeko-local.ps1'
. $Helpers
$Tokens=$null;$ErrorsFound=$null
$Ast=[System.Management.Automation.Language.Parser]::ParseFile($Launcher,[ref]$Tokens,[ref]$ErrorsFound)
if ($ErrorsFound.Count) {throw 'Syntaxe du lanceur invalide.'}
foreach ($Definition in $Ast.FindAll({param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)) {
 if ($Definition.Name -in @('Get-ServiceRecordStatus','Expected-Process','Process-Info')) {Invoke-Expression $Definition.Extent.Text}
}
$HelperAst=[System.Management.Automation.Language.Parser]::ParseFile($Helpers,[ref]$Tokens,[ref]$ErrorsFound)
if ($ErrorsFound.Count) {throw 'Syntaxe des lectures de processus invalide.'}
$NativeDefinition=@($HelperAst.FindAll({param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Get-SauverNdekoNativeProcessInfo'},$true))[0].Extent.Text
$script:Checks=0
function Assert-Control([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message};$script:Checks++}
function Start-Process {throw 'Le test a tente de demarrer un processus.'}
function Stop-Process {throw 'Le test a tente d''arreter un processus.'}

Initialize-SauverNdekoProcessReader
$Created=[datetime]::Parse('2026-10-30T12:00:00.1234560Z').ToUniversalTime()
$Record=[pscustomobject]@{name='backend';pid=123;instance='identite-fictive-123';created=$Created.ToString('o');port=5000}
$KnownCommand='powershell.exe -NoLogo -NoProfile -File "'+$ServiceScript+'" -Service backend -ProjectRoot "'+$ProjectRoot+'" -Instance identite-fictive-123'
$script:CimCalls=0;$script:NativeCalls=0;$script:CimFailure=$false
$script:CimFixture=[pscustomobject]@{ProcessId=123;CreationDate=$Created;CommandLine=$KnownCommand}
$script:NativeFixture=[pscustomobject]@{ProcessId=123;CreationDate=$Created.AddTicks(4);CommandLine=$KnownCommand}
function Get-CimInstance {param($ClassName,$Filter,$ErrorAction) $script:CimCalls++;if ($script:CimFailure) {throw 'Lecture CIM refusee (fixture).'};return $script:CimFixture}
function Get-SauverNdekoNativeProcessInfo([int]$ProcessId) {$script:NativeCalls++;return $script:NativeFixture}
$Value=Get-SauverNdekoProcessInfo 123
Assert-Control ($Value.CommandLine -eq $KnownCommand -and $script:CimCalls -eq 1 -and $script:NativeCalls -eq 0) 'CIM complet doit rester prioritaire.'
$script:CimFixture=[pscustomobject]@{ProcessId=123;CreationDate=$Created;CommandLine=$null}
$Value=Get-SauverNdekoProcessInfo 123
Assert-Control ($Value.CreationDate.Ticks -eq $Created.AddTicks(4).Ticks -and $script:NativeCalls -eq 1) 'CIM masque doit utiliser l''identite native complete.'
Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'owned') 'La lecture native doit conserver une preuve exacte a la precision CIM.'
$script:CimFailure=$true
Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'owned') 'Le refus CIM peut etre complete par une lecture native autorisee.'
$script:CimFailure=$false;$script:NativeFixture=$null
Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Deux lectures incompletes ne doivent jamais autoriser l''arret.'
$script:CimFixture=[pscustomobject]@{ProcessId=123;CreationDate=$Created.AddSeconds(1);CommandLine=$KnownCommand}
Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'foreign') 'Un PID recycle doit rester etranger.'
$script:CimFixture=[pscustomobject]@{ProcessId=123;CreationDate='invalide';CommandLine=$KnownCommand}
Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une date illisible ne prouve pas l''identite.'

foreach ($Ticks in 0..9) {Assert-Control (Test-SauverNdekoCreationDate ($Created.AddTicks($Ticks)) $Created) 'Le supplement natif de 100 ns doit etre compare a la microseconde CIM.'}
Assert-Control (-not (Test-SauverNdekoCreationDate ($Created.AddTicks(10)) $Created)) 'Une microseconde complete de difference doit etre refusee.'
Assert-Control (-not (Test-SauverNdekoCreationDate $null $Created)) 'Une creation absente ne doit pas etre acceptee.'
Assert-Control (-not (Test-SauverNdekoCreationDate $Created 'date-invalide')) 'Une date enregistree invalide doit etre refusee.'

Assert-Control (Test-SauverNdekoServiceCommand $KnownCommand $Record $ServiceScript $ProjectRoot) 'Les quatre arguments exacts doivent etre reconnus.'
$InvalidCommands=@(
 $KnownCommand.Replace($ServiceScript,$ServiceScript+'.etranger'),
 $KnownCommand.Replace($ProjectRoot+'" -Instance',$ProjectRoot+'-autre" -Instance'),
 $KnownCommand.Replace('identite-fictive-123','identite-fictive-123-suite'),
 $KnownCommand.Replace('-Service backend','-Service frontend'),
 ($KnownCommand+' -Instance identite-fictive-123'),
 ($KnownCommand+' -File "'+$ServiceScript+'"'),
 $KnownCommand.Replace('-ProjectRoot "'+$ProjectRoot+'"',''),
 $KnownCommand.Replace('powershell.exe','autre.exe'),
 'powershell.exe -File autre.ps1 -Text "'+$ServiceScript+'" -Service backend -ProjectRoot "'+$ProjectRoot+'" -Instance identite-fictive-123'
)
foreach ($Command in $InvalidCommands) {Assert-Control (-not (Test-SauverNdekoServiceCommand $Command $Record $ServiceScript $ProjectRoot)) 'Un argument etranger, incomplet ou duplique doit etre refuse.'}
$SpacedRoot='C:\Dossier de verification\Sauver Ndeko'
$SpacedScript=Join-Path $SpacedRoot 'scripts\sauverndeko-service.ps1'
$SpacedCommand='"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -File "'+$SpacedScript+'" -Service backend -ProjectRoot "'+$SpacedRoot+'" -Instance identite-fictive-123'
Assert-Control (Test-SauverNdekoServiceCommand $SpacedCommand $Record $SpacedScript $SpacedRoot) 'Les chemins contenant des espaces doivent conserver leur identite.'

# Restaurer les vraies lectures, puis sonder uniquement les services deja suivis.
Remove-Item Function:\Get-CimInstance
Invoke-Expression $NativeDefinition
$Native=[SauverNdeko.NativeProcessReaderV1]::Read($PID)
Assert-Control ($null -ne $Native -and $Native.ProcessId -eq $PID -and -not [string]::IsNullOrWhiteSpace($Native.CommandLine)) 'La lecture native du processus de recette doit fonctionner sans elevation.'
Assert-Control ($null -eq [SauverNdeko.NativeProcessReaderV1]::Read(-1)) 'Un PID negatif ne doit pas produire d''identite.'
$StatePath=Join-Path $ProjectRoot '.runtime\services.json'
$LiveChecks=0
if (Test-Path -LiteralPath $StatePath) {
 $State=Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
 if ($State.project_root -ne $ProjectRoot) {throw 'Etat d''un autre projet.'}
 foreach ($LiveRecord in $State.services) {
  Assert-Control ((Get-ServiceRecordStatus $LiveRecord) -eq 'owned') 'Le service actif doit etre reconnu par ses vraies metadonnees.'
  $LiveChecks++
 }
}
[pscustomobject]@{success=$true;checks=$script:Checks;liveServicesRead=$LiveChecks;processesStarted=0;processesStopped=0} | ConvertTo-Json -Compress
