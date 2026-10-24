@echo off
setlocal
title SauverNdeko - Adresses reseau
chcp 65001 >nul
set "SCRIPT=%~dp0scripts\sauverndeko-local.ps1"
if not exist "%SCRIPT%" (
    echo ERREUR : lanceur introuvable : "%SCRIPT%"
    if /I not "%~1"=="-NoPause" pause
    exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Action Status %*
set "EXIT_CODE=%ERRORLEVEL%"
if /I not "%~1"=="-NoPause" pause
endlocal & exit /b %EXIT_CODE%
