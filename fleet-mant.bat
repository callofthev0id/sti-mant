@echo off
REM Lanzador de testing - menu interactivo del relevamiento de mantenimiento.
REM Uso:  sti-mant.bat            (pide el TAG)
REM       sti-mant.bat -Tag <nombrecorto> -Cliente "<Cliente>"
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sti-mant.ps1" -Menu %*
pause
