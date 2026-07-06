@echo off
REM Genera el informe de mantenimiento desde los JSON de relevamiento.
REM Uso:  sti-informe.bat            (usa el escritorio)
REM       sti-informe.bat -Carpeta "C:\ruta" -Cliente "<Cliente>" -Periodo 2026-06
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sti-informe.ps1" %*
pause
