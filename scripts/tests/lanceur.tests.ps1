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
$StopServiceDefinition=@($Ast.FindAll({param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Stop-ServiceRecord'},$true))[0].Extent.Text
$RequiredFrontendPort=5174
$Names=@('Network-Option','Network-Settings','Get-ServiceRecordStatus','Expected-Process','Assert-ServiceRecordsInspectable','Stop-Project','Start-Project','Free-Port','Frontend-Port')
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

 # Les fonctions du lanceur sont executees depuis leur AST, jamais le script
 # principal. Les doubles suivants interdisent toute action sur les vrais services.
 $script:Controls=9
 function Assert-Control([bool]$Condition,[string]$Message) {
  if (-not $Condition) {throw $Message}
  $script:Controls++
 }
 function Start-Process {throw 'Le test a tente de demarrer un vrai processus.'}
 function Stop-Process {throw 'Le test a tente d''arreter un vrai processus.'}
 function Get-CimInstance {throw 'Le test a tente de lire les vrais processus CIM.'}
 function Initialize-Python {throw 'Le test a tente d''initialiser le backend.'}
 function Start-ServiceRecord {throw 'Le test a tente de demarrer un service.'}
 function Step([string]$Text) {$script:Messages+=@($Text)}
 $script:Messages=@()
 $script:FixtureProcesses=@{}
 $script:FallbackAlive=@{}
 $script:ProcessReadError=$false
 function Process-Info([int]$ProcessId) {
  if ($script:ProcessReadError) {throw 'Acces CIM refuse (simulation).'}
  return $script:FixtureProcesses[$ProcessId]
 }
 function Get-Process([int]$Id,$ErrorAction) {
  if ($script:FallbackAlive.ContainsKey($Id)) {return [pscustomobject]@{Id=$Id}}
  return $null
 }
 $Record=[pscustomobject]@{name='backend';pid=123;instance='instance-fictive';created=$Created.ToUniversalTime().ToString('o');port=5000}
 $KnownCommand='powershell -File "'+$ServiceScript+'" -Instance instance-fictive'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$Created}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'owned') 'Le service dont l''identite est prouvee doit etre owned.'
 Assert-Control (Expected-Process $Record) 'Le wrapper doit conserver son contrat booleen owned.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$null;CreationDate=$Created}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une ligne de commande NULL ne signifie pas un service absent.'
 Assert-Control (-not (Expected-Process $Record)) 'Une identite inaccessible ne doit jamais autoriser un arret force.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine='   ';CreationDate=$Created}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une ligne de commande blanche doit rester inaccessible.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$null}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une date de creation absente ne prouve aucune identite.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate='date-invalide'}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une date de creation invalide doit rester inaccessible.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$Created.AddSeconds(1)}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'foreign') 'Un PID recycle doit etre distingue d''une identite inaccessible.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine='powershell -File autre-projet.ps1 -Instance instance-fictive';CreationDate=$Created}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'foreign') 'Un autre script ne doit pas etre considere comme le projet.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand.Replace('instance-fictive','autre-instance');CreationDate=$Created}
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'foreign') 'Une autre instance ne doit pas etre consideree comme le projet.'
 $script:FixtureProcesses.Remove(123)
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'absent') 'Un PID absent de CIM et Get-Process doit etre absent.'
 $script:FallbackAlive[123]=$true
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Un PID vivant dont CIM ne donne rien doit rester inaccessible.'
 $script:ProcessReadError=$true
 Assert-Control ((Get-ServiceRecordStatus $Record) -eq 'inaccessible') 'Une erreur de lecture CIM ne doit pas effacer l''identite suivie.'
 $script:ProcessReadError=$false
 $script:FallbackAlive.Clear()

 # Etat synthetique en memoire : aucune lecture/ecriture de .runtime/services.json.
 $script:SavedStates=@();$script:StoppedIds=@();$script:StopFailure=$false
 $script:FixtureState=$null;$script:Ready=$false;$script:AddressCalls=0
 function Read-State {return $script:FixtureState}
 function Save-State($State) {$script:SavedStates+=@(($State | ConvertTo-Json -Depth 8 -Compress))}
 function Stop-ServiceRecord($ServiceRecord) {
  if ((Get-ServiceRecordStatus $ServiceRecord) -ne 'owned') {return}
  $script:StoppedIds+=@([int]$ServiceRecord.pid)
  if ($script:StopFailure) {throw 'Arret refuse (simulation).'}
  $script:FixtureProcesses.Remove([int]$ServiceRecord.pid)
  $script:FallbackAlive.Remove([int]$ServiceRecord.pid)
 }
 function Network-Settings {return [pscustomobject]@{mode='local';bind='127.0.0.1';hosts='test.invalid'}}
 function Http-Ready([string]$Url) {return $script:Ready}
 function Show-Addresses($State) {$script:AddressCalls++}
 $FrontendRecord=[pscustomobject]@{name='frontend';pid=456;instance='frontend-fictive';created=$Created.ToUniversalTime().ToString('o');port=5174}
 function New-FixtureState {
  return [pscustomobject]@{version=1;project_root=$ProjectRoot;backend_port=5000;frontend_port=5174;network_mode='local';network_hosts='test.invalid';services=@($Record,$FrontendRecord)}
 }
 $script:FixtureState=New-FixtureState
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$null;CreationDate=$Created}
 $OriginalState=$script:FixtureState | ConvertTo-Json -Depth 8 -Compress
 $Rejected=$false
 try {Stop-Project} catch {$Rejected=$true}
 Assert-Control $Rejected 'L''arret doit refuser une identite inaccessible au lieu de perdre les metadonnees.'
 Assert-Control ($script:StoppedIds.Count -eq 0) 'Aucun arret ne doit preceder la verification de toutes les identites.'
 Assert-Control ($script:SavedStates.Count -eq 0) 'La garde inaccessible ne doit pas reecrire l''etat.'
 Assert-Control (($script:FixtureState | ConvertTo-Json -Depth 8 -Compress) -eq $OriginalState) 'Les metadonnees originales doivent rester integralement disponibles.'

 # Meme si l'autre service est arretable, l'ensemble doit etre controle avant DML.
 $script:FixtureProcesses[456]=[pscustomobject]@{CommandLine=('powershell -File "'+$ServiceScript+'" -Instance frontend-fictive');CreationDate=$Created}
 $Rejected=$false
 try {Stop-Project} catch {$Rejected=$true}
 Assert-Control ($Rejected -and $script:StoppedIds.Count -eq 0 -and $script:SavedStates.Count -eq 0) 'Un service connu ne doit pas etre arrete lorsque son pair est inaccessible.'
 $StartReached=$false;$Rejected=$false
 try {Stop-Project;$StartReached=$true;Start-Project} catch {$Rejected=$true}
 Assert-Control ($Rejected -and -not $StartReached) 'Le refus d''arret doit interrompre le parcours Restart avant son demarrage.'

 # Start doit refuser une reprise risquee, mais peut reutiliser la paire saine.
 $script:Ready=$false;$Rejected=$false
 try {Start-Project} catch {$Rejected=$true}
 Assert-Control ($Rejected -and $script:StoppedIds.Count -eq 0 -and $script:SavedStates.Count -eq 0) 'Start ne doit pas masquer une identite inaccessible lorsque la sante n''est pas prouvee.'
 $script:Ready=$true
 Start-Project
 Assert-Control ($script:AddressCalls -eq 1 -and $script:StoppedIds.Count -eq 0 -and $script:SavedStates.Count -eq 0) 'Une paire deja saine et compatible doit etre reutilisee sans arret ni reecriture.'

 # Des PID prouves absents/etrangers peuvent etre retires, jamais tues.
 $script:FixtureState=New-FixtureState;$script:FixtureProcesses.Clear()
 $script:FixtureProcesses[456]=[pscustomobject]@{CommandLine='powershell autre-projet.ps1';CreationDate=$Created}
 Stop-Project
 Assert-Control ($script:StoppedIds.Count -eq 0 -and $script:SavedStates.Count -eq 1) 'Le nettoyage des seuls PID absents/etrangers doit sauvegarder sans tuer.'
 Assert-Control ($script:FixtureState.services.Count -eq 0) 'Les references prouvees obsoletes peuvent etre nettoyees.'

 # Si l'arret d'un service connu echoue, son suivi doit subsister.
 $script:FixtureState=New-FixtureState;$script:SavedStates=@();$script:StoppedIds=@()
 $script:FixtureProcesses.Clear()
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$Created}
 $script:StopFailure=$true;$Rejected=$false
 try {Stop-Project} catch {$Rejected=$true}
 Assert-Control $Rejected 'Une erreur d''arret ne doit pas etre presentee comme un arret reussi.'
 Assert-Control (@($script:FixtureState.services | Where-Object {$_.pid -eq 123}).Count -eq 1) 'Les metadonnees du processus non arrete doivent rester conservees.'
 Assert-Control (@($script:SavedStates | Where-Object {@(($_ | ConvertFrom-Json).services).Count -eq 0}).Count -eq 0) 'Un echec d''arret ne doit jamais sauvegarder un etat vide.'

 # Parcours d'arret reussi, toujours sur des doubles en memoire.
 $script:FixtureState=New-FixtureState;$script:SavedStates=@();$script:StoppedIds=@();$script:StopFailure=$false
 Stop-Project
 Assert-Control ($script:StoppedIds.Count -eq 1 -and $script:StoppedIds[0] -eq 123) 'Seul le processus reconnu doit etre arrete.'
 Assert-Control ($script:FixtureState.services.Count -eq 0 -and $script:SavedStates.Count -eq 1) 'Un arret confirme doit nettoyer puis sauvegarder son etat.'

 # Verification du vrai corps Stop-ServiceRecord, toujours avec de faux PID.
 # Aucune commande systeme n'est deleguee par ces doubles.
 Invoke-Expression $StopServiceDefinition
 $script:StopMode='success';$script:StoppedIds=@()
 function Get-CimInstance($ClassName,[string]$Filter,$ErrorAction) {
  if ($ClassName -ne 'Win32_Process' -or $Filter -notmatch '^ParentProcessId=\d+$') {throw 'Lecture CIM inattendue dans le test.'}
  return @()
 }
 function Stop-Process([int]$Id,[switch]$Force,$ErrorAction) {
  if ($Id -ne 123) {throw 'Le test a tente de toucher un PID hors fixture.'}
  $script:StoppedIds+=@($Id)
  switch ($script:StopMode) {
   'success' {$script:FixtureProcesses.Remove($Id);return}
   'inaccessible' {$script:FixtureProcesses[$Id]=[pscustomobject]@{CommandLine=$null;CreationDate=$Created};return}
   'denied' {throw 'Stop-Process refuse (simulation).'}
   'noop' {return}
   default {throw 'Mode de test inconnu.'}
  }
 }
 $script:FixtureProcesses.Clear()
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$Created}
 Stop-ServiceRecord $Record
 Assert-Control ($script:StoppedIds.Count -eq 1 -and (Get-ServiceRecordStatus $Record) -eq 'absent') 'L''arret reel du corps AST doit etre confirme par une nouvelle lecture de la fixture.'
 foreach ($Mode in @('noop','denied','inaccessible')) {
  $script:StopMode=$Mode;$script:StoppedIds=@();$script:SavedStates=@();$script:Messages=@()
  $script:FixtureState=New-FixtureState
  $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine=$KnownCommand;CreationDate=$Created}
  $OriginalState=$script:FixtureState | ConvertTo-Json -Depth 8 -Compress
  $Rejected=$false
  try {Stop-Project} catch {$Rejected=$true}
  Assert-Control ($Rejected -and $script:StoppedIds.Count -eq 1) ('Un arret '+$Mode+' doit echouer explicitement.')
  Assert-Control ($script:SavedStates.Count -eq 0 -and ($script:FixtureState | ConvertTo-Json -Depth 8 -Compress) -eq $OriginalState) ('Un arret '+$Mode+' doit conserver l''etat de suivi complet.')
  Assert-Control (@($script:Messages | Where-Object {$_ -eq 'backend arrete.'}).Count -eq 0) ('Un arret '+$Mode+' ne doit pas etre annonce comme reussi.')
 }
 $script:StoppedIds=@()
 $Rejected=$false
 try {Stop-ServiceRecord $Record} catch {$Rejected=$true}
 Assert-Control ($Rejected -and $script:StoppedIds.Count -eq 0) 'Le vrai corps AST doit refuser un service inaccessible avant Stop-Process.'
 $script:FixtureProcesses[123]=[pscustomobject]@{CommandLine='autre-projet.ps1';CreationDate=$Created}
 Stop-ServiceRecord $Record
 Assert-Control ($script:StoppedIds.Count -eq 0) 'Le vrai corps AST doit conserver un processus etranger.'
 Write-Output ($script:Controls.ToString()+' controles : reseau, ports, identite des processus, acces refuse et conservation des metadonnees : OK. Aucun service reel demarre ou arrete.')
} finally {
 [Environment]::SetEnvironmentVariable('SAUVERNDEKO_NETWORK_MODE',$OldMode,'Process')
 [Environment]::SetEnvironmentVariable('SAUVERNDEKO_NETWORK_ALIAS',$OldAlias,'Process')
}
