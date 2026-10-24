@echo off
chcp 65001 >nul
setlocal
set "SCRIPT_DIR=%~dp0"
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%manage.ps1" help
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%manage.ps1" %*
)
