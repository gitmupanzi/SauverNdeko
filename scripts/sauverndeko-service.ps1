[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('backend','frontend')][string]$Service,
 [Parameter(Mandatory=$true)][string]$ProjectRoot,
 [Parameter(Mandatory=$true)][string]$Instance,
 [int]$BackendPort=5000,[int]$FrontendPort=5174,
 [string]$BindHost='127.0.0.1',[string]$NodePath='',
 [string]$NetworkHosts=''
)
$ErrorActionPreference='Continue'
$RuntimeRoot=Join-Path $ProjectRoot '.runtime'
$ServicePort=if ($Service -eq 'backend') {$BackendPort} else {$FrontendPort}
$OutLog=Join-Path $RuntimeRoot "$Service-$ServicePort.out.log"
$ErrLog=Join-Path $RuntimeRoot "$Service-$ServicePort.err.log"
try {
 if ($Service -eq 'backend') {
  $BackendRoot=Join-Path $ProjectRoot 'backend'
  $PythonExecutable=Join-Path $BackendRoot '.venv\Scripts\python.exe'
  $ManagePath=Join-Path $BackendRoot 'manage.py'
  Set-Location -LiteralPath $BackendRoot
  # Backend accessible uniquement via le proxy Vite, meme en mode LAN.
  & $PythonExecutable $ManagePath runserver "127.0.0.1:$BackendPort" --noreload --insecure 1>> $OutLog 2>> $ErrLog
 } else {
  $FrontendRoot=Join-Path $ProjectRoot 'frontend'
  $VitePath=Join-Path $FrontendRoot 'node_modules\vite\bin\vite.js'
  Set-Location -LiteralPath $FrontendRoot
  $env:SAUVERNDEKO_BACKEND_URL="http://127.0.0.1:$BackendPort"
  $env:SAUVERNDEKO_LOCAL_ALLOWED_HOSTS=$NetworkHosts
  # Le navigateur utilise son origine courante, egalement depuis un autre PC.
  $env:VITE_API_BASE_URL=''
  & $NodePath $VitePath --host $BindHost --port $FrontendPort --strictPort 1>> $OutLog 2>> $ErrLog
 }
 exit $LASTEXITCODE
} catch {
 $_ | Out-String | Add-Content -LiteralPath $ErrLog
 exit 1
}
