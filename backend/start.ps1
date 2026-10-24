param([string]$Bind='127.0.0.1:5000')
$ErrorActionPreference='Stop'
$PythonExecutable=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $PythonExecutable)) { throw 'Créer backend/.venv et installer requirements.txt ; voir README.md.' }
Push-Location -LiteralPath $PSScriptRoot
try { & $PythonExecutable manage.py runserver $Bind --noreload --insecure; exit $LASTEXITCODE } finally { Pop-Location }
