# Courses de fin naturelle du wrapper : vrais corps AST, processus/etat fictifs.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ServiceScript=Join-Path $ProjectRoot 'scripts\sauverndeko-service.ps1'
. (Join-Path $ProjectRoot 'scripts\sauverndeko-process.ps1')
$Tokens=$null;$ParseErrors=$null
$Ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $ProjectRoot 'scripts\sauverndeko-local.ps1'),[ref]$Tokens,[ref]$ParseErrors)
if ($ParseErrors.Count) {throw 'Syntaxe du lanceur invalide.'}
foreach ($Definition in $Ast.FindAll({param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
 if ($Definition.Name -in @('Stop-ServiceRecord','Stop-Project','Get-ServiceRecordStatus','Assert-ServiceRecordsInspectable')) {Invoke-Expression $Definition.Extent.Text}
}
$script:Checks=0
function Assert-Control([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message};$script:Checks++}
function Start-Process {throw 'Demarrage reel interdit.'}
function Stop-Process {throw 'Arret reel interdit.'}
function Invoke-SauverNdekoNativeTermination {throw 'Terminaison native reelle interdite.'}
$Created=[datetime]::Parse('2026-10-30T12:00:00.1234560Z').ToUniversalTime()
$Record=[pscustomobject]@{name='backend';pid=123;instance='wrapper-fictif';created=$Created.ToString('o');port=5000}
$Command='powershell.exe -File "'+$ServiceScript+'" -Service backend -ProjectRoot "'+$ProjectRoot+'" -Instance wrapper-fictif'
function Read-State {return $script:State}
function Save-State($State) {$script:Saved+=@(($State | ConvertTo-Json -Depth 8 -Compress))}
function Step([string]$Text) {$script:Messages+=@($Text)}
function Get-Process([int]$Id,$ErrorAction) {return $null}
function Get-CimInstance($ClassName,[string]$Filter,$ErrorAction) {if ($ClassName -ne 'Win32_Process' -or $Filter -ne 'ParentProcessId=123') {throw 'Lecture CIM hors fixture.'};return @()}
function Process-Info([int]$ProcessId) {
 if ($ProcessId -ne 123) {throw 'PID hors fixture.'};$script:Reads++
 if ($script:Gone) {return $null}
 if ($script:Recycled) {return [pscustomobject]@{CreationDate=$Created.AddSeconds(1);CommandLine='autre application'}}
 if ($script:Reads -ge 4) {
  switch ($script:Mode) {
   'autoexit' {$script:Gone=$true;return $null}
   'foreign' {$script:Recycled=$true;return [pscustomobject]@{CreationDate=$Created.AddSeconds(1);CommandLine='autre application'}}
   'inaccessible' {return [pscustomobject]@{CreationDate=$Created;CommandLine=$null}}
   'temporary-null' {if ($script:Reads -eq 4) {return $null}}
  }
 }
 return [pscustomobject]@{CreationDate=$Created;CommandLine=$Command}
}
function Stop-SauverNdekoVerifiedProcess([int]$ProcessId,$Expected) {
 if ($ProcessId -ne 123) {throw 'PID hors fixture.'};$script:Stopped+=@($ProcessId)
 switch ($script:Mode) {
  'denied' {throw 'Arret refuse (fixture).'}
  'exit-on-stop' {$script:Gone=$true;throw 'Processus deja termine (fixture).'}
  'recycle-on-stop' {$script:Recycled=$true;throw 'Identite native remplacee (fixture).'}
  default {$script:Gone=$true}
 }
}
foreach ($Mode in @('autoexit','foreign','inaccessible','temporary-null','denied','exit-on-stop','recycle-on-stop')) {
 $script:Mode=$Mode;$script:Reads=0;$script:Gone=$false;$script:Recycled=$false;$script:Stopped=@();$script:Saved=@();$script:Messages=@()
 $script:State=[pscustomobject]@{version=1;project_root=$ProjectRoot;services=@($Record)}
 $Before=$script:State | ConvertTo-Json -Depth 8 -Compress;$Rejected=$false
 try {Stop-Project} catch {$Rejected=$true}
 if ($Mode -in @('inaccessible','denied')) {
  Assert-Control $Rejected ('Un vrai refus garde son erreur : '+$Mode)
  Assert-Control ($script:Saved.Count -eq 0 -and ($script:State | ConvertTo-Json -Depth 8 -Compress) -eq $Before) ('Le suivi entier reste conserve : '+$Mode)
 } else {
  Assert-Control (-not $Rejected) ('Une fin naturelle ou identite remplacee ne produit pas une fausse erreur : '+$Mode)
  Assert-Control ($script:Saved.Count -eq 1 -and $script:State.services.Count -eq 0) ('Le suivi devenu ancien peut etre nettoye sans toucher un autre processus : '+$Mode)
 }
 if ($Mode -in @('autoexit','foreign','inaccessible')) {
  Assert-Control ($script:Stopped.Count -eq 0) ('Aucune terminaison ne doit etre tentee : '+$Mode)
 } else {Assert-Control ($script:Stopped.Count -eq 1) ('Une seule action sur le PID fictif atteste : '+$Mode)}
 if ($Mode -in @('autoexit','foreign','recycle-on-stop','inaccessible','denied')) {Assert-Control (@($script:Messages | Where-Object {$_ -eq 'backend arrete.'}).Count -eq 0) ('Aucun faux message de terminaison forcee : '+$Mode)}
}
[pscustomobject]@{success=$true;checks=$script:Checks;processesStarted=0;processesStopped=0;nativeTerminations=0;stateWrites=0} | ConvertTo-Json -Compress
