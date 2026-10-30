# Verification du repli minimal : toutes les actions sont remplacees par des doubles.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $ProjectRoot 'scripts\sauverndeko-process.ps1')
$script:Checks=0
function Assert-Control([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message};$script:Checks++}
function Start-Process {throw 'Demarrage reel interdit par la recette.'}
Initialize-SauverNdekoProcessReader
Assert-Control ([SauverNdeko.NativeProcessReaderV1]::TerminateVerified(-1,0,'','') -match 'incompletes') 'Les parametres incomplets sont refuses avant toute ouverture native.'
$Created=[datetime]::Parse('2026-10-30T12:00:00.1234560Z').ToUniversalTime()
$Executable=Join-Path $ProjectRoot 'frontend\node_modules\@esbuild\win32-x64\esbuild.exe'
$Expected=[pscustomobject]@{ProcessId=123;CreationDate=$Created;CommandLine=('"'+$Executable+'" --service=fictif');ExecutablePath=$Executable}
$script:Native=[pscustomobject]@{ProcessId=123;CreationDate=$Created.AddTicks(4);CommandLine=$Expected.CommandLine;ExecutablePath=$Executable}
$script:Calls=@();$script:Stops=@();$script:Reads=0;$script:Mode='success';$script:NativeFailure=$false
function Stop-Process([int]$Id,[switch]$Force,$ErrorAction) {
 if ($Id -ne 123) {throw 'PID hors fixture.'};$script:Stops+=@($Id)
 if ($script:Mode -eq 'denied') {throw [UnauthorizedAccessException]::new('Refus Windows simule.')}
 if ($script:Mode -eq 'nested-denied') {throw [Exception]::new('Echec cmdlet simule.',[ComponentModel.Win32Exception]::new(5))}
 if ($script:Mode -eq 'other') {throw 'Panne differente du refus de permission.'}
}
function Get-SauverNdekoNativeProcessInfo([int]$ProcessId) {if ($ProcessId -ne 123) {throw 'PID hors fixture.'};$script:Reads++;return $script:Native}
function Invoke-SauverNdekoNativeTermination([int]$ProcessId,$Snapshot) {if ($ProcessId -ne 123) {throw 'PID hors fixture.'};$script:Calls+=@([pscustomobject]@{id=$ProcessId;snapshot=$Snapshot});if ($script:NativeFailure) {throw 'Terminaison minimale refusee (simulation).'}}
Stop-SauverNdekoVerifiedProcess 123 $Expected
Assert-Control ($script:Stops.Count -eq 1 -and $script:Reads -eq 0 -and $script:Calls.Count -eq 0) 'Un arret ordinaire reussi ne lance aucun repli natif.'
$script:Mode='denied';$script:Calls=@();$script:Reads=0
Stop-SauverNdekoVerifiedProcess 123 $Expected
Assert-Control ($script:Reads -eq 1 -and $script:Calls.Count -eq 1 -and $script:Calls[0].id -eq 123) 'Un acces refuse peut utiliser les seuls droits minimaux avec identite concordante.'
Assert-Control ($script:Calls[0].snapshot.CreationDate.Ticks -eq $Created.AddTicks(4).Ticks -and $script:Calls[0].snapshot.CommandLine -ceq $Expected.CommandLine -and $script:Calls[0].snapshot.ExecutablePath -ceq $Executable) 'La verification finale recoit les ticks natifs exacts, la commande et le chemin entier.'
$script:Mode='nested-denied';$script:Calls=@()
Stop-SauverNdekoVerifiedProcess 123 $Expected
Assert-Control ($script:Calls.Count -eq 1) 'Une exception Windows code5 enveloppee par la cmdlet conserve le meme repli controle.'
$script:Mode='denied'
foreach ($Case in @('creation','commande','executable','pid','lecture','image-absente','commande-attendue-absente','date-attendue-invalide')) {
 $script:Native=[pscustomobject]@{ProcessId=123;CreationDate=$Created.AddTicks(4);CommandLine=$Expected.CommandLine;ExecutablePath=$Executable}
 $Reference=[pscustomobject]@{ProcessId=123;CreationDate=$Created;CommandLine=$Expected.CommandLine;ExecutablePath=$Executable}
 switch ($Case) {
  'creation' {$script:Native.CreationDate=$Created.AddTicks(10)}
  'commande' {$script:Native.CommandLine+=' --autre'}
  'executable' {$script:Native.ExecutablePath='C:\Autre\esbuild.exe'}
  'pid' {$script:Native.ProcessId=124}
  'lecture' {$script:Native=$null}
  'image-absente' {$script:Native.ExecutablePath=$null}
  'commande-attendue-absente' {$Reference.CommandLine=$null}
  'date-attendue-invalide' {$Reference.CreationDate='illisible'}
 }
 $script:Calls=@();$Rejected=$false
 try {Stop-SauverNdekoVerifiedProcess 123 $Reference} catch {$Rejected=$true}
 Assert-Control $Rejected ('Les metadonnees differentes doivent refuser la terminaison : '+$Case)
 Assert-Control ($script:Calls.Count -eq 0) ('Aucune terminaison native ne doit etre appelee : '+$Case)
}
$script:Native=[pscustomobject]@{ProcessId=123;CreationDate=$Created.AddTicks(4);CommandLine=$Expected.CommandLine;ExecutablePath=$Executable}
$script:Calls=@();$script:Reads=0;$script:Mode='other';$Rejected=$false
try {Stop-SauverNdekoVerifiedProcess 123 $Expected} catch {$Rejected=$true}
Assert-Control ($Rejected -and $script:Reads -eq 0 -and $script:Calls.Count -eq 0) 'Une autre panne de Stop-Process n''autorise jamais le repli.'
$script:Mode='denied';$script:NativeFailure=$true;$script:Calls=@();$Rejected=$false
try {Stop-SauverNdekoVerifiedProcess 123 $Expected} catch {$Rejected=$true}
Assert-Control ($Rejected -and $script:Calls.Count -eq 1) 'Un refus minimal reste explicite et ne doit pas etre annonce comme reussi.'
[pscustomobject]@{success=$true;checks=$script:Checks;processesStarted=0;processesStopped=0;nativeTerminations=0;stateWrites=0} | ConvertTo-Json -Compress
