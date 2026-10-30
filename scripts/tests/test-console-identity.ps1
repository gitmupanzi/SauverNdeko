# Verification des auxiliaires console : lectures et doubles uniquement.
# Aucune action systeme de demarrage, arret ou ecriture de l'etat du lanceur.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ServiceScript=Join-Path $ProjectRoot 'scripts\sauverndeko-service.ps1'
. (Join-Path $ProjectRoot 'scripts\sauverndeko-process.ps1')
Initialize-SauverNdekoProcessReader
$script:Checks=0
function Assert-Control([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message};$script:Checks++}
function Start-Process {throw 'Demarrage reel interdit par cette recette.'}
function Stop-Process {throw 'Arret reel interdit par cette recette.'}
$Created=[datetime]::Parse('2026-10-30T12:00:00.1234560Z').ToUniversalTime()
$SystemDirectory=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) 'System32'
$Conhost=Join-Path $SystemDirectory 'conhost.exe'
$OpenConsole=Join-Path $SystemDirectory 'OpenConsole.exe'
$Snapshot=[pscustomobject]@{ProcessId=124;CreationDate=$Created;Name='conhost.exe'}
$Observed=[pscustomobject]@{ProcessId=124;CreationDate=$Created;CommandLine='non utilise'}
$script:Native=[pscustomobject]@{ProcessId=124;CreationDate=$Created.AddTicks(4);ExecutablePath=$Conhost;CommandLine=('\??\'+$Conhost+' 0x4')}
function Get-SauverNdekoNativeProcessInfo([int]$ProcessId) {return $script:Native}
Assert-Control (Test-SauverNdekoConsoleHelper $Observed $Snapshot) 'Le vrai conhost natif doit etre reconnu.'
$script:Native.ExecutablePath=$OpenConsole;$script:Native.CommandLine='"'+$OpenConsole+'" --headless'
Assert-Control (Test-SauverNdekoConsoleHelper $Observed $Snapshot) 'OpenConsole systeme doit etre reconnu par image et argv exacts.'
$script:Native.ExecutablePath=$Conhost;$script:Native.CommandLine='\\?\'+$Conhost+' 0x4'
Assert-Control (Test-SauverNdekoConsoleHelper $Observed $Snapshot) 'Le prefixe Windows etendu ne change pas le chemin atteste.'
$GoodCommand='\??\'+$Conhost+' 0x4'
$InvalidImages=@('C:\Temp\conhost.exe',(Join-Path $SystemDirectory 'conhost.exe.autre'),(Join-Path $SystemDirectory 'powershell.exe'),'')
foreach ($Image in $InvalidImages) {$script:Native.ExecutablePath=$Image;$script:Native.CommandLine=$GoodCommand;Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Un nom seul ou une autre image ne constitue pas un auxiliaire Windows.'}
$script:Native.ExecutablePath=$Conhost
foreach ($Command in @('conhost.exe 0x4','C:\Temp\conhost.exe 0x4',('"'+$OpenConsole+'" --headless'),'')) {$script:Native.CommandLine=$Command;Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Un argv sans le meme executable complet doit etre refuse.'}
$script:Native.CommandLine=$GoodCommand;$script:Native.CreationDate=$Created.AddTicks(10)
Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Un PID recycle a la microseconde suivante ne doit pas etre exclu.'
$script:Native.CreationDate=$Created.AddTicks(4);$script:Native.ProcessId=125
Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Une autre identite native doit etre refusee.'
$script:Native.ProcessId=124;$Observed.CreationDate=$Created.AddSeconds(1)
Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Les deux observations de creation doivent correspondre.'
$Observed.CreationDate=$Created;$script:Native=$null
Assert-Control (-not (Test-SauverNdekoConsoleHelper $Observed $Snapshot)) 'Une lecture native refusee doit maintenir le parcours ordinaire.'

# Charger le vrai corps d'arret via AST, sans executer le lanceur principal.
$Tokens=$null;$ParseErrors=$null
$Ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $ProjectRoot 'scripts\sauverndeko-local.ps1'),[ref]$Tokens,[ref]$ParseErrors)
if ($ParseErrors.Count) {throw 'Syntaxe du lanceur invalide.'}
foreach ($Definition in $Ast.FindAll({param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
 if ($Definition.Name -in @('Stop-ServiceRecord','Stop-Project','Get-ServiceRecordStatus','Assert-ServiceRecordsInspectable')) {Invoke-Expression $Definition.Extent.Text}
}
$Record=[pscustomobject]@{name='backend';pid=123;instance='console-fixture';created=$Created.ToString('o');port=5000}
$KnownCommand='powershell.exe -File "'+$ServiceScript+'" -Service backend -ProjectRoot "'+$ProjectRoot+'" -Instance console-fixture'
$script:Processes=@{};$script:Stopped=@();$script:Saved=@();$script:ChildSnapshot=$Snapshot;$script:FailChild=$false
$script:Native=[pscustomobject]@{ProcessId=124;CreationDate=$Created.AddTicks(4);ExecutablePath=$Conhost;CommandLine=$GoodCommand}
function Process-Info([int]$ProcessId) {return $script:Processes[$ProcessId]}
function Get-Process([int]$Id,$ErrorAction) {return $null}
function Get-CimInstance($ClassName,[string]$Filter,$ErrorAction) {if ($ClassName -ne 'Win32_Process' -or $Filter -notmatch '^ParentProcessId=\d+$') {throw 'Lecture CIM hors fixture.'};if ($Filter -eq 'ParentProcessId=123') {return $script:ChildSnapshot};return @()}
function Step([string]$Text) {}
function Stop-Process([int]$Id,[switch]$Force,$ErrorAction) {if ($Id -notin @(123,124)) {throw 'PID hors fixture : aucune delegation systeme.'};$script:Stopped+=@($Id);if ($Id -eq 124 -and $script:FailChild) {throw 'Acces refuse simule a l''enfant.'};$script:Processes.Remove($Id)}
function Read-State {return $script:FixtureState}
function Save-State($State) {$script:Saved+=@(($State | ConvertTo-Json -Depth 8 -Compress))}
$script:Processes[123]=[pscustomobject]@{CreationDate=$Created;CommandLine=$KnownCommand}
$script:Processes[124]=$Observed
Stop-ServiceRecord $Record
Assert-Control ($script:Stopped.Count -eq 1 -and $script:Stopped[0] -eq 123) 'Le vrai corps doit laisser le conhost atteste intact puis arreter seulement le wrapper fictif.'
Assert-Control ($script:Processes.ContainsKey(124)) 'L''auxiliaire doit demeurer present dans la fixture apres l''arret du wrapper.'

# Un faux conhost ou une identite native differente garde le refus d'acces.
foreach ($Case in @('image-etrangere','argv-etranger','date-recyclee','lecture-refusee','enfant-ordinaire')) {
 $script:Processes[123]=[pscustomobject]@{CreationDate=$Created;CommandLine=$KnownCommand};$script:Processes[124]=$Observed
 $script:Stopped=@();$script:Saved=@();$script:FailChild=$true
 $script:Native=[pscustomobject]@{ProcessId=124;CreationDate=$Created.AddTicks(4);ExecutablePath=$Conhost;CommandLine=$GoodCommand}
 switch ($Case) {
  'image-etrangere' {$script:Native.ExecutablePath='C:\Temp\conhost.exe'}
  'argv-etranger' {$script:Native.CommandLine='C:\Temp\conhost.exe 0x4'}
  'date-recyclee' {$script:Native.CreationDate=$Created.AddTicks(10)}
  'lecture-refusee' {$script:Native=$null}
  'enfant-ordinaire' {$script:Native.ExecutablePath=Join-Path $SystemDirectory 'cmd.exe';$script:Native.CommandLine='cmd.exe'}
 }
 $script:FixtureState=[pscustomobject]@{version=1;project_root=$ProjectRoot;services=@($Record)}
 $Before=$script:FixtureState | ConvertTo-Json -Depth 8 -Compress;$Rejected=$false
 try {Stop-Project} catch {$Rejected=$true}
 Assert-Control ($Rejected -and $script:Stopped.Count -eq 1 -and $script:Stopped[0] -eq 124) ('Un enfant non atteste garde le refus ordinaire : '+$Case)
 Assert-Control ($script:Processes.ContainsKey(123) -and $script:Saved.Count -eq 0 -and ($script:FixtureState | ConvertTo-Json -Depth 8 -Compress) -eq $Before) ('Le refus preserve wrapper et suivi sans etat vide : '+$Case)
}
[pscustomobject]@{success=$true;checks=$script:Checks;processesStarted=0;processesStopped=0;stateWrites=0} | ConvertTo-Json -Compress
